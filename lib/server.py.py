from flask import Flask, request, send_file
import io

app = Flask(__name__)

@app.route("/processar", methods=["POST"])
def processar():
    if "file" not in request.files:
        return {"success": False, "message": "Nenhum arquivo enviado"}, 400

    file = request.files["file"]

    # Por enquanto devolve a mesma imagem sem alterações
    return send_file(
        io.BytesIO(file.read()),
        mimetype="image/png"
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
