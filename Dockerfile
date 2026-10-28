FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y pip setuptools wheel

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY app.py .
RUN chmod 444 app.py

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
