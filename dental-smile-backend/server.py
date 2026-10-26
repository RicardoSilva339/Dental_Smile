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
# Usando a sua chave do Replicate
REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN", "bbd5280737253ebb0c42abf734f3c9ce")

# Endpoint oficial do modelo de Stable Diffusion v1.5 no Replicate
REPLICATE_API_URL = "https://api.replicate.com/v1/predictions"
REPLICATE_HEADERS = {
    "Authorization": f"Bearer {REPLICATE_API_TOKEN}",
    "Content-Type": "application/json"
}

def get_db_connection():
    return psycopg2.connect(DATABASE_URL, sslmode='require')

def init_db():
    """Garante a criação da tabela de usuários e adiciona colunas necessárias caso já exista"""
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

        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email VARCHAR(100);")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS senha VARCHAR(100);")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS cro VARCHAR(50);")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS creditos INTEGER DEFAULT 0;")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS tentativas_login INTEGER DEFAULT 0;")

        conn.commit()
        cur.close()
        conn.close()
        print("Banco de dados de usuários sincronizado com sucesso!")
    except Exception as e:
        print(f"Erro ao inicializar o banco de usuários: {e}")

def init_device_db():
    """Garante a criação da tabela de controle de dispositivos (Anti-Reinstalação)"""
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
        print("Banco de dados de dispositivos sincronizado com sucesso!")
    except Exception as e:
        print(f"Erro ao inicializar tabela de dispositivos: {e}")

init_db()
init_device_db()

# 📱 Rota de Verificação de Dispositivo (Anti-Reinstalação)
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
            cur.execute("""
                INSERT INTO dispositivos (device_id, creditos)
                VALUES (%s, 3)
                ON CONFLICT (device_id) DO NOTHING;
            """, (device_id,))
            conn.commit()
            creditos = 3
            novo = True

        cur.close()
        conn.close()
        return jsonify({"success": True, "creditos": creditos, "novo": novo}), 200

    except Exception as e:
        print(f"ERRO NO CHECK-DEVICE: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

# 🔐 Rota de Registro de Novo Dentista
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(force=True, silent=True) or {}
    nome = data.get('nome', '')
    email = data.get('email', '').strip().lower()
    cro = data.get('cro', '')
    senha = data.get('senha', '')

    if not email or not senha:
        return jsonify({"success": False, "error": "E-mail e senha são obrigatórios."}), 400

    api_key = email

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("SELECT id FROM usuarios WHERE email = %s;", (email,))
        if cur.fetchone():
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Este e-mail já está cadastrado."}), 400

        creditos_iniciais = 0

        cur.execute("""
            INSERT INTO usuarios (api_key, nome, email, cro, senha, creditos, tentativas_login)
            VALUES (%s, %s, %s, %s, %s, %s, 0);
        """, (api_key, nome, email, cro, senha, creditos_iniciais))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"success": True, "message": "Conta criada com sucesso!"}), 200
    except Exception as e:
        print(f"ERRO NO CADASTRO: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": f"Erro no banco: {str(e)}"}), 500

# 🔑 Rota de Login
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
            return jsonify({
                "success": False,
                "bloqueado": True,
                "error": "Conta temporariamente bloqueada por excesso de tentativas."
            }), 403

        if senha != senha_correta:
            novas_tentativas = tentativas + 1
            cur.execute("UPDATE usuarios SET tentativas_login = %s WHERE id = %s;", (novas_tentativas, user_id))
            conn.commit()
            cur.close()
            conn.close()

            restantes = 4 - novas_tentativas
            msg = f"Senha incorreta. Restam {restantes} tentativas." if restantes > 0 else "Conta bloqueada por segurança."
            return jsonify({"success": False, "error": msg}), 401

        cur.execute("UPDATE usuarios SET tentativas_login = 0 WHERE id = %s;", (user_id,))
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            "success": True,
            "message": "Login efetuado com sucesso!",
            "api_key": email,
            "creditos": creditos,
            "nome": nome
        }), 200

    except Exception as e:
        print(f"ERRO NO LOGIN: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

# 🔍 Verificar Créditos
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

# 💳 Adicionar Créditos
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
        cur.execute("""
            UPDATE usuarios
            SET creditos = creditos + %s
            WHERE api_key = %s OR email = %s
            RETURNING creditos;
        """, (quantidade, api_key, api_key))
        res = cur.fetchone()
        if res:
            novo_saldo = res[0]
    elif device_id:
        cur.execute("""
            UPDATE dispositivos
            SET creditos = creditos + %s
            WHERE device_id = %s
            RETURNING creditos;
        """, (quantidade, device_id))
        res = cur.fetchone()
        if res:
            novo_saldo = res[0]

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"success": True, "novo_saldo": novo_saldo}), 200

# 🪄 Processar Sorriso (Integrado com o REPLICATE e Escala Bleach)
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
    prompt_custom = f"perfect white smile, professional cosmetic dentistry, bleach shade {selected_color}, highly detailed, natural teeth structure"

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image
        orig_width, orig_height = orig_image.size

        ai_image_resized = None

        # Prepara a imagem em data URI para o Replicate
        image_data_uri = f"data:image/jpeg;base64,{image_b64}"

        # Payload para o modelo Stable Diffusion no Replicate
        payload = {
            "version": "7762fd07cf82c948538e41f63f7d068bf7316f3cc457673b4bf2fd3261b0c038", # Versão estável SD v1.5
            "input": {
                "prompt": prompt_custom,
                "image": image_data_uri,
                "prompt_strength": 0.45,
                "num_outputs": 1
            }
        }

        # Dispara a requisição para criar a predição no Replicate
        resp = requests.post(REPLICATE_API_URL, headers=REPLICATE_HEADERS, json=payload, timeout=30)

        if resp.status_code in [200, 201]:
            pred_data = resp.json()
            pred_id = pred_data.get("id")
            get_url = f"{REPLICATE_API_URL}/{pred_id}"

            # Faz o polling (aguarda o Replicate terminar de processar a imagem na nuvem)
            for _ in range(15): # Tenta por até 30 segundos (2s por tentativa)
                time.sleep(2)
                poll_resp = requests.get(get_url, headers=REPLICATE_HEADERS, timeout=15)
                if poll_resp.status_code == 200:
                    poll_data = poll_resp.json()
                    status = poll_data.get("status")

                    if status == "succeeded":
                        output = poll_data.get("output")
                        if output and isinstance(output, list) and len(output) > 0:
                            img_url = output[0]
                            # Baixa a imagem gerada pelo Replicate
                            img_resp = requests.get(img_url, timeout=20)
                            if img_resp.status_code == 200:
                                ai_image = Image.open(io.BytesIO(img_resp.content))
                                ai_image = ImageOps.exif_transpose(ai_image) or ai_image
                                ai_image_resized = ai_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)
                        break
                    elif status in ["failed", "canceled"]:
                        break

        # Fallback de segurança caso a IA demore ou falhe
        if ai_image_resized is None:
            ai_image_resized = orig_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)

        buffered = io.BytesIO()
        ai_image_resized.save(buffered, format="JPEG")
        processed_b64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

        # Desconta o crédito (do dispositivo ou do usuário)
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