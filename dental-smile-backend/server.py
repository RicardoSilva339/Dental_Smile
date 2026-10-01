from flask import Flask, request, send_file, jsonify
from PIL import Image
import io

app = Flask(__name__)

# Rota raiz necessária para o Render e testes
@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "online", "message": "Dental Smile Backend Ativo"}), 200

@app.route('/processar', methods=['POST'])
def processar():
    if 'file' not in request.files:
        return "Nenhum arquivo enviado", 400

    file = request.files['file']
    if file.filename == '':
        return "Nome de arquivo inválido", 400

    img = Image.open(file)

    # Redimensiona para economizar memória RAM (máx 800px)
    max_dimension = 800
    if max(img.size) > max_dimension:
        img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

    # Processamento da imagem
    img = img.convert("L")

    img_io = io.BytesIO()
    img.save(img_io, 'JPEG', quality=85)
    img_io.seek(0)

    return send_file(img_io, mimetype='image/jpeg')

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)