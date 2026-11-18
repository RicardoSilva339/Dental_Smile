import os
import io
import random
import base64
import time
import psycopg2
import traceback
import requests
import numpy as np
import mercadopago
from flask import Flask, request, jsonify
from PIL import Image, ImageOps
import cv2

app = Flask(__name__)

@app.route('/', methods=['GET', 'HEAD'])
def health_check():
    return "Dental Smile Backend OK", 200

DATABASE_URL = os.environ.get("DATABASE_URL")
RESEND_API_KEY = os.environ.get("RESEND_API_KEY")

# Inicializa o SDK do Mercado Pago com verificação de segurança no boot
mp_access_token = os.environ.get("MP_ACCESS_TOKEN", "").strip()
if not mp_access_token:
    print("⚠️ ATENÇÃO: MP_ACCESS_TOKEN não foi encontrado nas variáveis de ambiente!")
else:
    print(f"💳 Mercado Pago inicializado com token: {mp_access_token[:10]}...")

sdk = mercadopago.SDK(mp_access_token)

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
                email_verificado BOOLEAN DEFAULT FALSE,
                codigo_verificacao VARCHAR(6),
                limite_dispositivos INTEGER DEFAULT 1,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN DEFAULT FALSE;")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS codigo_verificacao VARCHAR(6);")
        cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS limite_dispositivos INTEGER DEFAULT 1;")

        cur.execute("""
            CREATE TABLE IF NOT EXISTS dispositivos_ativos (
                id SERIAL PRIMARY KEY,
                email_dentista VARCHAR(100) NOT NULL,
                device_id VARCHAR(255) NOT NULL,
                ultima_atividade TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (email_dentista, device_id)
            );
        """)

        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Erro ao inicializar o banco: {e}")

init_db()

print("⚙️ Servidor iniciado com Virada de Ouro (Flux 2 Pro) + Mercado Pago Pix")

