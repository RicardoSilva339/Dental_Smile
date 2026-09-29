from flask import Flask, request, send_file
from PIL import Image
import io

app = Flask(__name__)

@app.route('/processar', methods=['POST'])
def processar():
    # Verifica se o arquivo foi enviado
    if 'file' not in request.files:
        return "Nenhum arquivo enviado", 400
    
    file = request.files['file']
    if file.filename == '':
        return "Nome de arquivo inválido", 400

    # Abre a imagem com Pillow
    img = Image.open(file)

    # Exemplo de processamento: converter para preto e branco
    img = img.convert("L")

    # Salva em memória e devolve como resposta
    img_io = io.BytesIO()
    img.save(img_io, 'JPEG')
    img_io.seek(0)

    return send_file(img_io, mimetype='image/jpeg')

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
