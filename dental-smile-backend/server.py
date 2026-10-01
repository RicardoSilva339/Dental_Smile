from flask import Flask, request, send_file, jsonify
from PIL import Image, ImageEnhance, ImageFilter
import io

app = Flask(__name__)

# Tabela de clareamento baseada na Escala Vita
# Ajusta o brilho (Fator 1.0 = original)
VITA_WHITENING_MAP = {
    'BL1': 1.60, # Ultra branco
    'A1':  1.45, # Branco natural
    'A2':  1.30, # Levemente clareado
    'B1':  1.50, # Claro
}

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "online", "message": "Dental Smile Backend Ativo (Plano B)"}), 200

@app.route('/processar', methods=['POST'])
def processar():
    if 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo de imagem enviado"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Nome de arquivo inválido"}), 400

    # Recebe os parâmetros do Flutter
    color_code = request.form.get('color', 'A1')

    try:
        # 1. Carrega a imagem do paciente e otimiza memória
        img = Image.open(file).convert("RGB")
        max_dimension = 1080
        if max(img.size) > max_dimension:
            img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
        width, height = img.size

        # --- PROCESSAMENTO PLANO B (Clareamento + Suavização) ---

        # 2. Clareamento Global (Escala Vita)
        whitening_factor = VITA_WHITENING_MAP.get(color_code, 1.45)
        enhancer = ImageEnhance.Brightness(img)
        img_clarificada = enhancer.enhance(whitening_factor)

        # 3. Alinhamento Básico (Suavização de Textura)
        # Cria uma máscara para focar apenas na área da boca (aproximadamente)
        mask = Image.new('L', (width, height), 0)
        # Define uma região central inferior para suavizar (boca)
        # Y começa em 60% da altura e vai até 85%. X centralizado.
        boca_regiao = (int(width*0.25), int(height*0.60), int(width*0.75), int(height*0.85))
        mask_draw = Image.new('L', (width, height), 0)
        from PIL import ImageDraw
        draw = ImageDraw.Draw(mask_draw)
        # Desenha um retângulo branco e desfoca para bordas suaves
        draw.rectangle(boca_regiao, fill=255)
        mask_suave = mask_draw.filter(ImageFilter.GaussianBlur(radius=20))

        # 4. Aplica desfoque (Blur) para suavizar dentes tortos
        img_suavizada = img_clarificada.filter(ImageFilter.GaussianBlur(radius=3))

        # 5. Mescla as imagens: clareada onde é rosto, suavizada onde é boca
        final_img = Image.composite(img_suavizada, img_clarificada, mask_suave)

        # --- FIM DO PROCESSAMENTO ---

        # Prepara para envio
        img_io = io.BytesIO()
        final_img.save(img_io, 'JPEG', quality=85)
        img_io.seek(0)

        return send_file(img_io, mimetype='image/jpeg')

    except Exception as e:
        print(f"Erro no processamento: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)