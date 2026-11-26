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

mp_access_token = os.environ.get("MP_ACCESS_TOKEN", "").strip()
if not mp_access_token:
    print("ATENCAO: MP_ACCESS_TOKEN nao foi encontrado nas variaveis de ambiente!")
else:
    print(f"Mercado Pago inicializado com token: {mp_access_token[:10]}...")

sdk = mercadopago.SDK(mp_access_token)

# Tabela oficial de pacotes comerciais em producao
TABELA_PACOTES = {
    '10': {'creditos': 10, 'valor': '79.00', 'titulo': 'Pacote 10 Creditos Dental Smile'},
    '30': {'creditos': 30, 'valor': '199.00', 'titulo': 'Pacote 30 Creditos Dental Smile'},
    '100': {'creditos': 100, 'valor': '579.00', 'titulo': 'Pacote 100 Creditos Dental Smile'}
}

# Referencia de tons (1 a 29) e faixas alvo para BL1-BL4
SHADE_MAP = {
     1: "0M1",
     2: "0M2",
     3: "0M3",
     4: "1M1",
     5: "1M2",
     6: "1M3",
     7: "2L1.5",
     8: "2L2.5",
     9: "2M1",
    10: "2M2",
    11: "2M3",
    12: "2R1.5",
    13: "2R2.5",
    14: "3L1.5",
    15: "3L2.5",
    16: "3M1",
    17: "3M2",
    18: "3M3",
    19: "3R1.5",
    20: "3R2.5",
    21: "4L1.5",
    22: "4L2.5",
    23: "4M1",
    24: "4M2",
    25: "4M3",
    26: "4R1.5",
    27: "4R2.5",
    28: "5M2",
    29: "5M3"
}

ESCALA_BL_REFERENCIA = {
    'bl1': {'indices': [1], 'tons': [SHADE_MAP[1]]},
    'bl2': {'indices': [4, 5], 'tons': [SHADE_MAP[4], SHADE_MAP[5]]},
    'bl3': {'indices': [17, 19], 'tons': [SHADE_MAP[17], SHADE_MAP[19]]},
    'bl4': {'indices': [27, 29], 'tons': [SHADE_MAP[27], SHADE_MAP[29]]},
}

# Tabela oficial Mercado Pago (Taxa base vendedora: 4.98% | Acrescimos parcelado comprador 2x a 10x)
TAXA_BASE_CARTAO = 0.0498
TABELA_JUROS_PARCELAS_MP = {
    1: 0.0000,
    2: 0.0964,
    3: 0.1123,
    4: 0.1136,
    5: 0.1431,
    6: 0.1432,
    7: 0.1672,
    8: 0.1673,
    9: 0.1969,
    10: 0.2065
}

def calcular_opcoes_cartao(valor_base_pix):
    valor_liquido_desejado = float(valor_base_pix)
    valor_base_cartao = round(valor_liquido_desejado / (1.0 - TAXA_BASE_CARTAO), 2)
    opcoes = []
    for parcelas in range(1, 11):
        taxa_mp = TABELA_JUROS_PARCELAS_MP.get(parcelas, 0.0)
        total_comprador = round(valor_base_cartao * (1.0 + taxa_mp), 2)
        valor_parcela = round(total_comprador / parcelas, 2)
        opcoes.append({
            "parcelas": parcelas,
            "valor_base_order": f"{valor_base_cartao:.2f}",
            "valor_parcela": valor_parcela,
            "total_comprador": total_comprador,
            "label": (
                f"1x de R$ {total_comprador:.2f} (a vista no cartao)"
                if parcelas == 1
                else f"{parcelas}x de R$ {valor_parcela:.2f} (Total R$ {total_comprador:.2f})"
            )
        })
    return valor_base_cartao, opcoes

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

        cur.execute("""
            CREATE TABLE IF NOT EXISTS pedidos_mp (
                id SERIAL PRIMARY KEY,
                order_id VARCHAR(100) UNIQUE NOT NULL,
                email_dentista VARCHAR(100) NOT NULL,
                qtd_creditos INTEGER NOT NULL,
                creditado BOOLEAN DEFAULT FALSE,
                metodo_pagamento VARCHAR(30) DEFAULT 'pix',
                valor_pago VARCHAR(20),
                parcelas INTEGER DEFAULT 1,
                criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

        cur.execute("ALTER TABLE pedidos_mp ADD COLUMN IF NOT EXISTS metodo_pagamento VARCHAR(30) DEFAULT 'pix';")
        cur.execute("ALTER TABLE pedidos_mp ADD COLUMN IF NOT EXISTS valor_pago VARCHAR(20);")
        cur.execute("ALTER TABLE pedidos_mp ADD COLUMN IF NOT EXISTS parcelas INTEGER DEFAULT 1;")

        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Erro ao inicializar o banco: {e}")

init_db()

print("Servidor iniciado com Virada de Ouro Flux 2 Pro (BL1-BL4 + Harmonizacao) + Mercado Pago")

def enviar_email_codigo(destinatario, nome, codigo, assunto="Codigo de Verificacao - Dental Smile"):
    if not RESEND_API_KEY:
        print(f"[MODO TESTE SEM RESEND_API_KEY] Codigo para {destinatario}: {codigo}")
        return True

    saudacao = f"Ola, Dr(a). {nome}!" if nome else "Ola!"
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #5C6BC0; text-align: center;">Dental Smile</h2>
        <p>{saudacao}</p>
        <p>Use o codigo de 6 digitos abaixo para validar seu acesso:</p>
        <div style="background-color: #f4f6f9; padding: 15px; text-align: center; border-radius: 8px; margin: 20px 0;">
            <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #333;">{codigo}</span>
        </div>
        <p style="font-size: 12px; color: #777;">Se voce nao solicitou este codigo, apenas ignore este e-mail.</p>
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
        return False, f"Limite de {limite} dispositivo(s) simultaneo(s) atingido para o seu plano."

    cur.execute("INSERT INTO dispositivos_ativos (email_dentista, device_id) VALUES (%s, %s);", (email, device_id))
    return True, "OK"

def creditar_usuario_por_email(email_dentista, qtd_creditos):
    if not email_dentista or qtd_creditos <= 0:
        return None

    email_limpo = email_dentista.strip().lower()
    novo_limite = 1
    if qtd_creditos >= 100:
        novo_limite = 3
    elif qtd_creditos >= 30:
        novo_limite = 2

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE usuarios
        SET creditos = creditos + %s,
            limite_dispositivos = GREATEST(COALESCE(limite_dispositivos, 1), %s)
        WHERE email = %s OR api_key = %s
        RETURNING creditos, limite_dispositivos;
    """, (qtd_creditos, novo_limite, email_limpo, email_limpo))
    res = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return res

