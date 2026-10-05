from flask import Flask, request, send_file, jsonify
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
import io

app = Flask(__name__)

# Mapeamento dos parâmetros enviados pelo Flutter para o fator de clareamento
COLOR_MAP = {
    'natural': 1.25,   # Clareamento suave
    'brilhante': 1.55, # Clareamento intenso / branco radiante
    'perolado': 1.40   # Clareamento equilibrado
}

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "online", "message": "Dental Smile Backend Ativo"}), 200

# Rota exata esperada pela ApiService do Flutter
@app.route('/api/process-smile', methods=['POST'])
def process_smile():
    # 1. Validação do arquivo de imagem enviado pelo Flutter
    if 'photo' not in request.files and 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo de imagem enviado"}), 400

    file = request.files.get('photo') or request.files.get('file')
    if not file or file.filename == '':
        return jsonify({"error": "Arquivo inválido"}), 400

    # 2. Leitura dos parâmetros enviados pelo Flutter
    color_param = request.form.get('color', 'brilhante').lower()
    shape_param = request.form.get('shape', 'oval')
    size_param = request.form.get('size', 'medio')

    try:
        # Carrega a imagem
        img = Image.open(file).convert("RGB")
        max_dimension = 1080
        if max(img.size) > max_dimension:
            img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
        width, height = img.size

        # --- PROCESSAMENTO DOS DENTES ---

        # Define o fator de brilho/clareamento com base na cor selecionada
        whitening_factor = COLOR_MAP.get(color_param, 1.45)

        # Aplica o clareamento
        enhancer = ImageEnhance.Brightness(img)
        img_clareada = enhancer.enhance(whitening_factor)

        # Ajuste extra de contraste para realçar o sorriso
        contrast_enhancer = ImageEnhance.Contrast(img_clareada)
        img_clareada = contrast_enhancer.enhance(1.15)

        # Máscara da Região do Sorriso (Centralizada no terço inferior da boca)
        mask_draw = Image.new('L', (width, height), 0)
        draw = ImageDraw.Draw(mask_draw)

        # Região aproximada do sorriso
        boca_box = (int(width * 0.28), int(height * 0.52), int(width * 0.72), int(height * 0.78))
        draw.ellipse(boca_box, fill=255)

        # Sfumato/Suavização nas bordas da máscara para evitar cortes secos
        mask_suave = mask_draw.filter(ImageFilter.GaussianBlur(radius=25))

        # Mescla a imagem com os dentes clareados/transformados na imagem original
        final_img = Image.composite(img_clareada, img, mask_suave)

        # Prepara a imagem para ser devolvida em formato de Bytes para o Flutter
        img_io = io.BytesIO()
        final_img.save(img_io, 'JPEG', quality=90)
        img_io.seek(0)

        return send_file(img_io, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)