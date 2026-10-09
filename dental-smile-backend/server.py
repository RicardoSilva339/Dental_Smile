from flask import Flask, request, jsonify, send_file
import replicate
import io

app = Flask(__name__)

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        # 1. Verificar se o ficheiro foi enviado na requisição multipart
        if 'file' not in request.files:
            return jsonify({'error': 'Nenhum ficheiro/foto enviado'}), 400

        file = request.files['file']
        color = request.form.get('color', 'BL1')  # Pega o parâmetro 'color' do Flutter

        # 2. Enviar para a API do Replicate usando o novo token (REPLICATE_API_TOKEN)
        # Substitua 'seu-usuario/seu-modelo:versao' pelo modelo real utilizado no Replicate
        output = replicate.run(
            "seu-usuario/seu-modelo:versao",
            input={
                "image": file,
                "color": color
            }
        )

        # 3. Retornar o resultado para o aplicativo Flutter
        # Caso o Replicate retorne um stream/URL da imagem processada
        return send_file(output, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento: {e}")
        return jsonify({'error': str(e)}), 500