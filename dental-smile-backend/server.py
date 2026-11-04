import os
import io
import base64
import time
import requests
import psycopg2
import traceback
from flask import Flask, request, jsonify
from PIL import Image, ImageOps, ImageDraw

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")
REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN", "bbd5280737253ebb0c42abf734f3c9ce")

REPLICATE_API_URL = "https://api.replicate.com/v1/predictions"
REPLICATE_HEADERS = {
    "Authorization": f"Bearer {REPLICATE_API_TOKEN}",
    "Content-Type": "application/json"
}

def get_db_connection():
    return psycopg2.connect(DATABASE_URL, sslmode='require')

def init_db():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS usuarios (
                id SERIAL PRIMARY KEY,
                api_key VARCHAR(100) UNIQUE NOT NULL,
                nome VARCHAR(100),
                email VARCHAR(100) UNIQUE NOT NULL,
                cro VARCHAR(50),
                creditos INTEGER DEFAULT 0,
                senha VARCHAR(100),
                tentativas_login INTEGER DEFAULT 0,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Erro ao inicializar o banco: {e}")

def init_device_db():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS dispositivos (
                device_id VARCHAR(255) PRIMARY KEY,
                creditos INTEGER DEFAULT 3,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Erro ao inicializar dispositivos: {e}")

init_db()
init_device_db()

@app.route('/check-device', methods=['POST'])
def check_device():
    data = request.get_json(force=True, silent=True) or {}
    device_id = data.get('device_id', '').strip()
    if not device_id:
        return jsonify({"success": False, "error": "Device ID obrigatório."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT creditos FROM dispositivos WHERE device_id = %s;", (device_id,))
        row = cur.fetchone()
        if row:
            creditos = row[0]
            novo = False
        else:
            cur.execute("INSERT INTO dispositivos (device_id, creditos) VALUES (%s, 3) ON CONFLICT (device_id) DO NOTHING;", (device_id,))
            conn.commit()
            creditos = 3
            novo = True
        cur.close()
        conn.close()
        return jsonify({"success": True, "creditos": creditos, "novo": novo}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(force=True, silent=True) or {}
    nome = data.get('nome', '')
    email = data.get('email', '').strip().lower()
    cro = data.get('cro', '')
    senha = data.get('senha', '')

    if not email or not senha:
        return jsonify({"success": False, "error": "E-mail e senha são obrigatórios."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id FROM usuarios WHERE email = %s;", (email,))
        if cur.fetchone():
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Este e-mail já está cadastrado."}), 400

        cur.execute("""
            INSERT INTO usuarios (api_key, nome, email, cro, senha, creditos, tentativas_login)
            VALUES (%s, %s, %s, %s, %s, 0, 0);
        """, (email, nome, email, cro, senha, 0))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"success": True, "message": "Conta criada com sucesso!"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()
    senha = data.get('senha', '')

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, senha, tentativas_login, creditos, nome FROM usuarios WHERE email = %s;", (email,))
        user = cur.fetchone()

        if not user:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "E-mail não encontrado."}), 404

        user_id, senha_corr, tentativas, creditos, nome = user
        tentativas = tentativas or 0

        if tentativas >= 4:
            cur.close()
            conn.close()
            return jsonify({"success": False, "bloqueado": True, "error": "Conta bloqueada por excesso de tentativas."}), 403

        if senha != senha_corr:
            novas_tentativas = tentativas + 1
            cur.execute("UPDATE usuarios SET tentativas_login = %s WHERE id = %s;", (novas_tentativas, user_id))
            conn.commit()
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Senha incorreta."}), 401

        cur.execute("UPDATE usuarios SET tentativas_login = 0 WHERE id = %s;", (user_id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"success": True, "api_key": email, "creditos": creditos, "nome": nome}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/check-credits', methods=['POST'])
def check_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
    user = cur.fetchone()
    creditos = user[0] if user else 0
    cur.close()
    conn.close()
    return jsonify({"success": True, "creditos": creditos}), 200

@app.route('/add-credits', methods=['POST'])
def add_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    device_id = data.get('device_id', '').strip()
    quantidade = int(data.get('quantidade', 10))

    conn = get_db_connection()
    cur = conn.cursor()
    novo_saldo = quantidade

    if api_key:
        cur.execute("UPDATE usuarios SET creditos = creditos + %s WHERE api_key = %s OR email = %s RETURNING creditos;", (quantidade, api_key, api_key))
        res = cur.fetchone()
        if res: novo_saldo = res[0]
    elif device_id:
        cur.execute("UPDATE dispositivos SET creditos = creditos + %s WHERE device_id = %s RETURNING creditos;", (quantidade, device_id))
        res = cur.fetchone()
        if res: novo_saldo = res[0]

    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"success": True, "novo_saldo": novo_saldo}), 200

@app.route('/process-smile', methods=['POST'])
def process_smile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    device_id = data.get('device_id', '').strip()

    conn = get_db_connection()
    cur = conn.cursor()
    creditos_atuais = 0
    is_convidado = False

    if api_key:
        cur.execute("SELECT creditos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
        user = cur.fetchone()
        creditos_atuais = user[0] if user else 0
    elif device_id:
        is_convidado = True
        cur.execute("SELECT creditos FROM dispositivos WHERE device_id = %s;", (device_id,))
        row = cur.fetchone()
        creditos_atuais = row[0] if row else 0
    else:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Identificação inválida."}), 400

    if creditos_atuais <= 0:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Créditos insuficientes."}), 403

    image_b64 = data.get('image')
    selected_color = data.get('color', 'bl2').lower()

    bleach_modifiers = {
        'bl1': 'ultra white bleach shade BL1 teeth, maximum professional aesthetic whitening',
        'bl2': 'bright white bleach shade BL2 teeth, natural and striking bright look',
        'bl3': 'natural white bleach shade BL3 teeth, harmonious and balanced shade',
        'bl4': 'soft natural bleach shade BL4 teeth, subtle clean translucent look'
    }
    color_desc = bleach_modifiers.get(selected_color, bleach_modifiers['bl2'])

    # Prompt otimizado para inpainting estrito na região da boca
    prompt_custom = (
        f"perfect aesthetic human teeth, {color_desc}, aligned white teeth, "
        f"healthy teeth with a perfect smile, professional dental restoration, photorealistic"
    )

    negative_prompt_custom = (
        "deformed teeth, ugly, disfigured, bad anatomy, crooked teeth, "
        "worst quality, low quality, jpeg artifacts, extra teeth, missing teeth"
    )

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image

        print("=" * 60)
        print(f"📥 [INPAINTING] Imagem original recebida: {orig_image.width} x {orig_image.height}")
        print("=" * 60)

        rgb_image = orig_image.convert("RGB")
        w, h = rgb_image.size

        # Redimensiona para 512x512 para o Stable Diffusion Inpainting processar perfeitamente sem distorcer
        img_512 = rgb_image.resize((512, 512), Image.Resampling.LANCZOS)

        buffered_orig = io.BytesIO()
        rgb_image.save(buffered_orig, format="JPEG", quality=90)
        original_processed_b64 = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')

        buffered_input = io.BytesIO()
        img_512.save(buffered_input, format="JPEG", quality=90)
        image_b64_512 = base64.b64encode(buffered_input.getvalue()).decode('utf-8')
        image_data_uri = f"data:image/jpeg;base64,{image_b64_512}"

        # 🎯 Criação automática da Máscara focada na região central inferior (boca/sorriso)
        mask_img = Image.new("L", (512, 512), 0) # Fundo preto (preserva tudo)
        draw = ImageDraw.Draw(mask_img)
        # Desenha uma elipse branca exatamente na zona da boca (centro-baixo)
        draw.ellipse([160, 300, 352, 430], fill=255) # Branco (área que a IA vai modificar)

        buffered_mask = io.BytesIO()
        mask_img.save(buffered_mask, format="PNG")
        mask_b64 = base64.b64encode(buffered_mask.getvalue()).decode('utf-8')
        mask_data_uri = f"data:image/png;base64,{mask_b64}"

        ai_image_final = None

        # Usando o modelo oficial e estável de Inpainting do Replicate
        payload = {
            "version": "95b7223104132402a9ae91cc677285bc0eb997013cd357bffa40d9ae41a9d91a",
            "input": {
                "image": image_data_uri,
                "mask": mask_data_uri,
                "prompt": prompt_custom,
                "negative_prompt": negative_prompt_custom,
                "num_outputs": 1,
                "guidance_scale": 7.5,
                "prompt_strength": 0.75
            }
        }

        resp = requests.post(REPLICATE_API_URL, headers=REPLICATE_HEADERS, json=payload, timeout=30)

        if resp.status_code in [200, 201]:
            pred_data = resp.json()
            pred_id = pred_data.get("id")
            get_url = f"{REPLICATE_API_URL}/{pred_id}"

            for _ in range(60):
                time.sleep(2)
                try:
                    poll_resp = requests.get(get_url, headers=REPLICATE_HEADERS, timeout=20)
                    if poll_resp.status_code == 200:
                        poll_data = poll_resp.json()
                        status = poll_data.get("status")

                        if status == "succeeded":
                            output = poll_data.get("output")
                            if output and isinstance(output, list) and len(output) > 0:
                                img_url = output[0]
                                img_resp = requests.get(img_url, timeout=60)
                                if img_resp.status_code == 200:
                                    ai_image = Image.open(io.BytesIO(img_resp.content))
                                    ai_image = ImageOps.exif_transpose(ai_image) or ai_image

                                    print("=" * 60)
                                    print(f"📤 [INPAINTING] Sucesso! Redimensionando para o tamanho original: {w}x{h}")
                                    print("=" * 60)

                                    # Redimensiona diretamente para o tamanho original exato da foto do celular
                                    ai_image_final = ai_image.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
                            break
                        elif status in ["failed", "canceled"]:
                            break
                except Exception:
                    continue

        if ai_image_final is None:
            ai_image_final = rgb_image.copy()

        buffered = io.BytesIO()
        ai_image_final.save(buffered, format="JPEG", quality=90)
        processed_b64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

        if is_convidado:
            cur.execute("UPDATE dispositivos SET creditos = creditos - 1 WHERE device_id = %s RETURNING creditos;", (device_id,))
            novo_saldo = cur.fetchone()[0]
        else:
            cur.execute("UPDATE usuarios SET creditos = creditos - 1 WHERE api_key = %s OR email = %s RETURNING creditos;", (api_key, api_key))
            novo_saldo = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            "success": True,
            "original_image": original_processed_b64,
            "processed_image": processed_b64,
            "creditos_restantes": novo_saldo
        }), 200

    except Exception as e:
        if 'cur' in locals() and cur: cur.close()
        if 'conn' in locals() and conn: conn.close()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)