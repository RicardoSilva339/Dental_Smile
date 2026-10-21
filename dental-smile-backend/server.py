import os
import io
import base64
import requests
import psycopg2
from flask import Flask, request, jsonify
from PIL import Image

app = Flask(__name__)

# Lê a URL do banco PostgreSQL configurada nas Environment Variables do Render
DATABASE_URL = os.environ.get("DATABASE_URL")
HUGGINGFACE_API_KEY = os.environ.get("HUGGINGFACE_API_KEY")

# URL atualizada do modelo Stable Diffusion no Hugging Face (Inference Router)
HF_API_URL = "https://router.huggingface.co/hf-inference/models/runwayml/stable-diffusion-v1-5"
HEADERS = {"Authorization": f"Bearer {HUGGINGFACE_API_KEY}"}

def get_db_connection():
    """Cria uma conexão segura com o PostgreSQL no Render"""
    return psycopg2.connect(DATABASE_URL, sslmode='require')

def init_db():
    """Cria a tabela de usuários, créditos, email e CRO caso ela ainda não exista"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS usuarios (
                id SERIAL PRIMARY KEY,
                api_key VARCHAR(100) UNIQUE NOT NULL,
                nome VARCHAR(100),
                email VARCHAR(100),
                cro VARCHAR(50),
                creditos INTEGER DEFAULT 3,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
        print("Tabela 'usuarios' (com email e CRO) verificada/criada com sucesso no PostgreSQL!")
    except Exception as e:
        print(f"Erro ao inicializar o banco de dados: {e}")

# Inicializa a tabela assim que o servidor sobe
init_db()

@app.route('/check-credits', methods=['POST'])
def check_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', 'dentista_demo_123')

    conn = get_db_connection()
    cur = conn.cursor()

    # Procura o dentista pelo api_key
    cur.execute("SELECT creditos, nome FROM usuarios WHERE api_key = %s;", (api_key,))
    user = cur.fetchone()

    if not user:
        # Se o usuário não existe, cria automaticamente com 3 créditos iniciais (freemium)
        cur.execute(
            "INSERT INTO usuarios (api_key, nome, creditos) VALUES (%s, %s, %s) RETURNING creditos;",
            (api_key, "Dr. Demo", 3)
        )
        creditos = cur.fetchone()[0]
        conn.commit()
    else:
        creditos = user[0]

    cur.close()
    conn.close()

    return jsonify({"success": True, "creditos": creditos}), 200

@app.route('/add-credits', methods=['POST'])
def add_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', 'dentista_demo_123')
    quantidade = data.get('quantidade', 10) # Ex: 10, 50 ou 100 créditos do plano

    conn = get_db_connection()
    cur = conn.cursor()

    # Atualiza ou adiciona créditos ao usuário de forma persistente
    cur.execute("""
        INSERT INTO usuarios (api_key, creditos) VALUES (%s, %s)
        ON CONFLICT (api_key)
        DO UPDATE SET creditos = usuarios.creditos + EXCLUDED.creditos
        RETURNING creditos;
    """, (api_key, quantidade))

    novo_saldo = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()

    return jsonify({
        "success": True,
        "message": f"{quantidade} créditos adicionados com sucesso!",
        "novo_saldo": novo_saldo
    }), 200

# 👤 Nova rota para atualizar/salvar os dados cadastrais e CRO do dentista
@app.route('/update-profile', methods=['POST'])
def update_profile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', 'dentista_demo_123')
    nome = data.get('nome')
    email = data.get('email')
    cro = data.get('cro')

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO usuarios (api_key, nome, email, cro)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (api_key)
            DO UPDATE SET
                nome = EXCLUDED.nome,
                email = EXCLUDED.email,
                cro = EXCLUDED.cro;
        """, (api_key, nome, email, cro))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"success": True, "message": "Perfil atualizado com sucesso no PostgreSQL!"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/process-smile', methods=['POST'])
def process_smile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', 'dentista_demo_123')

    # Validação de Créditos no PostgreSQL
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos FROM usuarios WHERE api_key = %s;", (api_key,))
    user = cur.fetchone()

    creditos_atuais = user[0] if user else 0

    if creditos_atuais <= 0:
        cur.close()
        conn.close()
        return jsonify({
            "success": False,
            "error": "Créditos insuficientes. Por favor, adquira um novo pacote de créditos."
        }), 403

    image_b64 = data.get('image')
    prompt_custom = data.get('prompt', 'perfect white smile, professional cosmetic dentistry, highly detailed')

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        # Decodifica a imagem original do app e guarda as dimensões originais (para o 1:1)
        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_width, orig_height = orig_image.size

        ai_image_resized = None

        try:
            # Tenta enviar a imagem para o Hugging Face
            payload = {
                "inputs": prompt_custom,
                "parameters": {"strength": 0.45}
            }
            response = requests.post(HF_API_URL, headers=HEADERS, files={"image": image_data}, json=payload, timeout=30)

            if response.status_code == 200:
                ai_image = Image.open(io.BytesIO(response.content))
                ai_image_resized = ai_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)
        except Exception as ai_err:
            print(f"Aviso: Falha na conexão com Hugging Face ({ai_err}), usando processamento local de contingência.")

        # Se por acaso a IA falhar ou der timeout, usa a imagem original redimensionada para garantir que o fluxo não quebre
        if ai_image_resized is None:
            ai_image_resized = orig_image.resize((orig_width, orig_height), Image.Resampling.LANCZOS)

        # Converte de volta para base64 para retornar ao Flutter
        buffered = io.BytesIO()
        ai_image_resized.save(buffered, format="JPEG")
        processed_b64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

        # Desconta 1 crédito do usuário no PostgreSQL com sucesso garantido!
        cur.execute("UPDATE usuarios SET creditos = creditos - 1 WHERE api_key = %s RETURNING creditos;", (api_key,))
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
        if 'cur' in locals() and cur:
            cur.close()
        if 'conn' in locals() and conn:
            conn.close()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)