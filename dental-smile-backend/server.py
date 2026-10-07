import io
import cv2
import numpy as np
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/', methods=['GET'])
def home():
    return jsonify({'status': 'online', 'message': 'Dental Smile API em execução'})

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

        # Converte para espaço de cor HSV para manipular tonalidades e saturação
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        h, s, v = cv2.split(hsv)

        # Seleciona a faixa de tons amarelados/claros (correspondente aos dentes)
        lower_yellow = np.array([10, 25, 100])
        upper_yellow = np.array([40, 255, 255])
        mask = cv2.inRange(hsv, lower_yellow, upper_yellow)

        # Suaviza a máscara para garantir transições naturais nas bordas dos dentes
        mask_blur = cv2.GaussianBlur(mask, (15, 15), 0) / 255.0

        # Intensidade do clareamento de acordo com a opção selecionada
        if color == 'brilhante':
            brightness_boost = 60
            saturation_reduce = 0.3
        elif color == 'perolado':
            brightness_boost = 40
            saturation_reduce = 0.5
        else:  # natural
            brightness_boost = 25
            saturation_reduce = 0.6

        # Reduz a amarelização (Saturação) e aumenta a luminosidade (Valor/Brilho)
        s_adjusted = np.clip(s * (1 - mask_blur * saturation_reduce), 0, 255).astype(np.uint8)
        v_adjusted = np.clip(v + (mask_blur * brightness_boost), 0, 255).astype(np.uint8)

        # Recombina os canais HSV e reconverte para BGR
        hsv_processed = cv2.merge([h, s_adjusted, v_adjusted])
        processed_img = cv2.cvtColor(hsv_processed, cv2.COLOR_HSV2BGR)

        # Converte o resultado processado para PNG na memória
        _, buffer = cv2.imencode('.png', processed_img)
        io_buf = io.BytesIO(buffer)

        return send_file(io_buf, mimetype='image/png')

    except Exception as e:
        print(f"Erro interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)