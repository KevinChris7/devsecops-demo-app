import os
import secrets
from flask import Flask
from flask_wtf.csrf import CSRFProtect

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY') or secrets.token_hex(32)
csrf = CSRFProtect()
csrf.init_app(app)

@app.route("/")
def home():
    return "Vyomanant Academy DevSecOps Demo App\n"

@app.route("/health")
def health():
    return "OK\n"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
