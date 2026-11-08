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
from PIL import Image, ImageOps, ImageEnhance, ImageDraw, ImageFilter
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

# Inicializa o Face Landmarker do MediaPipe uma única vez ao iniciar o servidor
base_options = mp.tasks.BaseOptions(model_asset_path='face_landmarker.task')
options = mp.tasks.vision.FaceLandmarkerOptions(
    base_options=base_options,
    output_face_blendshapes=False,
    output_facial_transformation_matrixes=False,
    num_faces=1
)
detector = mp.tasks.vision.FaceLandmarker.create_from_options(options)

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
    selected_shape = data.get('shape', 'natural').lower()
    selected_size = data.get('size', 'medio').lower()

    if not image_b64:
        cur.close()
        conn.close()
        return jsonify({"success": False, "error": "Nenhuma imagem enviada."}), 400

    try:
        # Extrai os dados base64 (removendo prefixo data:image/... se presente)
        if "," in image_b64:
            image_b64 = image_b64.split(",")[1]

        image_data = base64.b64decode(image_b64)
        orig_image = Image.open(io.BytesIO(image_data))
        orig_image = ImageOps.exif_transpose(orig_image) or orig_image

        rgb_image = orig_image.convert("RGB")
        imagem_rgb = np.array(rgb_image)
        altura, largura, _ = imagem_rgb.shape

        print("=" * 60)
        print(f"📥 [PYTHON REST] Recebido | Dimensões: {largura}x{altura} | Cor: {selected_color.upper()}")
        print("=" * 60)

        buffered_orig = io.BytesIO()
        rgb_image.save(buffered_orig, format="JPEG", quality=90)
        original_processed_b64 = base64.b64encode(buffered_orig.getvalue()).decode('utf-8')

        # Detecção com MediaPipe
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=imagem_rgb)
        detection_result = detector.detect(mp_image)

        if not detection_result.face_landmarks:
            raise Exception("Nenhum rosto detectado na imagem.")

        face_landmarks = detection_result.face_landmarks[0]

        # 1. SMART SQUARE FACE CROP (Recorte Quadrado 1:1 do rosto)
        y_coords = [int(pt.y * altura) for pt in face_landmarks]
        center_y = sum(y_coords) // len(y_coords)
        S = min(largura, altura)
        y1 = max(0, center_y - (S // 2))
        y2 = min(altura, y1 + S)
        if y2 - S >= 0:
            y1 = y2 - S
        x1, x2 = 0, S

        # 2. Máscara exclusiva para a Arcada Superior (onde a IA atua)
        mascara_sup = np.zeros((altura, largura), dtype=np.uint8)
        pontos_arcada_superior = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308]
        coordenadas_sup = [(int(face_landmarks[i].x * largura), int(face_landmarks[i].y * altura)) for i in pontos_arcada_superior]
        cv2.fillPoly(mascara_sup, [np.array(coordenadas_sup, np.int32)], 255)

        kernel = np.ones((3, 3), np.uint8)
        mascara_sup_dilatada = cv2.dilate(mascara_sup, kernel, iterations=1)

        # 3. Máscara exclusiva para a Arcada Inferior (recebe apenas clareamento/tonalidade)
        mascara_inf = np.zeros((altura, largura), dtype=np.uint8)
        pontos_arcada_inferior = [318, 402, 317, 14, 87, 178, 88, 95]
        coordenadas_inf = [(int(face_landmarks[i].x * largura), int(face_landmarks[i].y * altura)) for i in pontos_arcada_inferior]
        cv2.fillPoly(mascara_inf, [np.array(coordenadas_inf, np.int32)], 255)
        mascara_inf_dilatada = cv2.dilate(mascara_inf, kernel, iterations=1)

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

        print("🚀 [REPLICATE REST] Disparando IA com máscara alinhada apenas na arcada superior...")

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
            raise Exception("Tempo limite excedido aguardando o Replicate processar a imagem.")

        print(f"📥 [REPLICATE] Imagem gerada com sucesso: {image_url}")

        with urllib.request.urlopen(image_url) as url_response:
            ai_image_bytes = url_response.read()

        ai_image_raw = Image.open(io.BytesIO(ai_image_bytes)).convert("RGB")
        ai_crop_restaurado = ai_image_512 = ai_image_raw.resize((S, S), Image.Resampling.LANCZOS)

        # Fusão suave na arcada superior (com IA)
        crop_orig_pil = Image.fromarray(crop_sq_img)
        crop_mask_pil = Image.fromarray(crop_sq_mask)
        mask_soft = crop_mask_pil.filter(ImageFilter.GaussianBlur(radius=2))

        crop_final_pil = Image.composite(ai_crop_restaurado, crop_orig_pil, mask_soft)
        crop_final_np = np.array(crop_final_pil)

        # Reconstrói a imagem com a arcada superior corrigida
        imagem_final_rgb = np.copy(imagem_rgb)
        imagem_final_rgb[y1:y2, x1:x2] = crop_final_np

        # 4. Tratamento suave da Arcada Inferior (Clareamento / Tonalidade sem alterar formato)
        # Converte para HSV para ajustar brilho/saturação dos dentes de baixo preservando a anatomia torta original
        hsv = cv2.cvtColor(imagem_final_rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
        hsv[:, :, 2] = np.where(mascara_inf_dilatada > 0, np.clip(hsv[:, :, 2] * 1.15, 0, 255), hsv[:, :, 2]) # Aumenta brilho
        hsv[:, :, 1] = np.where(mascara_inf_dilatada > 128, np.clip(hsv[:, :, 1] * 0.85, 0, 255), hsv[:, :, 1]) # Reduz amarelado (saturação)
        imagem_final_rgb = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)

        # Codifica o resultado final para base64
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
        print("📤 [PYTHON REST] Simulação de sorriso concluída com sucesso!")
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