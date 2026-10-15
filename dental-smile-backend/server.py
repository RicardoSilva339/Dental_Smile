import os
import io
import traceback
import requests
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# O token lido do Render
HF_TOKEN = os.getenv("HUGGINGFACE_API_KEY")
# Novo endpoint atualizado do router da Hugging Face
API_URL = "https://router.huggingface.co/hf-inference/models/runwayml/stable-diffusion-v1-5"

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        prompt_text = (
            f"photo of perfectsmile smile, shade {color_code}, "
            "aligned white teeth, healthy teeth with a perfect smile"
        )

        headers = {
            "Authorization": f"Bearer {HF_TOKEN}"
        }

        payload = {
            "inputs": prompt_text
        }

        response = requests.post(API_URL, headers=headers, json=payload)

        if response.status_code != 200:
            print(f"Erro da Hugging Face: {response.text}")
            return jsonify({'error': f"Erro na API externa: {response.text}"}), response.status_code

        return send_file(io.BytesIO(response.content), mimetype='image/jpeg')

    except Exception as e:
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)