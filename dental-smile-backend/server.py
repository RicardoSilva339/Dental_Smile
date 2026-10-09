import os
import base64
from flask import Flask, request, jsonify
from flask_cors import CORS
import replicate

app = Flask(__name__)
CORS(app)

# Configura o token da API do Replicate
os.environ["REPLICATE_API_TOKEN"] = "r8_bUmvwILZ7nzN3Unq9Ddul44eCNcYPUi1KwScC"

@app.route('/process-image', methods=['POST'])
def process_image():
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({'error': 'Nenhuma imagem enviada'}), 400

        image_data = data['image']
        color = data.get('color', 'brilhante')
        shape = data.get('shape', 'quadrado')
        size = data.get('size', 'medio')

        if ',' in image_data:
            image_data = image_data.split(',')[1]

        image_bytes = base64.b64decode(image_data)
        input_image_path = "/tmp/input_patient.png"
        with open(input_image_path, "wb") as f:
            f.write(image_bytes)

        # Prompt de IA focado em estética dental
        prompt = (
            f"Professional dental aesthetic simulation, realistic smile, "
            f"perfectly aligned teeth, teeth color {color} white, teeth shape {shape}, "
            f"teeth size {size}, high quality dental porcelain veneers, "
            f"keep original face, skin, lips, and glasses unchanged."
        )

        output = replicate.run(
            "stability-ai/stable-diffusion-inpainting:c28b782980f7f32997e3b1c6d1d4dbed8690349887758ed0064f9f257521e102",
            input={
                "image": open(input_image_path, "rb"),
                "prompt": prompt,
                "negative_prompt": "crooked teeth, yellow teeth, blurry, distorted face, bad anatomy, extra teeth",
                "num_inference_steps": 30,
                "guidance_scale": 7.5
            }
        )

        result_url = output[0] if isinstance(output, list) else str(output)

        return jsonify({
            'success': True,
            'result_url': result_url
        })

    except Exception as e:
        print(f"Erro no processamento: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)