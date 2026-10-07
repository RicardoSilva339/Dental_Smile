from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import cv2
import numpy as np
import os
import io

app = Flask(__name__)
CORS(app)  # Libera o acesso para o aplicativo Flutter

# Rota para checagem de saúde
@app.route('/', methods=['GET'])
def health_check():
    return jsonify({"status": "API Dental Smile online"}), 200

# Aceita tanto a rota /process-smile quanto /api/process-smile
@app.route('/process-smile', methods=['POST'])
@app.route('/api/process-smile', methods=['POST'])
def process_smile():
    try:
        # Suporta tanto a chave 'file' quanto 'image'
        file = request.files.get('file') or request.files.get('image')

        if not file:
            return jsonify({'error': 'Nenhuma imagem foi recebida sob a chave "file" ou "image"'}), 400

        color = request.form.get('color', 'natural')
        shape = request.form.get('shape', 'oval')
        size = request.form.get('size', 'medio')

        # Converte a imagem enviada para OpenCV
        np_img = np.frombuffer(file.read(), np.uint8)
        img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({'error': 'Arquivo de imagem inválido'}), 400

        # --- LÓGICA DE PROCESSAMENTO / IA ---
        # Exemplo: Ajuste leve de brilho/contraste com base nas escolhas
        processed_img = cv2.convertScaleAbs(img, alpha=1.1, beta=15)

        # Converte o resultado processado para formato PNG em memória
        _, buffer = cv2.imencode('.png', processed_img)
        io_buf = io.BytesIO(buffer)

        # Retorna a imagem tratada diretamente em bytes
        return send_file(io_buf, mimetype='image/png')

    except Exception as e:
        print(f"Erro interno: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)