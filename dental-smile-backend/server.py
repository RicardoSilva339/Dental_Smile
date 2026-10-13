import os
import requests
import io
from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

# Token da Hugging Face vindo das variáveis de ambiente configuradas no Render
HF_TOKEN = os.environ.get("HUGGINGFACE_API_TOKEN")

# Endpoint do modelo no Hugging Face (utilizando o CodeFormer como base gratuita de restauração/sorriso)
API_URL = "https://api-inference.huggingface.co/models/sczhou/codeformer"

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        # Lê os bytes do arquivo enviado pelo Flutter
        image_bytes = image_file.read()

        # Configura os cabeçalhos de autenticação da Hugging Face
        headers = {"Authorization": f"Bearer {HF_TOKEN}"}

        # Faz a requisição POST diretamente para a API gratuita da Hugging Face
        response = requests.post(API_URL, headers=headers, data=image_bytes)

        if response.status_code != 200:
            print(f"Erro na API Hugging Face: {response.text}")
            return jsonify({'error': 'Erro ao processar imagem no modelo', 'details': response.text}), 500

        # Converte os bytes de resposta da imagem para um stream compatível com o send_file
        output_stream = io.BytesIO(response.content)

        # Retorna a imagem processada gerada pela IA para o Flutter
        return send_file(output_stream, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento interno: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)