import io
import os
import cv2
import numpy as np
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


@app.route('/', methods=['GET'])
def health_check():
  return jsonify({'status': 'API Dental Smile online'}), 200


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

    # Converte para espaço de cor YCrCb e LAB
    ycrcb = cv2.cvtColor(img, cv2.COLOR_BGR2YCrCb)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)

    y, cr, cb = cv2.split(ycrcb)
    l, a, b = cv2.split(lab)

    # Intensidade de clareamento conforme o parâmetro
    boost = 40 if color == 'brilhante' else (28 if color == 'perolado' else 18)

    # 1. Região vertical provável do sorriso (foco no terço médio/inferior)
    height, width = l.shape
    region_mask = np.zeros_like(l)
    region_mask[
        int(height * 0.45) : int(height * 0.80),
        int(width * 0.20) : int(width * 0.80),
    ] = 255

    # 2. Dentes são áreas claras (L alto) dentro da região focal
    bright_pixels = cv2.threshold(l, 150, 255, cv2.THRESH_BINARY)[1]

    # Combina apenas os pixels claros que estão na região focal da boca
    teeth_mask = cv2.bitwise_and(bright_pixels, bright_pixels, mask=region_mask)

    # Suavização para evitar bordas duras
    teeth_mask_blur = cv2.GaussianBlur(teeth_mask, (15, 15), 0) / 255.0

    # 3. Aplica aumento de luminância (L) e neutralização do tom amarelado (B)
    l_new = np.clip(l + (teeth_mask_blur * boost), 0, 255).astype(np.uint8)
    b_new = np.clip(b - (teeth_mask_blur * 12), 0, 255).astype(np.uint8)

    lab_adjusted = cv2.merge([l_new, a, b_new])
    processed_img = cv2.cvtColor(lab_adjusted, cv2.COLOR_LAB2BGR)

    _, buffer = cv2.imencode('.png', processed_img)
    io_buf = io.BytesIO(buffer)

    return send_file(io_buf, mimetype='image/png')

  except Exception as e:
    print(f'Erro interno: {str(e)}')
    return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
  port = int(os.environ.get('PORT', 5000))
  app.run(host='0.0.0.0', port=port)