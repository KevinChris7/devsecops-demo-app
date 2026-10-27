FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY --chown=appuser:appgroup app.py .

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
