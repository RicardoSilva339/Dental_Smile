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
client = InferenceClient(token=HF_TOKEN)

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

        # Alterado para um modelo público e aberto para evitar restrições de termos
        model_id = "runwayml/stable-diffusion-v1-5"

        # Chamada segura usando o cliente oficial
        image_output = client.text_to_image(
            prompt=prompt_text,
            model=model_id,
        )

        img_io = io.BytesIO()
        image_output.save(img_io, 'JPEG')
        img_io.seek(0)

        return send_file(img_io, mimetype='image/jpeg')

    except Exception as e:
        # Imprime o erro técnico completo no console do Render
        traceback.print_exc()
        print(f"Erro no processamento interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)