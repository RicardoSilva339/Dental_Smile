import os
import io
import base64
import time
import urllib.request
import psycopg2
import traceback
import requests
import numpy as np
from flask import Flask, request, jsonify
from PIL import Image, ImageOps, ImageFilter
import cv2

app = Flask(__name__)

@app.route('/', methods=['GET', 'HEAD'])
def health_check():
    return "Dental Smile Backend OK", 200

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

print("⚙️ Servidor iniciado com sucesso (Base estável + Calibração Cirúrgica Bleach BL1-BL4)")

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
        """, (email, nome, email, cro, senha))
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
        if "," in image_b64:
            image_b64 = image_b64.split(",")[1]

        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image

        rgb_image = orig_image.convert("RGB")

        img_512 = rgb_image.resize((512, 512), Image.Resampling.LANCZOS)
        imagem_rgb = np.array(img_512)
        altura, largura, _ = imagem_rgb.shape

        print("=" * 60)
        print(f"📥 [PYTHON REST] Imagem 512x512 recebida | Cor selecionada: {selected_color.upper()}")
        print("=" * 60)

        buffered_orig = io.BytesIO()
        img_512.save(buffered_orig, format="JPEG", quality=90)
        original_processed_b64 = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')

        mascara_sup = np.zeros((512, 512), dtype=np.uint8)

        # 🛠️ Máscara estável comprovada no "Novo Mundo"
        box_x1 = int(512 * 0.22)
        box_x2 = int(512 * 0.78)
        box_sup_y1 = int(512 * 0.38)
        box_sup_y2 = int(512 * 0.54)

        cv2.rectangle(mascara_sup, (box_x1, box_sup_y1), (box_x2, box_sup_y2), 255, -1)

        kernel = np.ones((3, 3), np.uint8)
        mascara_sup_dilatada = cv2.dilate(mascara_sup, kernel, iterations=1)

        mask_512 = Image.fromarray(mascara_sup_dilatada)

        buffered_img_512 = io.BytesIO()
        img_512.save(buffered_img_512, format="JPEG", quality=90)
        image_uri = f"data:image/jpeg;base64,{base64.b64encode(buffered_img_512.getvalue()).decode('utf-8')}"

        buffered_mask_512 = io.BytesIO()
        mask_512.save(buffered_mask_512, format="PNG")
        mask_uri = f"data:image/png;base64,{base64.b64encode(buffered_mask_512.getvalue()).decode('utf-8')}"

        print("🚀 [REPLICATE REST] Disparando IA na arcada superior...")

        replicate_token = os.environ.get("REPLICATE_API_TOKEN")
        headers = {
            "Authorization": f"Bearer {replicate_token}",
            "Content-Type": "application/json"
        }

        prompt_text = (
            f"photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1>(Beautiful natural teeth, aligned bite teeth), "
            f"aligned white teeth, human like teeth, (no teeth gap), celebrity-like teeth, healthy teeth with a perfect smile, not big incisor, good proportion teeth, shade {selected_color.upper()}, good proportion smile,"
        )
        negative_prompt_text = (
            "(deformed teeth, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime), "
            "(deformed, distorted, abnormal teeth:1.3, disfigured:1.3, large teeth:2), poorly drawn, Fixer, bad anatomy, rabbit teeth, "
            "wrong anatomy, missing teeth, disconnected teeth, unnatural mouth, bunny teeth, big incisor teeth, disproportionate front teeth, "
            "bad smile, reflection, crooked teeth, distorted teeth, cropped, out of frame, worst quality, low quality, "
            "jpeg artifacts, ugly, morbid, disfigured, gross proportions, too many teeth, lipstick, lip gloss, "
            "too less teeth, unnatural size teeth, poorly drawn mouth, poorly drawn teeth"
        )

        payload = {
            "version": "4956c634b9aa976129f13166c713f8cf38bd337cd58c77925e8cd71d935d5696",
            "input": {
                "image": image_uri,
                "mask": mask_uri,
                "prompt": prompt_text,
                "negative_prompt": negative_prompt_text,
                "num_outputs": 1,
                "num_inference_steps": 25,
                "guidance_scale": 6.0
            }
        }

        response = requests.post("https://api.replicate.com/v1/predictions", json=payload, headers=headers, timeout=120)

        if response.status_code != 201:
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
                image_url = output[0] if isinstance(output, list) else output
                break
            elif status == "failed":
                raise Exception(f"Processamento da IA falhou: {poll_data.get('error')}")

        if not image_url:
            raise Exception("Tempo limite excedido aguardando o Replicate.")

        with urllib.request.urlopen(image_url) as url_response:
            ai_image_bytes = url_response.read()

        ai_image_raw = Image.open(io.BytesIO(ai_image_bytes)).convert("RGB")
        ai_crop_restaurado = ai_image_raw.resize((512, 512), Image.Resampling.LANCZOS)

        # 🎨 CALIBRAÇÃO CIRÚRGICA DE CORES BLEACH (BL1 a BL4) - Suavidade natural idêntica à referência
        ai_np = np.array(ai_crop_restaurado)
        hsv_ai = cv2.cvtColor(ai_np, cv2.COLOR_RGB2HSV).astype(np.float32)

        if selected_color == 'bl1':
            # BL1: Ultra iluminado e brilhante, preservando a textura do esmalte puro
            hsv_ai[:, :, 2] = np.clip(hsv_ai[:, :, 2] * 1.02, 0, 255)
            hsv_ai[:, :, 1] = np.clip(hsv_ai[:, :, 1] * 0.98, 0, 255)
        elif selected_color == 'bl2':
            # BL2: Branco intenso com micro-toque natural
            hsv_ai[:, :, 2] = np.clip(hsv_ai[:, :, 2] * 1.00, 0, 255)
            hsv_ai[:, :, 1] = np.clip(hsv_ai[:, :, 1] * 1.00, 0, 255)
        elif selected_color == 'bl3':
            # BL3: Natural equilibrado (marfim levemente acolhedor)
            hsv_ai[:, :, 2] = np.clip(hsv_ai[:, :, 2] * 0.98, 0, 255)
            hsv_ai[:, :, 1] = np.clip(hsv_ai[:, :, 1] * 1.03, 0, 255)
        elif selected_color == 'bl4':
            # BL4: Suave e orgânico (tom de esmalte natural mais quente)
            hsv_ai[:, :, 2] = np.clip(hsv_ai[:, :, 2] * 0.96, 0, 255)
            hsv_ai[:, :, 1] = np.clip(hsv_ai[:, :, 1] * 1.06, 0, 255)

        ai_crop_restaurado = Image.fromarray(cv2.cvtColor(hsv_ai.astype(np.uint8), cv2.COLOR_HSV2RGB))

        # Fusão suave com a imagem original
        crop_orig_pil = Image.fromarray(imagem_rgb)
        crop_mask_pil = Image.fromarray(mascara_sup_dilatada)
        mask_soft = crop_mask_pil.filter(ImageFilter.GaussianBlur(radius=3))

        crop_final_pil = Image.composite(ai_crop_restaurado, crop_orig_pil, mask_soft)
        imagem_final_rgb = np.array(crop_final_pil)

        final_bgr = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2BGR)
        _, buffer = cv2.imencode('.jpg', final_bgr, [cv2.IMWRITE_JPEG_QUALITY, 95])
        processed_b64 = base64.b64encode(buffer).decode('utf-8')

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
        print("📤 [PYTHON REST] Simulação concluída com calibração de cor cirúrgica!")
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