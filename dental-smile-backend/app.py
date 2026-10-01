from flask import Flask, request, send_file, jsonify
from PIL import Image
import io

app = Flask(__name__)

# 1. Rota raiz para o Render/Navegador testar se o servidor está online
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

    # Abre a imagem com Pillow
    img = Image.open(file)

    # 🛑 OTIMIZAÇÃO DE MEMÓRIA (Reduz dimensão para não estourar a RAM do Render)
    max_dimension = 800
    if max(img.size) > max_dimension:
        img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

    # Exemplo de processamento: converter para preto e branco
    img = img.convert("L")

    # Salva em memória e devolve como resposta
    img_io = io.BytesIO()
    img.save(img_io, 'JPEG', quality=85)
    img_io.seek(0)

    return send_file(img_io, mimetype='image/jpeg')

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)