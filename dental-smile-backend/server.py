import os
import io
import traceback
import urllib.parse
import requests
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        # Prompt otimizado para a geração do sorriso
        prompt_text = (
            f"photo of perfect smile, shade {color_code}, "
            "aligned white teeth, healthy teeth with a perfect smile, high quality, realistic dentistry photo"
        )

        # Codifica o prompt para ser usado com segurança na URL
        encoded_prompt = urllib.parse.quote(prompt_text)

        # URL do serviço gratuito Pollinations (sem necessidade de token ou pagamento)
        pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&seed=42&nologo=true"

        # Faz o pedido da imagem gerada
        response = requests.get(pollinations_url, timeout=60)

        if response.status_code != 200:
            print(f"Erro na geração de imagem: {response.status_code}")
            return jsonify({'error': 'Erro ao gerar imagem no serviço externo'}), response.status_code

        return send_file(io.BytesIO(response.content), mimetype='image/jpeg')

    except Exception as e:
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)