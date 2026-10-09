from flask import Flask, request, jsonify, send_file
import replicate
import io

app = Flask(__name__)

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado'}), 400

        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]
        color_code = request.form.get('color', 'A1')

        # Lê os bytes do arquivo para passá-lo corretamente ao Replicate
        image_bytes = image_file.read()
        image_stream = io.BytesIO(image_bytes)

        # Executa o modelo exato no Replicate
        output = replicate.run(
            "sourav-sarkar-doc32/smile-correct:4956c634",  # Modelo atualizado
            input={
                "image": image_stream,
                "color": color_code
            }
        )

        # Retorna o resultado gerado pela IA para o Flutter
        return send_file(output, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento interno: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)