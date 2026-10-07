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

        # Converte para YCrCb (para isolar cor) e LAB (para ajustar brilho)
        ycrcb = cv2.cvtColor(img, cv2.COLOR_BGR2YCrCb)
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)

        _, cr, _ = cv2.split(ycrcb)
        l, a, b = cv2.split(lab)

        # Intensidade do clareamento
        boost = 40 if color == 'brilhante' else (28 if color == 'perolado' else 18)

        height, width = l.shape

        # 1. Restringe a busca apenas para a área central inferior (evita testa, olhos e bochechas externas)
        roi_mask = np.zeros_like(l)
        roi_mask[int(height * 0.50):int(height * 0.82), int(width * 0.25):int(width * 0.75)] = 255

        # 2. Localiza pixels de alta luminosidade (dentes)
        bright_pixels = cv2.threshold(l, 155, 255, cv2.THRESH_BINARY)[1]

        # 3. Interseção: Apenas pixels realmente claros dentro da região da boca
        teeth_mask = cv2.bitwise_and(bright_pixels, roi_mask)

        # 4. Suavização para transição natural
        teeth_mask_blur = cv2.GaussianBlur(teeth_mask, (15, 15), 0) / 255.0

        # 5. Aumenta brilho (L) e neutraliza o tom amarelo (B)
        l_new = np.clip(l + (teeth_mask_blur * boost), 0, 255).astype(np.uint8)
        b_new = np.clip(b - (teeth_mask_blur * 14), 0, 255).astype(np.uint8)

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