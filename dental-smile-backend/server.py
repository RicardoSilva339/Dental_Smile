from flask import Flask, request, send_file, jsonify
from PIL import Image, ImageEnhance
import io

app = Flask(__name__)

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "online", "message": "Dental Smile Backend Ativo"}), 200

@app.route('/processar', methods=['POST'])
def processar():
    if 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo enviado"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Nome de arquivo inválido"}), 400

    # Recebe os parâmetros enviados pelo Flutter
    color = request.form.get('color', 'A1')
    shape = request.form.get('shape', 'default')
    size = request.form.get('size', 'default')

    try:
        # Garante que a imagem está em RGB (colorida)
        img = Image.open(file).convert("RGB")

        # Otimização de memória para o Render (máximo 800px)
        max_dimension = 800
        if max(img.size) > max_dimension:
            img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

        # Ajuste de clareamento/brilho baseado na cor escolhida
        # Cores mais claras (BL1, A1) recebem um ganho de brilho maior
        factor = 1.35 if color in ['BL1', 'A1'] else 1.20
        enhancer = ImageEnhance.Brightness(img)
        img = enhancer.enhance(factor)

        img_io = io.BytesIO()
        img.save(img_io, 'JPEG', quality=85)
        img_io.seek(0)

        return send_file(img_io, mimetype='image/jpeg')
    except Exception as e:
        print(f"Erro no processamento: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)