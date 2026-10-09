from flask import Flask, request, jsonify, send_file
import replicate
import io

app = Flask(__name__)

@app.route('/process-smile', methods=['POST'])
def process_smile():
    try:
        # Verifica se existe algum ficheiro na requisição multipart, independentemente do nome do campo
        if not request.files:
            return jsonify({'error': 'Nenhum ficheiro enviado nos arquivos da requisição'}), 400

        # Pega automaticamente o primeiro ficheiro enviado (evita erro de nome de campo)
        image_key = list(request.files.keys())[0]
        image_file = request.files[image_key]

        # Pega o parâmetro de cor enviado pelo app (padrão 'A1' se vier vazio)
        color_code = request.form.get('color', 'A1')

        # Executa o modelo no Replicate
        output = replicate.run(
            "seu-usuario/seu-modelo:versao",  # Substitua pelo ID/versão real do seu modelo no Replicate
            input={
                "image": image_file,
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