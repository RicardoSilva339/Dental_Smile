from flask import Flask, request, send_file, jsonify
import io
import cv2
import numpy as np
from PIL import Image, ImageEnhance

app = Flask(__name__)

def processar_simulacao_dentes(image_bytes, color, shape, size):
    """
    Aplica modificações visuais na imagem de acordo com as opções escolhidas.
    """
    # Converter bytes em imagem OpenCV / Numpy
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        return None

    # Converte BGR (OpenCV) para RGB
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)

    # 1. Ajuste de Cor (Clareamento / Tom dos dentes)
    # Seleciona o brilho e contraste de acordo com o tom desejado
    brilho_factor = 1.1
    if color == "A1" or color == "BL1": # Mais claros
        brilho_factor = 1.25
    elif color == "A2":
        brilho_factor = 1.15
    elif color == "A3":
        brilho_factor = 1.05

    enhancer_brightness = ImageEnhance.Brightness(pil_img)
    pil_img = enhancer_brightness.enhance(brilho_factor)

    enhancer_contrast = ImageEnhance.Contrast(pil_img)
    pil_img = enhancer_contrast.enhance(1.1)

    # Convertendo de volta para OpenCV BGR
    img_processed = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)

    # 2. Salva a imagem processada em memória
    _, buffer = cv2.imencode('.png', img_processed)
    return io.BytesIO(buffer)


@app.route("/processar", methods=["POST"])
def processar():
    if "file" not in request.files:
        return jsonify({"success": False, "message": "Nenhum arquivo enviado"}), 400

    file = request.files["file"]

    # Recebe os parâmetros de simulação enviados pelo app
    color = request.form.get("color", "A1")
    shape = request.form.get("shape", "Natural")
    size = request.form.get("size", "Médio")

    image_bytes = file.read()

    # Processa a imagem aplicando a simulação
    output_stream = processar_simulacao_dentes(image_bytes, color, shape, size)

    if output_stream is None:
        return jsonify({"success": False, "message": "Erro ao processar a imagem"}), 500

    return send_file(
        output_stream,
        mimetype="image/png"
    )


if __name__ == "__main__":
    print("🚀 Servidor de Simulação Odontológica rodando na porta 5000...")
    app.run(host="0.0.0.0", port=5000, debug=True)