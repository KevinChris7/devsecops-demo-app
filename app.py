from flask import Flask

app = Flask(__name__)
csrf = CSRFProtect()
csrf.init_app(app)

@app.route("/")
def home():
    return "Vyomanant Academy DevSecOps Demo App\n"

@app.route("/health")
def health():
    return "OK\n"

if __name__ == "__main__":
    app.run(host='127.0.0.1', port=5000, debug=True)
