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

# Converte para LAB para isolar Luminância (L) de Cor (A, B)
lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
l, a, b = cv2.split(lab)

# Intensidade do clareamento de acordo com a opção
boost = 45 if color == 'brilhante' else (30 if color == 'perolado' else 20)

# Isola regiões de alta luminância (dentes) e reduz o tom amarelado no canal B
height, width = l.shape
mouth_region = np.zeros_like(l)
mouth_region[int(height * 0.45):int(height * 0.85), :] = 255  # Foco na área da boca

# Máscara para pixels claros dentro da região focal
teeth_mask = cv2.bitwise_and(cv2.threshold(l, 140, 255, cv2.THRESH_BINARY)[1], mouth_region)
teeth_mask = cv2.GaussianBlur(teeth_mask, (11, 11), 0) / 255.0

# Aumenta brilho (L) e neutraliza o amarelo (B)
l_new = np.clip(l + (teeth_mask * boost), 0, 255).astype(np.uint8)
b_new = np.clip(b - (teeth_mask * 15), 0, 255).astype(np.uint8)

lab_adjusted = cv2.merge([l_new, a, b_new])
processed_img = cv2.cvtColor(lab_adjusted, cv2.COLOR_LAB2BGR)

_, buffer = cv2.imencode('.png', processed_img)
io_buf = io.BytesIO(buffer)

return send_file(io_buf, mimetype='image/png')

except Exception as e:
print(f"Erro interno: {str(e)}")
return jsonify({'error': str(e)}), 500