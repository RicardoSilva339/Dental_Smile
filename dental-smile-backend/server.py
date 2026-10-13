import os
import io
import requests
import replicate
from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

# O Replicate usará automaticamente a variável REPLICATE_API_TOKEN configurada no Render

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        # Lê os bytes da imagem
        image_bytes = image_file.read()
        image_stream = io.BytesIO(image_bytes)

        # Executa o modelo no Replicate configurado para economizar créditos
        output = replicate.run(
            "sourav-sarkar-doc32/smile-correct:4956c634b9aa976129f13166c713f8cf38bd337cd58c77925e8cd71d935d5696",
            input={
                "image": image_stream,
                "prompt": f"photo of perfectsmile smile <lora:lora_perfectsmile_v1_from_v1_160:1>(Beautiful natural teeth, aligned bite teeth), shade {color_code}, aligned white teeth, human like teeth, (no teeth gap), celebrity-like teeth, healthy teeth with a perfect smile, not big incisor, good proportion teeth, good proportion smile",
                "num_outputs": 1,  # CRUCIAL: 1 gera apenas 1 imagem e economiza 4x mais saldo
                "negative_prompt": "(deformed teeth, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime), (deformed, distorted, abnormal teeth:1.3, disfigured:1.3, large teeth:2), poorly drawn, Fixer, bad anatomy, rabbit teeth, wrong anatomy, missing teeth, disconnected teeth, unnatural mouth, bunny teeth, big incisor teeth, disproportionate front teeth, bad smile, reflection, crooked teeth, distorted teeth, cropped, out of frame, worst quality, low quality, jpeg artifacts, ugly, morbid, disfigured, gross proportions, too many teeth, lipstick, lip gloss, too less teeth, unnatural size teeth, poorly drawn mouth, poorly drawn teeth"
            }
        )

        # O Replicate retorna uma lista de URLs de imagens ou um FileOutput
        # Caso retorne URL, fazemos o download direto dos bytes para entregar ao Flutter:
        if isinstance(output, list) and len(output) > 0:
            image_url = str(output[0])
            img_res = requests.get(image_url)
            return send_file(io.BytesIO(img_res.content), mimetype='image/jpeg')
        elif hasattr(output, 'read'):
            return send_file(io.BytesIO(output.read()), mimetype='image/jpeg')
        else:
            return jsonify({'error': 'Formato de resposta inesperado do Replicate'}), 500

    except Exception as e:
        print(f"Erro no processamento interno: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)