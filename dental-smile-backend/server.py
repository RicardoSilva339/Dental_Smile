import io
import cv2
import numpy as np
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/process-smile', methods=['POST'])
@app.route('/api/process-smile', methods=['POST'])
def process_smile():
    try:
        file = request.files.get('file') or request.files.get('image')
        if not file:
            return jsonify({'error': 'Nenhuma imagem enviada'}), 400

        color = request.form.get('color', 'brilhante')

        np_img = np.frombuffer(file.read(), np.uint8)
        img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({'error': 'Imagem inválida'}), 400

        height, width = img.shape[:2]

        # 1. Converter para os espaços de cor LAB e HSV
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        l, a, b = cv2.split(lab)
        h, s, v = cv2.split(hsv)

        # 2. Definição da ROI em formato elíptico (focado estritamente na boca)
        roi_mask = np.zeros((height, width), dtype=np.uint8)
        center_x, center_y = int(width * 0.50), int(height * 0.60)
        axes_x, axes_y = int(width * 0.20), int(height * 0.10) # Reduzido para não pegar o queixo
        cv2.ellipse(roi_mask, (center_x, center_y), (axes_x, axes_y), 0, 0, 360, 255, -1)

        # 3. Filtro de Cor Anatômica dos Dentes:
        # - Luminosidade alta (v > 130)
        # - Baixa saturação (s < 100 -> exclui lábios vermelhos e pele rosada/morena)
        teeth_color_mask = cv2.inRange(hsv, (0, 0, 130), (180, 95, 255))

        # 4. Interseção da região bucal com os pixels característicos de dentes
        teeth_mask = cv2.bitwise_and(teeth_color_mask, roi_mask)

        # 5. Suavização progressiva para blend invisível com as gengivas e lábios
        teeth_mask_blur = cv2.GaussianBlur(teeth_mask, (31, 31), 0) / 255.0

        # 6. Intensidade do Clareamento
        boost_l = 35 if color == 'brilhante' else (25 if color == 'perolado' else 15)
        neutralize_b = 16 if color == 'brilhante' else 10

        # Aplica o clareamento no canal L e remove o tom amarelado no canal B
        l_new = np.clip(l + (teeth_mask_blur * boost_l), 0, 255).astype(np.uint8)
        b_new = np.clip(b - (teeth_mask_blur * neutralize_b), 0, 255).astype(np.uint8)

        lab_adjusted = cv2.merge([l_new, a, b_new])
        processed_img = cv2.cvtColor(lab_adjusted, cv2.COLOR_LAB2BGR)

        _, buffer = cv2.imencode('.png', processed_img)
        io_buf = io.BytesIO(buffer)

        return send_file(io_buf, mimetype='image/png')

    except Exception as e:
        print(f"Erro interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)