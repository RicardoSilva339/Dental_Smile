from flask import Flask, request, send_file, jsonify
from PIL import Image, ImageEnhance, ImageOps
import io

app = Flask(__name__)

# Tabela de tonalidades RGB baseadas na Escala Vita
VITA_COLOR_MAP = {
    'BL1': (250, 248, 240), # Ultra branco / Lente de contato
    'A1':  (242, 236, 218), # Branco natural
    'A2':  (235, 224, 198), # Amarelado claro
    'B1':  (245, 240, 220), # Claro amarelado/cinza
}

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "online", "message": "Dental Smile Backend Ativo"}), 200

@app.route('/processar', methods=['POST'])
def processar():
    if 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo de imagem enviado"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Nome de arquivo inválido"}), 400

    # Recebe os parâmetros do Flutter
    color_code = request.form.get('color', 'A1')
    shape = request.form.get('shape', 'Natural')
    size = request.form.get('size', 'Médio')

    # Verifica se o Flutter enviou o arquivo do molde PNG de dentes
    overlay_file = request.files.get('overlay')

    try:
        # Carrega a imagem do paciente
        base_img = Image.open(file).convert("RGBA")

        # Otimização de memória para o Render (máx 800px)
        max_dimension = 800
        if max(base_img.size) > max_dimension:
            base_img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

        # Se o Flutter enviou o molde PNG (ex: dentes_arredondados.png ou dentes_quadrados.png)
        if overlay_file:
            overlay_img = Image.open(overlay_file).convert("RGBA")

            # Redimensiona o molde para se adequar à foto do paciente
            overlay_img = overlay_img.resize(base_img.size, Image.Resampling.LANCZOS)

            # Aplica o tom de cor escolhido no molde de dentes
            target_rgb = VITA_COLOR_MAP.get(color_code, (242, 236, 218))

            # Separa os canais Alpha (transparência)
            r, g, b, alpha = overlay_img.split()

            # Colorização do molde
            colored_overlay = Image.new("RGBA", base_img.size, target_rgb + (0,))
            colored_overlay.putalpha(alpha)

            # Realiza a fusão (sobreposição) do molde com a imagem original
            base_img = Image.alpha_composite(base_img, colored_overlay)
        else:
            # Caso não envie molde, aplica o clareamento global simples
            rgb_img = base_img.convert("RGB")
            factor = 1.35 if color_code in ['BL1', 'A1'] else 1.20
            enhancer = ImageEnhance.Brightness(rgb_img)
            base_img = enhancer.enhance(factor).convert("RGBA")

        # Converte de volta para RGB e prepara para envio
        final_img = base_img.convert("RGB")
        img_io = io.BytesIO()
        final_img.save(img_io, 'JPEG', quality=85)
        img_io.seek(0)

        return send_file(img_io, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)