import os
import io
import base64
import time
import requests
import psycopg2
import traceback
from flask import Flask, request, jsonify
from PIL import Image, ImageOps

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

        user_id, senha_correta, tentativas, creditos, nome = user
        tentativas = tentativas or 0

        if tentativas >= 4:
            cur.close()
            conn.close()
            return jsonify({"success": False, "bloqueado": True, "error": "Conta bloqueada por excesso de tentativas."}), 403

        if senha != senha_correta:
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

    prompt_custom = (
        f"photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1> "
        f"(Beautiful natural teeth, aligned bite teeth), {color_desc}, "
        f"aligned white teeth, human like teeth, (no teeth gap), "
        f"celebrity-like teeth, healthy teeth with a perfect smile, not big incisor, "
        f"good proportion teeth, good proportion smile,"
    )

    negative_prompt_custom = (
        "(deformed teeth, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime), "
        "(deformed, distorted, abnormal teeth:1.3, disfigured:1.3, large teeth:2), poorly drawn, "
        "bad anatomy, rabbit teeth, wrong anatomy, missing teeth, disconnected teeth, "
        "unnatural mouth, bunny teeth, big incisor teeth, disproportionate front teeth, "
        "bad smile, reflection, crooked teeth, distorted teeth, cropped, out of frame, "
        "worst quality, low quality, jpeg artifacts, ugly, morbid, disfigured, "
        "gross proportions, too many teeth, lipstick, lip gloss, too less teeth, "
        "unnatural size teeth, poorly drawn mouth, poorly drawn teeth"
    )

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image
        orig_width, orig_height = orig_image.size

        print("=" * 60)
        print(f"📥 [TELEMETRIA ENTRADA] Imagem Original do App: {orig_width} x {orig_height}")
        print("=" * 60)

        work_image = orig_image.copy()
        max_dim = 1024
        if max(orig_width, orig_height) > max_dim:
            work_image.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
            print(f"🔄 [TELEMETRIA WORK] Reduzida para envio ao Replicate: {work_image.width} x {work_image.height}")

        buffered_work = io.BytesIO()
        work_image.save(buffered_work, format="JPEG", quality=90)
        optimized_b64 = base64.b64encode(buffered_work.getvalue()).decode('utf-8')
        image_data_uri = f"data:image/jpeg;base64,{optimized_b64}"

        ai_image_final = None

        payload = {
            "version": "4956c634b9aa976129f13166c713f8cf38bd337cd58c77925e8cd71d935d5696",
            "input": {
                "image": image_data_uri,
                "prompt": prompt_custom,
                "negative_prompt": negative_prompt_custom,
                "num_outputs": 1
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
                                    print(f"📤 [TELEMETRIA SAÍDA] Retornada pelo Replicate: {ai_image.width} x {ai_image.height}")
                                    print(f"🔍 [COMPARAÇÃO] Original: {orig_width}x{orig_height} vs IA: {ai_image.width}x{ai_image.height}")
                                    print("=" * 60)

                                    ai_square = ai_image.convert("RGB")
                                    new_ai_width = orig_width
                                    new_ai_height = int(ai_square.height * (orig_width / ai_square.width))
                                    ai_resized = ai_square.resize((new_ai_width, new_ai_height), Image.Resampling.LANCZOS)

                                    ai_image_final = Image.new("RGB", (orig_width, orig_height), (0, 0, 0))
                                    paste_y = (orig_height - new_ai_height) // 2
                                    ai_image_final.paste(ai_resized, (0, paste_y))
                            break
                        elif status in ["failed", "canceled"]:
                            break
                except Exception:
                    continue

        if ai_image_final is None:
            ai_image_final = orig_image.copy()

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