def enviar_email_codigo(destinatario, nome, codigo, assunto="Código de Verificação - Dental Smile"):
    if not RESEND_API_KEY:
        print(f"⚠️ [MODO TESTE SEM RESEND_API_KEY] Código para {destinatario}: {codigo}")
        return True

    saudacao = f"Olá, Dr(a). {nome}!" if nome else "Olá!"
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #5C6BC0; text-align: center;">Dental Smile</h2>
        <p>{saudacao}</p>
        <p>Use o código de 6 dígitos abaixo para validar seu acesso:</p>
        <div style="background-color: #f4f6f9; padding: 15px; text-align: center; border-radius: 8px; margin: 20px 0;">
            <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #333;">{codigo}</span>
        </div>
        <p style="font-size: 12px; color: #777;">Se você não solicitou este código, apenas ignore este e-mail.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="font-size: 11px; color: #999; text-align: center;">Dental Smile &bull; <a href="https://dentalsmile.ia.br" style="color: #5C6BC0; text-decoration: none;">dentalsmile.ia.br</a></p>
    </div>
    """

    try:
        resp = requests.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {RESEND_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "from": "Dental Smile <contato@dentalsmile.ia.br>",
                "to": [destinatario],
                "subject": assunto,
                "html": html_content
            },
            timeout=15
        )
        return resp.status_code in [200, 201]
    except Exception as e:
        print(f"Erro ao enviar e-mail: {e}")
        return False

def validar_limite_dispositivo(cur, email, device_id, limite):
    if not device_id:
        return True, "OK"

    cur.execute("SELECT id FROM dispositivos_ativos WHERE email_dentista = %s AND device_id = %s;", (email, device_id))
    if cur.fetchone():
        cur.execute("UPDATE dispositivos_ativos SET ultima_atividade = CURRENT_TIMESTAMP WHERE email_dentista = %s AND device_id = %s;", (email, device_id))
        return True, "OK"

    cur.execute("SELECT COUNT(*) FROM dispositivos_ativos WHERE email_dentista = %s;", (email,))
    qtd_ativos = cur.fetchone()[0]

    if qtd_ativos >= limite:
        return False, f"Limite de {limite} dispositivo(s) simultâneo(s) atingido para o seu plano."

    cur.execute("INSERT INTO dispositivos_ativos (email_dentista, device_id) VALUES (%s, %s);", (email, device_id))
    return True, "OK"

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(force=True, silent=True) or {}
    nome = data.get('nome', '').strip()
    email = data.get('email', '').strip().lower()
    cro = data.get('cro', '').strip()
    senha = data.get('senha', '')

    if not email or not senha:
        return jsonify({"success": False, "error": "E-mail e senha são obrigatórios."}), 400

    codigo_otp = f"{random.randint(100000, 999999)}"

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, email_verificado FROM usuarios WHERE email = %s;", (email,))
        existente = cur.fetchone()

        if existente:
            if existente[1]:
                cur.close()
                conn.close()
                return jsonify({"success": False, "error": "Este e-mail já está cadastrado e ativo."}), 400
            else:
                cur.execute("""
                    UPDATE usuarios
                    SET nome = %s, cro = %s, senha = %s, codigo_verificacao = %s
                    WHERE email = %s;
                """, (nome, cro, senha, codigo_otp, email))
        else:
            cur.execute("""
                INSERT INTO usuarios (api_key, nome, email, cro, senha, creditos, email_verificado, codigo_verificacao, limite_dispositivos)
                VALUES (%s, %s, %s, %s, %s, 0, FALSE, %s, 1);
            """, (email, nome, email, cro, senha, codigo_otp))

        conn.commit()
        cur.close()
        conn.close()

        enviar_email_codigo(email, nome, codigo_otp, "Ative sua conta - Código Dental Smile")

        return jsonify({
            "success": True,
            "requer_verificacao": True,
            "message": "Código de 6 dígitos enviado para o seu e-mail!"
        }), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/verify-email', methods=['POST'])
def verify_email():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()
    codigo = data.get('codigo', '').strip()
    device_id = data.get('device_id', '').strip()

    if not email or not codigo:
        return jsonify({"success": False, "error": "E-mail e código são obrigatórios."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, codigo_verificacao, email_verificado, nome, limite_dispositivos FROM usuarios WHERE email = %s;", (email,))
        user = cur.fetchone()

        if not user:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Usuário não encontrado."}), 404

        user_id, codigo_salvo, ja_verificado, nome, limite_disp = user

        if ja_verificado:
            cur.close()
            conn.close()
            return jsonify({"success": True, "message": "Conta já verificada!"}), 200

        if codigo != codigo_salvo:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Código incorreto. Verifique seu e-mail e tente novamente."}), 400

        cur.execute("""
            UPDATE usuarios
            SET email_verificado = TRUE, codigo_verificacao = NULL, creditos = 3
            WHERE id = %s;
        """, (user_id,))

        if device_id:
            validar_limite_dispositivo(cur, email, device_id, limite_disp or 1)

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            "success": True,
            "api_key": email,
            "nome": nome,
            "creditos": 3,
            "message": "E-mail confirmado! Seus 3 créditos gratuitos foram liberados."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()
    senha = data.get('senha', '')
    device_id = data.get('device_id', '').strip()

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT id, senha, tentativas_login, creditos, nome, email_verificado, limite_dispositivos
            FROM usuarios WHERE email = %s;
        """, (email,))
        user = cur.fetchone()

        if not user:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "E-mail não encontrado."}), 404

        user_id, senha_corr, tentativas, creditos, nome, email_verificado, limite_disp = user
        tentativas = tentativas or 0
        limite_disp = limite_disp or 1

        if tentativas >= 4:
            cur.close()
            conn.close()
            return jsonify({"success": False, "bloqueado": True, "error": "Conta bloqueada por excesso de tentativas. Use 'Esqueci minha senha'."}), 403

        if senha != senha_corr:
            novas_tentativas = tentativas + 1
            cur.execute("UPDATE usuarios SET tentativas_login = %s WHERE id = %s;", (novas_tentativas, user_id))
            conn.commit()
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Senha incorreta."}), 401

        if not email_verificado:
            novo_codigo = f"{random.randint(100000, 999999)}"
            cur.execute("UPDATE usuarios SET codigo_verificacao = %s WHERE id = %s;", (novo_codigo, user_id))
            conn.commit()
            cur.close()
            conn.close()
            enviar_email_codigo(email, nome, novo_codigo, "Ative sua conta - Código Dental Smile")
            return jsonify({
                "success": False,
                "requer_verificacao": True,
                "error": "E-mail ainda não confirmado. Enviamos um novo código de 6 dígitos para você."
            }), 403

        permitido, msg_disp = validar_limite_dispositivo(cur, email, device_id, limite_disp)
        if not permitido:
            cur.close()
            conn.close()
            return jsonify({"success": False, "limite_dispositivos": True, "error": msg_disp}), 403

        cur.execute("UPDATE usuarios SET tentativas_login = 0 WHERE id = %s;", (user_id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({
            "success": True,
            "api_key": email,
            "creditos": creditos,
            "nome": nome,
            "limite_dispositivos": limite_disp
        }), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()

    if not email:
        return jsonify({"success": False, "error": "Informe o e-mail cadastrado."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, nome FROM usuarios WHERE email = %s;", (email,))
        user = cur.fetchone()

        if not user:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "E-mail não encontrado no sistema."}), 404

        user_id, nome = user
        codigo_recuperacao = f"{random.randint(100000, 999999)}"

        cur.execute("UPDATE usuarios SET codigo_verificacao = %s WHERE id = %s;", (codigo_recuperacao, user_id))
        conn.commit()
        cur.close()
        conn.close()

        enviar_email_codigo(email, nome, codigo_recuperacao, "Recuperação de Senha - Dental Smile")

        return jsonify({"success": True, "message": "Código de recuperação enviado para o seu e-mail."}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()
    codigo = data.get('codigo', '').strip()
    nova_senha = data.get('nova_senha', '')

    if not email or not codigo or not nova_senha:
        return jsonify({"success": False, "error": "Preencha todos os campos."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, codigo_verificacao FROM usuarios WHERE email = %s;", (email,))
        user = cur.fetchone()

        if not user or user[1] != codigo:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Código inválido ou expirado."}), 400

        cur.execute("""
            UPDATE usuarios
            SET senha = %s, codigo_verificacao = NULL, tentativas_login = 0, email_verificado = TRUE
            WHERE id = %s;
        """, (nova_senha, user[0]))
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"success": True, "message": "Senha alterada com sucesso!"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/reset-devices', methods=['POST'])
def reset_devices():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('email', '').strip().lower()
    device_id_atual = data.get('device_id', '').strip()

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM dispositivos_ativos WHERE email_dentista = %s;", (email,))
        if device_id_atual:
            cur.execute("INSERT INTO dispositivos_ativos (email_dentista, device_id) VALUES (%s, %s);", (email, device_id_atual))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"success": True, "message": "Dispositivos antigos desconectados com sucesso."}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/check-credits', methods=['POST'])
def check_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()

    if not api_key:
        return jsonify({"success": True, "creditos": 0}), 200

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos, limite_dispositivos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
    user = cur.fetchone()
    creditos = user[0] if user else 0
    limite = user[1] if user else 1
    cur.close()
    conn.close()
    return jsonify({"success": True, "creditos": creditos, "limite_dispositivos": limite}), 200

@app.route('/add-credits', methods=['POST'])
def add_credits():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    quantidade = int(data.get('quantidade', 10))

    if not api_key:
        return jsonify({"success": False, "error": "Usuário não identificado."}), 400

    novo_limite = 1
    if quantidade >= 100:
        novo_limite = 3
    elif quantidade >= 30:
        novo_limite = 2

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE usuarios
        SET creditos = creditos + %s,
            limite_dispositivos = GREATEST(COALESCE(limite_dispositivos, 1), %s)
        WHERE api_key = %s OR email = %s
        RETURNING creditos, limite_dispositivos;
    """, (quantidade, novo_limite, api_key, api_key))
    res = cur.fetchone()

    conn.commit()
    cur.close()
    conn.close()

    if res:
        return jsonify({"success": True, "novo_saldo": res[0], "limite_dispositivos": res[1]}), 200
    return jsonify({"success": False, "error": "Conta não encontrada."}), 404

# --- ROTAS DE PAGAMENTO COM MERCADO PAGO (PIX) ---

@app.route('/criar-pagamento', methods=['POST'])
def criar_pagamento():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('api_key', '').strip().lower()
    pacote_tipo = data.get('pacote', '30')

    if not email:
        return jsonify({"success": False, "error": "Usuário não identificado."}), 401

    # VALOR DE TESTE R$ 1.00
    tabela_pacotes = {
        '10': {'creditos': 10, 'valor': 1.00, 'titulo': 'Pacote 10 Créditos Dental Smile (Teste)'},
        '30': {'creditos': 30, 'valor': 1.00, 'titulo': 'Pacote 30 Créditos Dental Smile (Teste)'},
        '100': {'creditos': 100, 'valor': 1.00, 'titulo': 'Pacote 100 Créditos Dental Smile (Teste)'}
    }

    pacote = tabela_pacotes.get(str(pacote_tipo), tabela_pacotes['30'])

    try:
        payment_data = {
            "transaction_amount": float(pacote['valor']),
            "description": pacote['titulo'],
            "payment_method_id": "pix",
            "payer": {
                "email": "test_user_buyer@test.com"
            },
            "metadata": {
                "email_dentista": email,
                "qtd_creditos": pacote['creditos']
            }
        }

        result = sdk.payment().create(payment_data)
        payment_response = result.get("response", {})

        if result.get("status") not in [200, 201]:
            raise Exception(f"Erro ao gerar Pix no Mercado Pago: {payment_response}")

        point_of_interaction = payment_response.get("point_of_interaction", {})
        qr_data = point_of_interaction.get("transaction_data", {}).get("qr_code", "")
        qr_base64 = point_of_interaction.get("transaction_data", {}).get("qr_code_base64", "")
        payment_id = payment_response.get("id")

        print(f"💳 [PIX CRIADO] ID: {payment_id} | Usuário real: {email} | Créditos: {pacote['creditos']} | Valor: R$ {pacote['valor']}")

        return jsonify({
            "success": True,
            "payment_id": payment_id,
            "qr_code": qr_data,
            "qr_code_base64": qr_base64,
            "valor": pacote['valor'],
            "creditos": pacote['creditos']
        }), 200

    except Exception as e:
        print(f"❌ Erro ao criar pagamento: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/webhook-mercadopago', methods=['POST'])
def webhook_mercadopago():
    data = request.get_json(force=True, silent=True) or {}
    print(f"🔔 [WEBHOOK RECEBIDO] Dados brutos: {data}")

    payment_id = None
    payment_info = data.get("data", {})
    payment_id = payment_info.get("id") or data.get("id")

    if not payment_id and "resource" in data:
        resource = str(data.get("resource", ""))
        if "payments" in resource:
            try:
                payment_id = resource.split("/")[-1]
            except Exception:
                pass

    if not payment_id:
        print("⚠️ [WEBHOOK] Notificação recebida sem ID de pagamento explicitado. Ignorando.")
        return jsonify({"status": "ignored"}), 200

    try:
        payment_result = sdk.payment().get(payment_id)
        payment_obj = payment_result.get("response", {})

        status = payment_obj.get("status")
        metadata = payment_obj.get("metadata", {})

        email_dentista = metadata.get("email_dentista")
        qtd_creditos = int(metadata.get("qtd_creditos", 0))

        print(f"🔔 [WEBHOOK MP] Pagamento ID {payment_id} | Status: {status} | Usuário: {email_dentista} | Créditos: {qtd_creditos}")

        if status == "approved" and email_dentista and qtd_creditos > 0:
            conn = get_db_connection()
            cur = conn.cursor()

            novo_limite = 1
            if qtd_creditos >= 100:
                novo_limite = 3
            elif qtd_creditos >= 30:
                novo_limite = 2

            cur.execute("""
                UPDATE usuarios
                SET creditos = creditos + %s,
                    limite_dispositivos = GREATEST(COALESCE(limite_dispositivos, 1), %s)
                WHERE email = %s
                RETURNING creditos, limite_dispositivos;
            """, (qtd_creditos, novo_limite, email_dentista))

            res = cur.fetchone()
            conn.commit()
            cur.close()
            conn.close()

            if res:
                print(f"✅ [CRÉDITOS LIBERADOS] {qtd_creditos} créditos adicionados para {email_dentista}. Novo saldo: {res[0]}")

        return jsonify({"status": "success"}), 200

    except Exception as e:
        print(f"❌ Erro no Webhook do Mercado Pago: {str(e)}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500

# --- FIM DAS ROTAS DE PAGAMENTO ---

@app.route('/process-smile', methods=['POST'])
def process_smile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    device_id = data.get('device_id', '').strip()

    if not api_key:
        return jsonify({"success": False, "error": "Faça login e valide seu e-mail para simular."}), 401

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos, email_verificado, limite_dispositivos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
    user = cur.fetchone()

    if not user:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Conta não encontrada."}), 404

    creditos_atuais, email_verificado, limite_disp = user
    limite_disp = limite_disp or 1

    if not email_verificado:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Valide seu e-mail antes de realizar simulações."}), 403

    permitido, msg_disp = validar_limite_dispositivo(cur, api_key, device_id, limite_disp)
    if not permitido:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": msg_disp}), 403

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
        if "," in image_b64:
            image_b64 = image_b64.split(",")[1]

        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image

        rgb_image = orig_image.convert("RGB")
        img_512 = rgb_image.resize((512, 512), Image.Resampling.LANCZOS)

        print("=" * 60)
        print(f"📥 [PYTHON REST] Imagem recebida | Cor selecionada: {selected_color.upper()}")
        print("=" * 60)

        buffered_orig = io.BytesIO()
        img_512.save(buffered_orig, format="JPEG", quality=92)
        b64_clean = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')
        original_processed_b64 = b64_clean

        replicate_token = os.environ.get("REPLICATE_API_TOKEN")
        headers = {
            "Authorization": f"Bearer {replicate_token}",
            "Content-Type": "application/json"
        }

        print("☁️ [REPLICATE] Enviando imagem para o repositório de arquivos...")
        file_resp = requests.post(
            "https://api.replicate.com/v1/files",
            headers={"Authorization": f"Bearer {replicate_token}"},
            files={"content": ("image.jpg", buffered_orig.getvalue(), "image/jpeg")},
            timeout=30
        )

        if file_resp.status_code not in [200, 201]:
            raise Exception(f"Erro ao enviar arquivo para o Replicate: {file_resp.text}")

        file_data = file_resp.json()
        input_image_url = file_data.get("urls", {}).get("get") or file_data.get("url")

        print("🚀 [REPLICATE REST] Disparando Official Model Black Forest Labs Flux 2 Pro...")

        prompt_text = (
            "photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1> "
            "upper teeth only, (Beautiful natural teeth), aligned white teeth, "
            "human like teeth, (no teeth gap), celebrity-like teeth, "
            "healthy teeth with a perfect smile, not big incisor, good proportion teeth"
        )

        payload = {
            "input": {
                "input_images": [input_image_url],
                "prompt": prompt_text,
                "aspect_ratio": "1:1",
                "output_format": "webp",
                "output_quality": 80,
                "resolution": "1 MP",
                "safety_tolerance": 2
            }
        }

        response = requests.post(
            "https://api.replicate.com/v1/models/black-forest-labs/flux-2-pro/predictions",
            json=payload,
            headers=headers,
            timeout=120
        )

        if response.status_code not in [200, 201]:
            raise Exception(f"Erro na API do Replicate ({response.status_code}): {response.text}")

        pred_data = response.json()
        get_url = pred_data.get("urls", {}).get("get")

        if not get_url:
            raise Exception("URL de rastreio do Replicate não retornada.")

        image_url = None
        for _ in range(90):
            time.sleep(2)
            poll_resp = requests.get(get_url, headers=headers, timeout=30)
            poll_data = poll_resp.json()
            status = poll_data.get("status")

            if status == "succeeded":
                output = poll_data.get("output")
                if isinstance(output, list) and len(output) > 0:
                    image_url = output[0]
                else:
                    image_url = output
                print("✅ [REPLICATE] Simulação Flux 2 Pro recebida com sucesso!")
                break
            elif status == "failed":
                raise Exception(f"Processamento da IA falhou: {poll_data.get('error')}")

        if not image_url:
            raise Exception("Tempo limite excedido aguardando o Replicate.")

        img_download = requests.get(image_url, timeout=30)
        if img_download.status_code != 200:
            raise Exception(f"Erro ao baixar imagem gerada: {img_download.status_code}")

        ai_image_raw = Image.open(io.BytesIO(img_download.content)).convert("RGB")
        ai_crop_restaurado = ai_image_raw.resize((512, 512), Image.Resampling.LANCZOS)

        ai_np = np.array(ai_crop_restaurado).astype(np.float32)

        hsv_ai = cv2.cvtColor(ai_np.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
        tooth_mask_sup = ((hsv_ai[:, :, 2] > 110) & (hsv_ai[:, :, 1] < 115)).astype(np.float32)
        tooth_mask_sup_smooth = cv2.GaussianBlur(tooth_mask_sup, (7, 7), 0)

        r_gain, g_gain, b_gain = 1.00, 1.00, 1.00
        if selected_color == 'bl1':
            r_gain, g_gain, b_gain = 1.02, 1.01, 0.96
        elif selected_color == 'bl2':
            r_gain, g_gain, b_gain = 1.03, 1.01, 0.93
        elif selected_color == 'bl3':
            r_gain, g_gain, b_gain = 1.04, 1.00, 0.89
        elif selected_color == 'bl4':
            r_gain, g_gain, b_gain = 1.05, 0.99, 0.85

        ai_colorido_np = ai_np.copy()
        ai_colorido_np[:, :, 0] = np.clip(ai_np[:, :, 0] * (1.0 + (r_gain - 1.0) * tooth_mask_sup_smooth), 0, 255)
        ai_colorido_np[:, :, 1] = np.clip(ai_np[:, :, 1] * (1.0 + (g_gain - 1.0) * tooth_mask_sup_smooth), 0, 255)
        ai_colorido_np[:, :, 2] = np.clip(ai_np[:, :, 2] * (1.0 + (b_gain - 1.0) * tooth_mask_sup_smooth), 0, 255)

        imagem_final_rgb = ai_colorido_np.astype(np.uint8)

        final_bgr = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2BGR)
        _, buffer = cv2.imencode('.jpg', final_bgr, [cv2.IMWRITE_JPEG_QUALITY, 95])
        processed_b64 = base64.b64encode(buffer).decode('utf-8')

        cur.execute("UPDATE usuarios SET creditos = creditos - 1 WHERE api_key = %s OR email = %s RETURNING creditos;", (api_key, api_key))
        novo_saldo = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()

        print("=" * 60)
        print("📤 [PYTHON REST] Simulação concluída com sucesso absoluto (Flux 2 Pro)!")
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
        print(f"❌ Erro crítico no backend: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)