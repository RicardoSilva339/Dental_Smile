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
import mediapipe as mp

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

# Inicializa o detector facial do MediaPipe para rodar na CPU do Render
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1, refine_landmarks=True)

print("⚙️ Servidor iniciado com MediaPipe FaceMesh ativo em CPU!")

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
        imagem_rgb = np.array(rgb_image)
        altura, largura, _ = imagem_rgb.shape

        buffered_orig = io.BytesIO()
        rgb_image.save(buffered_orig, format="JPEG", quality=90)
        original_processed_b64 = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')

        # Detecção real do rosto via MediaPipe FaceMesh na CPU
        results = face_mesh.process(imagem_rgb)
        if not results.multi_face_landmarks:
            raise Exception("Nenhum rosto detectado na imagem.")

        face_landmarks = results.multi_face_landmarks[0].landmark

        # 1. SMART SQUARE FACE CROP com base no centro real do rosto detectado
        y_coords = [int(pt.y * altura) for pt in face_landmarks]
        center_y = sum(y_coords) // len(y_coords)
        S = min(largura, altura)
        y1 = max(0, center_y - (S // 2))
        y2 = min(altura, y1 + S)
        if y2 - S >= 0:
            y1 = y2 - S
        x1, x2 = 0, S

        # 2. Máscara precisa da Arcada Superior baseada nos pontos reais da boca
        mascara_sup = np.zeros((altura, largura), dtype=np.uint8)
        pontos_sup = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308]
        coordenadas_sup = [(int(face_landmarks[i].x * largura), int(face_landmarks[i].y * altura)) for i in pontos_sup]
        cv2.fillPoly(mascara_sup, [np.array(coordenadas_sup, np.int32)], 255)
        mascara_sup_dilatada = cv2.dilate(mascara_sup, np.ones((3, 3), np.uint8), iterations=1)

        # 3. Máscara precisa da Arcada Inferior (para clareamento sem alterar o formato)
        mascara_inf = np.zeros((altura, largura), dtype=np.uint8)
        pontos_inf = [318, 402, 317, 14, 87, 178, 88, 95]
        coordenadas_inf = [(int(face_landmarks[i].x * largura), int(face_landmarks[i].y * altura)) for i in pontos_inf]
        cv2.fillPoly(mascara_inf, [np.array(coordenadas_inf, np.int32)], 255)
        mascara_inf_dilatada = cv2.dilate(mascara_inf, np.ones((3, 3), np.uint8), iterations=1)

        # Recorta a região quadrada do rosto para o Replicate
        crop_sq_img = imagem_rgb[y1:y2, x1:x2]
        crop_sq_mask = mascara_sup_dilatada[y1:y2, x1:x2]

        img_512 = Image.fromarray(crop_sq_img).resize((512, 512), Image.Resampling.LANCZOS)
        mask_512 = Image.fromarray(crop_sq_mask).resize((512, 512), Image.Resampling.NEAREST)

        buffered_img_512 = io.BytesIO()
        img_512.save(buffered_img_512, format="JPEG", quality=90)
        image_uri = f"data:image/jpeg;base64,{base64.b64encode(buffered_img_512.getvalue()).decode('utf-8')}"

        buffered_mask_512 = io.BytesIO()
        mask_512.save(buffered_mask_512, format="PNG")
        mask_uri = f"data:image/png;base64,{base64.b64encode(buffered_mask_512.getvalue()).decode('utf-8')}"

        replicate_token = os.environ.get("REPLICATE_API_TOKEN")
        headers = {
            "Authorization": f"Bearer {replicate_token}",
            "Content-Type": "application/json"
        }

        payload = {
            "version": "4956c634b9aa976129f13166c713f8cf38bd337cd58c77925e8cd71d935d5696",
            "input": {
                "image": image_uri,
                "mask": mask_uri,
                "prompt": f"photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1>(Beautiful natural teeth, aligned bite teeth), aligned white teeth, human like teeth, healthy teeth with a perfect smile, shade {selected_color.upper()}, good proportion smile,",
                "negative_prompt": "(deformed teeth, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime), bad anatomy, rabbit teeth, wrong anatomy, missing teeth, disconnected teeth, unnatural mouth, low quality, jpeg artifacts",
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

        image_url = None
        for _ in range(90):
            time.sleep(2)
            poll_resp = requests.get(get_url, headers=headers, timeout=30)
            poll_data = poll_resp.json()
            if poll_data.get("status") == "succeeded":
                output = poll_data.get("output")
                image_url = output[0] if isinstance(output, list) else output
                break
            elif poll_data.get("status") == "failed":
                raise Exception(f"Processamento da IA falhou: {poll_data.get('error')}")

        if not image_url:
            raise Exception("Tempo limite excedido aguardando o Replicate.")

        with urllib.request.urlopen(image_url) as url_response:
            ai_image_bytes = url_response.read()

        ai_image_raw = Image.open(io.BytesIO(ai_image_bytes)).convert("RGB")
        ai_crop_restaurado = ai_image_raw.resize((S, S), Image.Resampling.LANCZOS)

        # Fusão suave da arcada superior corrigida pela IA
        crop_orig_pil = Image.fromarray(crop_sq_img)
        crop_mask_pil = Image.fromarray(crop_sq_mask)
        mask_soft = crop_mask_pil.filter(ImageFilter.GaussianBlur(radius=2))

        crop_final_pil = Image.composite(ai_crop_restaurado, crop_orig_pil, mask_soft)
        imagem_final_rgb = np.copy(imagem_rgb)
        imagem_final_rgb[y1:y2, x1:x2] = np.array(crop_final_pil)

        # Tratamento suave da Arcada Inferior (Clareamento mantendo a anatomia natural)
        hsv = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
        hsv[:, :, 2] = np.where(mascara_inf_dilatada > 0, np.clip(hsv[:, :, 2] * 1.15, 0, 255), hsv[:, :, 2])
        hsv[:, :, 1] = np.where(mascara_inf_dilatada > 128, np.clip(hsv[:, :, 1] * 0.85, 0, 255), hsv[:, :, 1])
        imagem_final_rgb = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)

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

        return jsonify({
            "success": True,
            "original_image": original_processed_b64,
            "processed_image": processed_b64,
            "creditos_restantes": novo_saldo
        }), 200

    except Exception as e:
        if 'cur' in locals() and cur: cur.close()
        if 'conn' in locals() and conn: conn.close()
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)