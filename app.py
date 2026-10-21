from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Vyomanant Academy DevSecOps Demo App\n"

@app.route("/health")
def health():
    return "OK\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
