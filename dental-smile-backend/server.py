import os
import io
import traceback
import requests
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from PIL import Image

app = Flask(__name__)
CORS(app)

# Defina o seu token da Hugging Face nas variáveis de ambiente do Render (HUGGINGFACE_API_TOKEN)
HF_TOKEN = os.environ.get("HUGGINGFACE_API_TOKEN", "")

# Exemplo de modelo de Img2Img estável na Hugging Face (pode ajustar conforme o modelo desejado)
API_URL = "https://api-inference.huggingface.co/models/runwayml/stable-diffusion-v1-5"

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]

        color = request.form.get('color', 'Brilhante')
        shape = request.form.get('shape', 'Oval')
        size = request.form.get('size', 'Médio')

        # Lê a imagem enviada pelo Flutter
        input_image = Image.open(image_file.stream).convert("RGB")

        # Redimensiona para otimizar o envio à API (opcional, mas recomendado para evitar timeouts)
        input_image.thumbnail((512, 512))

        img_byte_arr = io.BytesIO()
        input_image.save(img_byte_arr, format='JPEG')
        img_bytes = img_byte_arr.getvalue()

        headers = {
            "Authorization": f"Bearer {HF_TOKEN}",
        }

        # Prompt estruturado para guiar a IA na modificação mantendo a estrutura
        prompt_text = f"Close up photo of person smiling, professional dentistry aesthetic, teeth shade {color}, shape {shape}, highly detailed, realistic."

        # Payload para modelos compatíveis ou tarefas de imagem
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
            # Fallback temporário para não quebrar a app caso a API esteja a carregar o modelo (503)
            # Retorna a imagem original tratada ou o erro limpo
            return send_file(io.BytesIO(img_bytes), mimetype='image/jpeg')

        return send_file(io.BytesIO(response.content), mimetype='image/jpeg')

    except Exception as e:
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)