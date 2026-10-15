import os
import io
import requests
from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

# A Hugging Face usará o token configurado no Render (HUGGINGFACE_API_KEY)
HF_TOKEN = os.getenv("HUGGINGFACE_API_KEY")

# Substitua pelo ID do modelo que deseja usar na Hugging Face (ex: um modelo de Stable Diffusion ou fine-tune)
HF_MODEL_ID = "stabilityai/stable-diffusion-2-1" # Exemplo de modelo, troque pelo seu se tiver um treinado
HF_API_URL = f"https://api-inference.huggingface.co/models/{HF_MODEL_ID}"

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        # Lê os bytes da imagem enviada pelo app
        image_bytes = image_file.read()

        # Prepara os cabeçalhos com o token da Hugging Face
        headers = {
            "Authorization": f"Bearer {HF_TOKEN}"
        }

        # Opcional: Prompt para guiar a IA, caso o modelo aceite parâmetros adicionais no payload ou option
        prompt_text = (
            f"photo of perfectsmile smile, shade {color_code}, "
            "aligned white teeth, healthy teeth with a perfect smile"
        )

        # Algumas APIs da Hugging Face aceitam a imagem diretamente no body ou em formato JSON
        # Para modelos de image-to-image/inpainting na Inference API padrão, enviamos os bytes diretamente:
        response = requests.post(HF_API_URL, headers=headers, data=image_bytes)

        if response.status_code != 200:
            return jsonify({
                'error': f'Erro na API da Hugging Face (Status {response.status_code}): {response.text}'
            }), response.status_code

        # Se a API retornar a imagem gerada em bytes diretamente
        processed_image_bytes = response.content
        return send_file(io.BytesIO(processed_image_bytes), mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento interno: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)