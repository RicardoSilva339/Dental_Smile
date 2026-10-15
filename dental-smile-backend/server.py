import os
import io
import traceback
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from huggingface_hub import InferenceClient

app = Flask(__name__)
CORS(app)

# O token lido do Render
HF_TOKEN = os.getenv("HUGGINGFACE_API_KEY")

# Inicializa o cliente oficial da Hugging Face
client = InferenceClient(api_key=HF_TOKEN)

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
            "aligned white teeth, healthy teeth with a perfect smile, high quality"
        )

        # Usando um modelo totalmente mantido na camada serverless gratuita
        image = client.text_to_image(
            prompt=prompt_text,
            model="stabilityai/stable-diffusion-2-1"
        )

        img_byte_arr = io.BytesIO()
        image.save(img_byte_arr, format='JPEG')
        img_byte_arr.seek(0)

        return send_file(img_byte_arr, mimetype='image/jpeg')

    except Exception as e:
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)