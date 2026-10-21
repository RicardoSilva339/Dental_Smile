import os
import io
import base64
import requests
import psycopg2
import traceback
from flask import Flask, request, jsonify
from PIL import Image

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")
HUGGINGFACE_API_KEY = os.environ.get("HUGGINGFACE_API_KEY")

HF_API_URL = "https://router.huggingface.co/hf-inference/models/runwayml/stable-diffusion-v1-5"
HEADERS = {"Authorization": f"Bearer {HUGGINGFACE_API_KEY}"}

def get_db_connection():
    return psycopg2.connect(DATABASE_URL, sslmode='require')

def init_db():
    """Garante a criação e atualização automática das colunas da tabela de usuários"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # 1. Cria a tabela base se não existir
        cur.execute("""
            CREATE TABLE IF NOT EXISTS usuarios (
                id SERIAL PRIMARY KEY,
                api_key VARCHAR(100) UNIQUE NOT NULL,
                nome VARCHAR(100),
                email VARCHAR(100) UNIQUE NOT NULL,
                cro VARCHAR(50),
                creditos INTEGER DEFAULT 3,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

        # 2. Adiciona as colunas novas caso a tabela já tenha sido criada anteriormente
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS senha VARCHAR(100);")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS tentativas_login INTEGER DEFAULT 0;")

        conn.commit()
        cur.close()
        conn.close()
        print("Banco de dados sincronizado e atualizado com sucesso!")
    except Exception as e:
        print(f"Erro ao inicializar o banco de dados: {e}")

init_db()

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

    api_key = email  # O e-mail é a chave única

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Verifica se o e-mail já existe
        cur.execute("SELECT id FROM usuarios WHERE email = %s;", (email,))
        if cur.fetchone():
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Este e-mail já está cadastrado."}), 400

        # Insere o novo usuário
        cur.execute("""
            INSERT INTO usuarios (api_key, nome, email, cro, senha, creditos, tentativas_login)
            VALUES (%s, %s, %s, %s, %s, 3, 0);
        """, (api_key, nome, email, cro, senha))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"success": True, "message": "Conta criada com sucesso com 3 créditos iniciais!"}), 200
    except Exception as e:
        print(f"ERRO NO CADASTRO: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": f"Erro no banco: {str(e)}"}), 500

# 🔑 Rota de Login com Proteção de Tentativas
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
                "error": "Conta temporariamente bloqueada por excesso de tentativas. Redefina a senha."
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

        # Reset de tentativas após login correto
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
    quantidade = data.get('quantidade', 10)

    conn = get_db_connection()
    cur = conn.cursor()

    # Atualiza tanto por api_key quanto por email
    cur.execute("""
        UPDATE usuarios
        SET creditos = creditos + %s
        WHERE api_key = %s OR email = %s
        RETURNING creditos;
    """, (quantidade, api_key, api_key))

    res = cur.fetchone()
    novo_saldo = res[0] if res else quantidade
    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"success": True, "novo_saldo": novo_saldo}), 200

# 🪄 Processar Sorriso
@app.route('/process-smile', methods=['POST'])
def process_smile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
    user = cur.fetchone()
    creditos_atuais = user[0] if user else 0

    if creditos_atuais <= 0:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Créditos insuficientes."}), 403

    image_b64 = data.get('image')
    prompt_custom = data.get('prompt', 'perfect white smile, professional cosmetic dentistry, highly detailed')

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_width, orig_height = orig_image.size

        ai_image_resized = None
        try:
            payload = {"inputs": prompt_custom, "parameters": {"strength": 0.45}}
            response = requests.post(HF_API_URL, headers=HEADERS, files={"image": image_data}, json=payload, timeout=30)
            if response.status_code == 200:
                ai_image = Image.open(io.BytesIO(response.content))
                ai_image_resized = ai_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)
        except Exception:
            pass

        if ai_image_resized is None:
            ai_image_resized = orig_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)

        buffered = io.BytesIO()
        ai_image_resized.save(buffered, format="JPEG")
        processed_b64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

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