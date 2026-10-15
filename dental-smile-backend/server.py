import os
import io
import traceback
import requests
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from PIL import Image

app = Flask(__name__)
CORS(app)

# Token da Hugging Face configurado nas variáveis de ambiente do Render
HF_TOKEN = os.environ.get("HUGGINGFACE_API_TOKEN", "")
API_URL = "https://api-inference.huggingface.co/models/runwayml/stable-diffusion-v1-5"

# 💎 Base de dados simulada de créditos por Dentista (Chave de Acesso / API Key)
# 🎁 Agora com 3 créditos de degustação para o modelo Freemium!
CREDITOS_DB = {
    "dentista_demo_123": {
        "nome": "Dr. Ricardo",
        "creditos": 3  # Saldo inicial de degustação
    }
}

@app.route('/check-credits', methods=['GET'])
def check_credits():
    """Rota para o app Flutter verificar quantos créditos o dentista ainda tem."""
    api_key = request.args.get('api_key', 'dentista_demo_123')

    if api_key in CREDITOS_DB:
        user_data = CREDITOS_DB[api_key]
        return jsonify({
            'success': True,
            'nome': user_data['nome'],
            'creditos': user_data['creditos']
        }), 200

    return jsonify({'success': False, 'error': 'Chave de acesso inválida'}), 401

@app.route('/add-credits', methods=['POST'])
def add_credits():
    """Rota para recarregar créditos após a confirmação de pagamento."""
    data = request.json or {}
    api_key = data.get('api_key', 'dentista_demo_123')
    quantidade = data.get('quantidade', 0)

    if api_key in CREDITOS_DB:
        CREDITOS_DB[api_key]['creditos'] += int(quantidade)
        print(f"Créditos adicionados para {api_key}. Novo saldo: {CREDITOS_DB[api_key]['creditos']}")
        return jsonify({
            'success': True,
            'novo_saldo': CREDITOS_DB[api_key]['creditos']
        }), 200

    return jsonify({'success': False, 'error': 'Chave de acesso inválida'}), 401

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        # Pega a chave de acesso enviada pelo app (ou usa uma padrão de demonstração)
        api_key = request.form.get('api_key', 'dentista_demo_123')

        # Validação de Créditos antes de processar
        if api_key not in CREDITOS_DB:
            return jsonify({'error': 'Autenticação necessária. Chave inválida.'}), 401

        if CREDITOS_DB[api_key]['creditos'] <= 0:
            return jsonify({
                'error': 'Créditos esgotados! Por favor, recarregue o seu plano para continuar a simular.'
            }), 402 # HTTP 402 Payment Required

        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]

        color = request.form.get('color', 'Brilhante')
        shape = request.form.get('shape', 'Oval')
        size = request.form.get('size', 'Médio')

        # Lê a imagem enviada pelo Flutter
        input_image = Image.open(image_file.stream).convert("RGB")
        input_image.thumbnail((512, 512))

        img_byte_arr = io.BytesIO()
        input_image.save(img_byte_arr, format='JPEG')
        img_bytes = img_byte_arr.getvalue()

        headers = {
            "Authorization": f"Bearer {HF_TOKEN}",
        }

        prompt_text = f"Close up photo of person smiling, professional dentistry aesthetic, teeth shade {color}, shape {shape}, highly detailed, realistic."

        files = {
            'image': img_bytes
        }
        data = {
            'inputs': prompt_text
        }

        # Faz a requisição para a Hugging Face Inference API
        response = requests.post(API_URL, headers=headers, files=files, data=data, timeout=60)

        if response.status_code != 200:
            print(f"Erro na Hugging Face: {response.status_code} - {response.text}")
            return send_file(io.BytesIO(img_bytes), mimetype='image/jpeg')

        # Sucesso no processamento: Desconta 1 crédito do saldo do dentista!
        CREDITOS_DB[api_key]['creditos'] -= 1
        print(f"Crédito descontado para {api_key}. Restantes: {CREDITOS_DB[api_key]['creditos']}")

        return send_file(io.BytesIO(response.content), mimetype='image/jpeg')

    except Exception as e:
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)