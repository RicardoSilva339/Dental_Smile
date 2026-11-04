import os
import io
import base64
import psycopg2
import traceback
import numpy as np
from flask import Flask, request, jsonify
from PIL import Image, ImageOps, ImageEnhance

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")

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

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image

        print("=" * 60)
        print(f"📥 [PROCESSAMENTO PYTHON] Original: {orig_image.width} x {orig_image.height} | Tom: {selected_color.upper()}")
        print("=" * 60)

        rgb_image = orig_image.convert("RGB")
        orig_w, orig_h = rgb_image.size

        # Salva a original para o comparador
        buffered_orig = io.BytesIO()
        rgb_image.save(buffered_orig, format="JPEG", quality=90)
        original_processed_b64 = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')

        # 🚀 PROCESSAMENTO LOCAL INTELIGENTE DE CLAREAMENTO (BL1 a BL4)
        # Intensidades baseadas na escolha do dentista
        intensities = {
            'bl1': {'brightness': 1.15, 'contrast': 1.10, 'color_enhence': 1.25},
            'bl2': {'brightness': 1.12, 'contrast': 1.08, 'color_enhence': 1.20},
            'bl3': {'brightness': 1.09, 'contrast': 1.05, 'color_enhence': 1.15},
            'bl4': {'brightness': 1.06, 'contrast': 1.03, 'color_enhence': 1.10}
        }
        cfg = intensities.get(selected_color, intensities['bl2'])

        # Cria uma cópia para aplicar o efeito na região inferior/central (boca)
        processed_img = rgb_image.copy()

        # Isola a região da boca baseada nas proporções do rosto
        box_x1 = int(orig_w * 0.32)
        box_y1 = int(orig_h * 0.60)
        box_x2 = int(orig_w * 0.68)
        box_y2 = int(orig_h * 0.85)

        mouth_area = processed_img.crop((box_x1, box_y1, box_x2, box_y2))

        # Aplica melhorias de brilho e realce de branqueamento na área dos dentes
        enhancer_bright = ImageEnhance.Brightness(mouth_area)
        mouth_area = enhancer_bright.enhance(cfg['brightness'])

        enhancer_contrast = ImageEnhance.Contrast(mouth_area)
        mouth_area = enhancer_contrast.enhance(cfg['contrast'])

        enhancer_color = ImageEnhance.Color(mouth_area)
        mouth_area = enhancer_color.enhance(cfg['color_enhence'])

        # Cole a boca tratada de volta na imagem final mantendo o tamanho exato original
        processed_img.paste(mouth_area, (box_x1, box_y1))

        buffered = io.BytesIO()
        processed_img.save(buffered, format="JPEG", quality=90)
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

        print("=" * 60)
        print("📤 [PROCESSAMENTO PYTHON] Imagem processada e alinhada com sucesso!")
        print("=" * 60)

        return jsonify({
            "success": True,
            "original_image": original_processed_b64,
            "processed_image": processed_b64,
            "creditos_restantes": novo_saldo
        }), 200

    except Exception as e:
        if 'cur' in locals() and cur: cur.close()
        if 'conn' in locals() and conn: conn.close()
        print(f"❌ Erro crítico: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)