def obter_dados_pagador(email, cpf_pagador, incluir_nome=True, email_override=None):
    email_payer = (email_override or email or "").strip().lower()
    cpf_limpo = "".join(filter(str.isdigit, cpf_pagador or ""))
    if len(cpf_limpo) != 11:
        cpf_limpo = "19119119100"

    payer = {
        "email": email_payer,
        "identification": {
            "type": "CPF",
            "number": cpf_limpo
        }
    }

    if incluir_nome:
        primeiro_nome = "APRO"
        sobrenome = "Dentista"
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("SELECT nome FROM usuarios WHERE email = %s OR api_key = %s;", (email, email))
            user_row = cur.fetchone()
            if user_row and user_row[0] and user_row[0].strip():
                partes_nome = user_row[0].strip().split(" ", 1)
                primeiro_nome = partes_nome[0]
                sobrenome = partes_nome[1] if len(partes_nome) > 1 else "Silva"
            cur.close()
            conn.close()
        except Exception as db_err:
            print(f"Aviso ao consultar nome do pagador: {db_err}")

        payer["first_name"] = primeiro_nome
        payer["last_name"] = sobrenome

    return payer

def construir_mascara_dentes(ai_rgb_np, max_pixels=11800):
    h, w, _ = ai_rgb_np.shape
    y_grid, x_grid = np.mgrid[0:h, 0:w].astype(np.float32)

    # Centro e raios ajustados para cobrir margem cervical superior, pre-molares laterais e arcada inferior
    cy, cx = h * 0.498, w * 0.50
    ry, rx = h * 0.142, w * 0.34
    dist_norm = np.sqrt(((y_grid - cy) / ry) ** 2 + ((x_grid - cx) / rx) ** 2)
    mouth_zone = np.clip(1.0 - np.maximum(0.0, (dist_norm - 0.68) / 0.32), 0.0, 1.0)
    mouth_zone = cv2.GaussianBlur(mouth_zone, (13, 13), 0)

    hsv_ai = cv2.cvtColor(ai_rgb_np.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)

    # Limiar adaptativo ao brilho medio da boca para cobrir bordas escuras/laterais sem pegar pele
    y1, y2 = int(h * 0.43), int(h * 0.61)
    x1, x2 = int(w * 0.25), int(w * 0.75)
    v_boca_ref = float(hsv_ai[y1:y2, x1:x2, 2].mean())
    v_min = 114.0 if v_boca_ref < 172.0 else 138.0
    s_max = 118.0 if v_boca_ref < 172.0 else 92.0

    # Evita selecionar labios fortemente avermelhados (H em 0..14 ou 165..180 com saturação alta)
    hue = hsv_ai[:, :, 0]
    sat = hsv_ai[:, :, 1]
    val = hsv_ai[:, :, 2]
    nao_labio = ~(((hue < 14.0) | (hue > 165.0)) & (sat > 115.0))

    tooth_raw = (
        (val > v_min) &
        (sat < s_max) &
        nao_labio &
        (mouth_zone > 0.20)
    ).astype(np.float32)

    # Fechamento morfologico para conectar microdiastemas, bordas cervicais e dentes inferiores
    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 6))
    tooth_closed = cv2.morphologyEx(tooth_raw, cv2.MORPH_CLOSE, close_kernel)
    tooth_mask = cv2.GaussianBlur(tooth_closed * mouth_zone, (5, 5), 0)

    # Contencao de area caso a mascara exceda o teto de pixels
    ativos = int(np.sum(tooth_mask > 0.10))
    if ativos > max_pixels:
        kernel = np.ones((3, 3), np.uint8)
        iteracoes = min(3, max(1, (ativos - max_pixels) // 1400 + 1))
        eroded = cv2.erode(tooth_mask, kernel, iterations=iteracoes)
        tooth_mask = cv2.GaussianBlur(eroded, (5, 5), 0)

    return tooth_mask

def aplicar_calibracao_e_preservar_pele(orig_rgb_np, ai_rgb_np, selected_color):
    """
    Aplica a calibracao BL1-BL4 com controle de brilho (V), area da mascara,
    preservacao dos labios/pele e preenchimento de diastemas/arcada inferior.
    """
    ai_float = ai_rgb_np.astype(np.float32)
    orig_float = orig_rgb_np.astype(np.float32)
    tooth_mask = construir_mascara_dentes(ai_rgb_np, max_pixels=11800)

    if selected_color == 'bl1':
        r_gain, g_gain, b_gain = 1.032, 1.052, 1.085
        saturation, brightness = 0.78, 1.042
        alpha_ia = 1.00
        teto_v = 186.0
    elif selected_color == 'bl2':
        r_gain, g_gain, b_gain = 1.020, 1.042, 1.075
        saturation, brightness = 0.85, 1.028
        alpha_ia = 1.00
        teto_v = 190.0
    elif selected_color == 'bl3':
        r_gain, g_gain, b_gain = 1.024, 0.976, 0.875
        saturation, brightness = 1.18, 0.965
        alpha_ia = 0.42
        teto_v = 185.0
    elif selected_color == 'bl4':
        r_gain, g_gain, b_gain = 1.024, 0.976, 0.875
        saturation, brightness = 1.18, 0.965
        alpha_ia = 0.40
        teto_v = 186.0
    else:
        r_gain, g_gain, b_gain = 1.020, 1.042, 1.075
        saturation, brightness = 0.85, 1.028
        alpha_ia = 1.00
        teto_v = 190.0

    calibrada = ai_float.copy()
    calibrada[:, :, 0] = np.clip(ai_float[:, :, 0] * (1.0 + (r_gain - 1.0) * tooth_mask), 0, 255)
    calibrada[:, :, 1] = np.clip(ai_float[:, :, 1] * (1.0 + (g_gain - 1.0) * tooth_mask), 0, 255)
    calibrada[:, :, 2] = np.clip(ai_float[:, :, 2] * (1.0 + (b_gain - 1.0) * tooth_mask), 0, 255)

    hsv_adj = cv2.cvtColor(calibrada.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    hsv_adj[:, :, 1] = np.clip(hsv_adj[:, :, 1] * (1.0 + (saturation - 1.0) * tooth_mask), 0, 255)
    hsv_adj[:, :, 2] = np.clip(hsv_adj[:, :, 2] * (1.0 + (brightness - 1.0) * tooth_mask), 0, 255)
    calibrada = cv2.cvtColor(hsv_adj.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32)

    # Nas regioes onde a foto original tinha diastema/sombra/falha e a IA reconstruiu dente,
    # garante peso da IA restrito a dente real (nao labial) para nao manchar o labio inferior
    hsv_ai_check = cv2.cvtColor(ai_rgb_np.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    hue_ai = hsv_ai_check[:, :, 0]
    sat_ai = hsv_ai_check[:, :, 1]
    dente_ai_valido = (~(((hue_ai < 14.0) | (hue_ai > 165.0)) & (sat_ai > 110.0))).astype(np.float32)

    luma_orig = orig_float.mean(axis=2)
    luma_ai = ai_float.mean(axis=2)
    gap_preenchido = np.clip((luma_ai - luma_orig - 24.0) / 38.0, 0.0, 1.0) * tooth_mask * dente_ai_valido

    alpha_efetivo = np.maximum(tooth_mask * alpha_ia, gap_preenchido * 0.90)
    blend_mask = np.clip(alpha_efetivo, 0.0, 1.0)
    blend_mask_3c = np.repeat(blend_mask[:, :, np.newaxis], 3, axis=2)

    resultado = calibrada * blend_mask_3c + orig_float * (1.0 - blend_mask_3c)

    if selected_color == 'bl4':
        resultado[:, :, 0] = np.clip(resultado[:, :, 0] * (1.0 + 0.008 * tooth_mask), 0, 255)
        resultado[:, :, 1] = np.clip(resultado[:, :, 1] * (1.0 - 0.004 * tooth_mask), 0, 255)
        resultado[:, :, 2] = np.clip(resultado[:, :, 2] * (1.0 - 0.062 * tooth_mask), 0, 255)

        hsv_bl4 = cv2.cvtColor(np.clip(resultado, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
        hsv_bl4[:, :, 1] = np.clip(hsv_bl4[:, :, 1] * (1.0 + 0.055 * tooth_mask), 0, 255)
        hsv_bl4[:, :, 2] = np.clip(hsv_bl4[:, :, 2] * (1.0 - 0.012 * tooth_mask), 0, 255)
        resultado = cv2.cvtColor(hsv_bl4.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32)

    # Contencao suave de brilho (V) na regiao da boca quando a iluminacao vier elevada
    h_m, w_m, _ = resultado.shape
    y1, y2 = int(h_m * 0.44), int(h_m * 0.60)
    x1, x2 = int(w_m * 0.30), int(w_m * 0.70)
    hsv_res = cv2.cvtColor(np.clip(resultado, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    v_boca_atual = float(hsv_res[y1:y2, x1:x2, 2].mean())
    if v_boca_atual > teto_v and v_boca_atual > 0:
        fator_v = min(1.0, (teto_v / v_boca_atual) ** 0.65)
        hsv_res[:, :, 2] = np.clip(hsv_res[:, :, 2] * (1.0 - (1.0 - fator_v) * tooth_mask), 0, 255)
        resultado = cv2.cvtColor(hsv_res.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32)

    return np.clip(resultado, 0, 255).astype(np.uint8)

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(force=True, silent=True) or {}
    nome = data.get('nome', '').strip()
    email = data.get('email', '').strip().lower()
    cro = data.get('cro', '').strip()
    senha = data.get('senha', '')

    if not email or not senha:
        return jsonify({"success": False, "error": "E-mail e senha sao obrigatorios."}), 400

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
                return jsonify({"success": False, "error": "Este e-mail ja esta cadastrado e ativo."}), 400
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

        enviar_email_codigo(email, nome, codigo_otp, "Ative sua conta - Codigo Dental Smile")

        return jsonify({
            "success": True,
            "requer_verificacao": True,
            "message": "Codigo de 6 digitos enviado para o seu e-mail!"
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
        return jsonify({"success": False, "error": "E-mail e codigo sao obrigatorios."}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, codigo_verificacao, email_verificado, nome, limite_dispositivos FROM usuarios WHERE email = %s;", (email,))
        user = cur.fetchone()

        if not user:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Usuario nao encontrado."}), 404

        user_id, codigo_salvo, ja_verificado, nome, limite_disp = user

        if ja_verificado:
            cur.close()
            conn.close()
            return jsonify({"success": True, "message": "Conta ja verificada!"}), 200

        if codigo != codigo_salvo:
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Codigo incorreto. Verifique seu e-mail e tente novamente."}), 400

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
            "message": "E-mail confirmado! Seus 3 creditos gratuitos foram liberados."
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
            return jsonify({"success": False, "error": "E-mail nao encontrado."}), 404

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
            enviar_email_codigo(email, nome, novo_codigo, "Ative sua conta - Codigo Dental Smile")
            return jsonify({
                "success": False,
                "requer_verificacao": True,
                "error": "E-mail ainda nao confirmado. Enviamos um novo codigo de 6 digitos para voce."
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
            return jsonify({"success": False, "error": "E-mail nao encontrado no sistema."}), 404

        user_id, nome = user
        codigo_recuperacao = f"{random.randint(100000, 999999)}"

        cur.execute("UPDATE usuarios SET codigo_verificacao = %s WHERE id = %s;", (codigo_recuperacao, user_id))
        conn.commit()
        cur.close()
        conn.close()

        enviar_email_codigo(email, nome, codigo_recuperacao, "Recuperacao de Senha - Dental Smile")

        return jsonify({"success": True, "message": "Codigo de recuperacao enviado para o seu e-mail."}), 200
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
            return jsonify({"success": False, "error": "Codigo invalido ou expirado."}), 400

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
        return jsonify({"success": False, "error": "Usuario nao identificado."}), 400

    res = creditar_usuario_por_email(api_key, quantidade)

    if res:
        return jsonify({"success": True, "novo_saldo": res[0], "limite_dispositivos": res[1]}), 200
    return jsonify({"success": False, "error": "Conta nao encontrada."}), 404

@app.route('/simular-parcelas-cartao', methods=['POST'])
def simular_parcelas_cartao():
    data = request.get_json(force=True, silent=True) or {}
    pacote_tipo = str(data.get('pacote', '30'))
    pacote = TABELA_PACOTES.get(pacote_tipo, TABELA_PACOTES['30'])
    valor_pix = float(pacote['valor'])
    valor_base_cartao, opcoes = calcular_opcoes_cartao(valor_pix)

    return jsonify({
        "success": True,
        "pacote": pacote_tipo,
        "creditos": pacote['creditos'],
        "valor_pix": valor_pix,
        "valor_base_cartao": valor_base_cartao,
        "opcoes_parcelamento": opcoes
    }), 200

@app.route('/criar-pagamento', methods=['POST'])
def criar_pagamento():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('api_key', '').strip().lower()
    pacote_tipo = str(data.get('pacote', '30'))
    device_session_id = data.get('device_id', '').strip() or f"ds_device_{random.randint(100000, 999999)}"
    cpf_pagador = data.get('cpf', '').strip()

    if not email:
        return jsonify({"success": False, "error": "Usuario nao identificado."}), 401

    pacote = TABELA_PACOTES.get(pacote_tipo, TABELA_PACOTES['30'])
    qtd_creditos = pacote['creditos']
    payer_obj = obter_dados_pagador(email, cpf_pagador)

    try:
        order_url = "https://api.mercadopago.com/v1/orders"
        idempotency_key = f"ds_pix_{random.randint(10000000, 99999999)}_{int(time.time())}"

        headers = {
            "Authorization": f"Bearer {mp_access_token}",
            "Content-Type": "application/json",
            "X-Idempotency-Key": idempotency_key,
            "X-meli-session-id": device_session_id
        }

        safe_ext_ref = f"ds_pkg{qtd_creditos}_{random.randint(100000, 999999)}"

        order_payload = {
            "type": "online",
            "external_reference": safe_ext_ref,
            "total_amount": str(pacote['valor']),
            "payer": payer_obj,
            "items": [
                {
                    "title": pacote['titulo'],
                    "category_id": "services",
                    "unit_price": str(pacote['valor']),
                    "quantity": 1
                }
            ],
            "transactions": {
                "payments": [
                    {
                        "amount": str(pacote['valor']),
                        "payment_method": {
                            "id": "pix",
                            "type": "bank_transfer",
                            "statement_descriptor": "DENTAL SMILE"
                        }
                    }
                ]
            }
        }

        resp = requests.post(order_url, json=order_payload, headers=headers, timeout=30)
        order_response = resp.json()

        if resp.status_code not in [200, 201]:
            raise Exception(f"Erro ao criar Order Pix no Mercado Pago: {order_response}")

        order_id = str(order_response.get("id"))

        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO pedidos_mp (order_id, email_dentista, qtd_creditos, creditado, metodo_pagamento, valor_pago, parcelas)
                VALUES (%s, %s, %s, FALSE, 'pix', %s, 1)
                ON CONFLICT (order_id) DO NOTHING;
            """, (order_id, email, qtd_creditos, str(pacote['valor'])))
            conn.commit()
            cur.close()
            conn.close()
        except Exception as db_pedido_err:
            print(f"Aviso ao registrar pedido_mp Pix: {db_pedido_err}")

        transactions = order_response.get("transactions", {})
        payments_list = transactions.get("payments", [])
        payment_id = None
        qr_data = ""
        qr_base64 = ""

        if payments_list:
            first_payment = payments_list[0]
            payment_id = first_payment.get("id")
            payment_method = first_payment.get("payment_method", {})
            qr_data = payment_method.get("qr_code", "")
            qr_base64 = payment_method.get("qr_code_base64", "")

        print(f"[ORDER PIX CRIADA] Order ID: {order_id} | Payment ID: {payment_id} | Usuario: {email} | Creditos: {qtd_creditos}")

        return jsonify({
            "success": True,
            "payment_id": payment_id,
            "order_id": order_id,
            "qr_code": qr_data,
            "qr_code_base64": qr_base64,
            "valor": float(pacote['valor']),
            "creditos": qtd_creditos
        }), 200

    except Exception as e:
        print(f"Erro ao criar pagamento Pix via Orders API oficial: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/criar-pagamento-cartao', methods=['POST'])
def criar_pagamento_cartao():
    data = request.get_json(force=True, silent=True) or {}
    email = data.get('api_key', '').strip().lower()
    pacote_tipo = str(data.get('pacote', '30'))
    card_token = data.get('card_token', '').strip()
    payment_method_id = data.get('payment_method_id', '').strip().lower()
    parcelas = int(data.get('installments', 1) or 1)
    device_session_id = data.get('device_id', '').strip() or f"ds_device_{random.randint(100000, 999999)}"
    cpf_pagador = data.get('cpf', '').strip()

    if not email:
        return jsonify({"success": False, "error": "Usuario nao identificado."}), 401

    if not card_token:
        return jsonify({"success": False, "error": "Token do cartao nao informado."}), 400

    if parcelas < 1 or parcelas > 10:
        parcelas = 1

    pacote = TABELA_PACOTES.get(pacote_tipo, TABELA_PACOTES['30'])
    qtd_creditos = pacote['creditos']
    valor_base_cartao, opcoes = calcular_opcoes_cartao(pacote['valor'])
    opcao_escolhida = next((o for o in opcoes if o["parcelas"] == parcelas), opcoes[0])
    valor_order_str = f"{valor_base_cartao:.2f}"

    try:
        order_url = "https://api.mercadopago.com/v1/orders"
        idempotency_key = f"ds_cc_{random.randint(10000000, 99999999)}_{int(time.time())}"

        headers = {
            "Authorization": f"Bearer {mp_access_token}",
            "Content-Type": "application/json",
            "X-Idempotency-Key": idempotency_key,
            "X-meli-session-id": device_session_id
        }

        safe_ext_ref = f"ds_cc_pkg{qtd_creditos}_{random.randint(100000, 999999)}"
        pm_id = payment_method_id or "master"

        payment_method_obj = {
            "id": pm_id,
            "type": "credit_card",
            "token": card_token,
            "installments": parcelas,
            "statement_descriptor": "DENTAL SMILE"
        }

        tentativas_payer = [
            obter_dados_pagador(email, cpf_pagador, incluir_nome=False),
            obter_dados_pagador(email, cpf_pagador, incluir_nome=False, email_override="comprador_teste@dentalsmile.ia.br")
        ]

        resp = None
        order_response = {}
        for idx_p, payer_candidato in enumerate(tentativas_payer):
            order_payload = {
                "type": "online",
                "processing_mode": "automatic",
                "external_reference": safe_ext_ref,
                "total_amount": valor_order_str,
                "payer": payer_candidato,
                "items": [
                    {
                        "title": f"{pacote['titulo']} (Cartao)",
                        "category_id": "services",
                        "unit_price": valor_order_str,
                        "quantity": 1
                    }
                ],
                "transactions": {
                    "payments": [
                        {
                            "amount": valor_order_str,
                            "payment_method": payment_method_obj
                        }
                    ]
                }
            }

            headers_tentativa = dict(headers)
            headers_tentativa["X-Idempotency-Key"] = f"{idempotency_key}_p{idx_p}"

            resp = requests.post(order_url, json=order_payload, headers=headers_tentativa, timeout=30)
            order_response = resp.json()

            if resp.status_code in [200, 201] or resp.status_code != 422:
                break

        if resp is None or resp.status_code not in [200, 201]:
            status_code_log = resp.status_code if resp is not None else "N/A"
            print(f"[ERRO ORDER CARTAO MP] Status {status_code_log}: {order_response}")
            msg_erro = "Pagamento nao autorizado pela operadora do cartao."
            if isinstance(order_response, dict):
                errors_list = order_response.get("errors", [])
                if errors_list and isinstance(errors_list, list):
                    msg_erro = errors_list[0].get("message", msg_erro)
            return jsonify({"success": False, "error": msg_erro, "detalhes": order_response}), 400

        order_id = str(order_response.get("id"))
        order_status = str(order_response.get("status", "")).lower()
        order_status_detail = str(order_response.get("status_detail", "")).lower()

        payments_list = order_response.get("transactions", {}).get("payments", [])
        payment_id = None
        payment_status = ""
        payment_status_detail = ""
        if payments_list and isinstance(payments_list, list):
            first_payment = payments_list[0]
            payment_id = first_payment.get("id")
            payment_status = str(first_payment.get("status", "")).lower()
            payment_status_detail = str(first_payment.get("status_detail", "")).lower()

        aprovado = (order_status in ["processed", "paid", "approved"]) or (payment_status in ["approved", "processed"])
        novo_saldo = None

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO pedidos_mp (order_id, email_dentista, qtd_creditos, creditado, metodo_pagamento, valor_pago, parcelas)
            VALUES (%s, %s, %s, %s, 'credit_card', %s, %s)
            ON CONFLICT (order_id) DO NOTHING;
        """, (order_id, email, qtd_creditos, aprovado, f"{opcao_escolhida['total_comprador']:.2f}", parcelas))
        conn.commit()
        cur.close()
        conn.close()

        if aprovado:
            res = creditar_usuario_por_email(email, qtd_creditos)
            novo_saldo = res[0] if res else None
            print(f"[CARTAO APROVADO NA HORA] Order: {order_id} | Usuario: {email} | +{qtd_creditos} CR | Saldo: {novo_saldo}")
            return jsonify({
                "success": True,
                "aprovado": True,
                "status": "approved",
                "order_id": order_id,
                "payment_id": payment_id,
                "creditos": qtd_creditos,
                "novo_saldo": novo_saldo,
                "parcelas": parcelas,
                "total_pago": opcao_escolhida["total_comprador"],
                "message": f"Pagamento aprovado! +{qtd_creditos} creditos adicionados a sua conta."
            }), 200

        if order_status in ["action_required", "in_process", "pending"] or payment_status in ["in_process", "pending"]:
            print(f"[CARTAO EM ANALISE] Order: {order_id} | status={order_status} | detail={payment_status_detail}")
            return jsonify({
                "success": True,
                "aprovado": False,
                "status": "pending",
                "order_id": order_id,
                "payment_id": payment_id,
                "message": "Pagamento em analise pela operadora. Assim que aprovar, seus creditos serao liberados automaticamente!"
            }), 200

        print(f"[CARTAO RECUSADO] Order: {order_id} | status={order_status} | detail={payment_status_detail or order_status_detail}")
        return jsonify({
            "success": False,
            "aprovado": False,
            "status": "rejected",
            "status_detail": payment_status_detail or order_status_detail,
            "error": "Cartao recusado pela operadora. Verifique os dados ou tente outro cartao/Pix."
        }), 400

    except Exception as e:
        print(f"Erro critico no pagamento com cartao: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/webhook-mercadopago', methods=['GET', 'POST'])
def webhook_mercadopago():
    if request.method == 'GET':
        return jsonify({"status": "verified"}), 200

    data = request.get_json(force=True, silent=True) or {}
    query_params = request.args.to_dict()

    evento_tipo = data.get("type") or query_params.get("type") or ""
    data_obj = data.get("data", {}) if isinstance(data.get("data"), dict) else {}
    recurso_id = data_obj.get("id") or data.get("id") or query_params.get("data.id") or ""
    ext_ref_query = query_params.get("data.external_reference") or ""

    print(f"[WEBHOOK RECEBIDO] tipo={evento_tipo} | id={recurso_id} | ext_ref={ext_ref_query}")

    try:
        headers_mp = {
            "Authorization": f"Bearer {mp_access_token}",
            "Content-Type": "application/json"
        }

        if evento_tipo == "order" or str(recurso_id).startswith("ORD"):
            order_id = str(recurso_id)
            resp_order = requests.get(f"https://api.mercadopago.com/v1/orders/{order_id}", headers=headers_mp, timeout=20)
            if resp_order.status_code not in [200, 201]:
                print(f"[WEBHOOK ORDER ERRO] Status {resp_order.status_code}: {resp_order.text}")
                return jsonify({"status": "ignored"}), 200

            order_info = resp_order.json()
            order_status = str(order_info.get("status", "")).lower()
            ext_ref = str(order_info.get("external_reference") or ext_ref_query or "")

            payments_list = order_info.get("transactions", {}).get("payments", [])
            payment_status = ""
            if payments_list and isinstance(payments_list, list):
                payment_status = str(payments_list[0].get("status", "")).lower()

            aprovado = (order_status in ["processed", "paid", "approved"]) or (payment_status in ["approved", "processed"])
            print(f"[WEBHOOK ORDER] order_id={order_id} | order_status={order_status} | payment_status={payment_status} | aprovado={aprovado}")

            if aprovado:
                email_dentista = None
                qtd_creditos = 0
                ja_creditado = False

                conn = get_db_connection()
                cur = conn.cursor()
                cur.execute("SELECT email_dentista, qtd_creditos, creditado FROM pedidos_mp WHERE order_id = %s;", (order_id,))
                pedido_row = cur.fetchone()
                if pedido_row:
                    email_dentista = pedido_row[0]
                    qtd_creditos = int(pedido_row[1] or 0)
                    ja_creditado = bool(pedido_row[2])

                if ja_creditado:
                    cur.close()
                    conn.close()
                    print(f"[WEBHOOK ORDER DUPLICADO] order_id={order_id} ja creditado anteriormente.")
                    return jsonify({"status": "success"}), 200

                if not email_dentista:
                    payer_info = order_info.get("payer", {})
                    if isinstance(payer_info, dict) and payer_info.get("email"):
                        email_dentista = payer_info.get("email").strip().lower()

                if not qtd_creditos:
                    items_info = order_info.get("items", [])
                    if items_info and isinstance(items_info, list):
                        titulo_item = str(items_info[0].get("title", ""))
                        if "100" in titulo_item:
                            qtd_creditos = 100
                        elif "30" in titulo_item:
                            qtd_creditos = 30
                        elif "10" in titulo_item:
                            qtd_creditos = 10

                if email_dentista and qtd_creditos > 0:
                    res = creditar_usuario_por_email(email_dentista, qtd_creditos)
                    cur.execute("UPDATE pedidos_mp SET creditado = TRUE WHERE order_id = %s;", (order_id,))
                    conn.commit()
                    print(f"[CREDITOS ENTREGUES VIA ORDER] email={email_dentista} | +{qtd_creditos} | novo_saldo={res}")
                else:
                    print(f"[WEBHOOK ORDER SEM DADOS COMPLETOS] email={email_dentista} | creditos={qtd_creditos} | ext_ref={ext_ref}")

                cur.close()
                conn.close()

            return jsonify({"status": "success"}), 200

        payment_id = recurso_id
        if not payment_id and "resource" in data:
            resource = str(data.get("resource", ""))
            if "payments" in resource:
                payment_id = resource.split("/")[-1]

        if not payment_id:
            return jsonify({"status": "ignored"}), 200

        payment_result = sdk.payment().get(payment_id)
        payment_obj = payment_result.get("response", {})

        status = str(payment_obj.get("status", "")).lower()
        metadata = payment_obj.get("metadata", {}) if isinstance(payment_obj.get("metadata"), dict) else {}

        email_dentista = metadata.get("email_dentista") or (payment_obj.get("payer") or {}).get("email")
        qtd_creditos = int(metadata.get("qtd_creditos", 0) or 0)

        if status == "approved" and email_dentista and qtd_creditos > 0:
            res = creditar_usuario_por_email(email_dentista, qtd_creditos)
            print(f"[CREDITOS ENTREGUES VIA PAYMENT] email={email_dentista} | +{qtd_creditos} | novo_saldo={res}")

        return jsonify({"status": "success"}), 200

    except Exception as e:
        print(f"Erro no Webhook do Mercado Pago: {str(e)}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/process-smile', methods=['POST'])
def process_smile():
    data = request.get_json(force=True, silent=True) or {}
    api_key = data.get('api_key', '').strip().lower()
    device_id = data.get('device_id', '').strip()

    if not api_key:
        return jsonify({"success": False, "error": "Faca login e valide seu e-mail para simular."}), 401

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT creditos, email_verificado, limite_dispositivos FROM usuarios WHERE api_key = %s OR email = %s;", (api_key, api_key))
    user = cur.fetchone()

    if not user:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Conta nao encontrada."}), 404

    creditos_atuais, email_verificado, limite_disp = user
    limite_disp = limite_disp or 1

    if not email_verificado:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Valide seu e-mail antes de realizar simulacoes."}), 403

    permitido, msg_disp = validar_limite_dispositivo(cur, api_key, device_id, limite_disp)
    if not permitido:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": msg_disp}), 403

    if creditos_atuais <= 0:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Creditos insuficientes."}), 403

    image_b64 = data.get('image')
    selected_color = str(data.get('color') or 'bl2').strip().lower()

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
        orig_512_np = np.array(img_512)

        ref_info = ESCALA_BL_REFERENCIA.get(selected_color, ESCALA_BL_REFERENCIA['bl2'])
        print("=" * 60)
        print(f"[PYTHON REST] Imagem recebida | Cor: {selected_color.upper()} | Ref: {ref_info['tons']}")
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

        print("[REPLICATE] Enviando imagem para o repositorio de arquivos...")
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

        print("[REPLICATE REST] Disparando Official Model Black Forest Labs Flux 2 Pro...")

        prompt_text = (
            "photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1> "
            "preserve original face, skin tone, nose, eyes and lips, "
            "aesthetic smile design, closed diastema and micro gaps, "
            "smooth even incisal edges and crown proportions, "
            "harmonious aligned white teeth, complete upper and lower teeth, "
            "high sharpness, natural realistic enamel and porcelain sheen"
        )

        payload = {
            "input": {
                "input_images": [input_image_url],
                "prompt": prompt_text,
                "seed": 9283,
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
            raise Exception("URL de rastreio do Replicate nao retornada.")

        image_url = None
        poll_data = {}
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
                print("[REPLICATE] Simulacao Flux 2 Pro recebida com sucesso!")
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
        ai_np = np.array(ai_crop_restaurado)

        imagem_final_rgb = aplicar_calibracao_e_preservar_pele(orig_512_np, ai_np, selected_color)

        # --- LOG DIAGNOSTICO REPLICATE + POS-PROCESSAMENTO ---
        pred_id = poll_data.get("id")
        pred_status = poll_data.get("status")
        pred_metrics = poll_data.get("metrics", {})
        mask_diag = construir_mascara_dentes(ai_np, max_pixels=11800)
        pixels_ativos = int(np.sum(mask_diag > 0.10))

        hsv_orig = cv2.cvtColor(orig_512_np, cv2.COLOR_RGB2HSV).astype(np.float32)
        hsv_ai_raw = cv2.cvtColor(ai_np, cv2.COLOR_RGB2HSV).astype(np.float32)
        hsv_final = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2HSV).astype(np.float32)

        h_m, w_m, _ = orig_512_np.shape
        y1, y2 = int(h_m * 0.44), int(h_m * 0.60)
        x1, x2 = int(w_m * 0.30), int(w_m * 0.70)

        print("-" * 60)
        print(f"[DIAG] Cor={selected_color.upper()} | PredID={pred_id} | Status={pred_status} | Metrics={pred_metrics}")
        print(f"[DIAG] MaskPixels(>0.10)={pixels_ativos} | Model={poll_data.get('model')} | Version={poll_data.get('version')}")
        print(f"[DIAG] PollKeys={list(poll_data.keys())} | InputEco={poll_data.get('input')}")
        if poll_data.get("logs"):
            print(f"[DIAG] ReplicateLogs={poll_data.get('logs')}")
        print(f"[DIAG] Boca ORIG   RGB=({orig_512_np[y1:y2, x1:x2, 0].mean():.1f}, {orig_512_np[y1:y2, x1:x2, 1].mean():.1f}, {orig_512_np[y1:y2, x1:x2, 2].mean():.1f}) | S={hsv_orig[y1:y2, x1:x2, 1].mean():.1f} V={hsv_orig[y1:y2, x1:x2, 2].mean():.1f}")
        print(f"[DIAG] Boca AI_RAW RGB=({ai_np[y1:y2, x1:x2, 0].mean():.1f}, {ai_np[y1:y2, x1:x2, 1].mean():.1f}, {ai_np[y1:y2, x1:x2, 2].mean():.1f}) | S={hsv_ai_raw[y1:y2, x1:x2, 1].mean():.1f} V={hsv_ai_raw[y1:y2, x1:x2, 2].mean():.1f}")
        print(f"[DIAG] Boca FINAL  RGB=({imagem_final_rgb[y1:y2, x1:x2, 0].mean():.1f}, {imagem_final_rgb[y1:y2, x1:x2, 1].mean():.1f}, {imagem_final_rgb[y1:y2, x1:x2, 2].mean():.1f}) | S={hsv_final[y1:y2, x1:x2, 1].mean():.1f} V={hsv_final[y1:y2, x1:x2, 2].mean():.1f}")
        print("-" * 60)

        final_bgr = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2BGR)
        _, buffer = cv2.imencode('.jpg', final_bgr, [cv2.IMWRITE_JPEG_QUALITY, 95])
        processed_b64 = base64.b64encode(buffer).decode('utf-8')

        cur.execute("UPDATE usuarios SET creditos = creditos - 1 WHERE api_key = %s OR email = %s RETURNING creditos;", (api_key, api_key))
        novo_saldo = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()

        print("=" * 60)
        print(f"[PYTHON REST] Simulacao concluida com sucesso absoluto (Flux 2 Pro - {selected_color.upper()})!")
        print("=" * 60)

        return jsonify({
            "success": True,
            "original_image": original_processed_b64,
            "processed_image": processed_b64,
            "creditos_restantes": novo_saldo
        }), 200

    except Exception as e:
        if 'cur' in locals() and cur:
            cur.close()
        if 'conn' in locals() and conn:
            conn.close()
        print(f"Erro critico no backend: {str(e)}")
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)