# Verixa API container (Render, or any Docker host).
# Fits in 512 MB: spaCy small model + MiniLM via ONNX (no PyTorch).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VERIXA_MODEL_DIR=/opt/models

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

# Bake the matching model into the image so the first request is fast.
RUN python -c "from fastembed import TextEmbedding; \
TextEmbedding('sentence-transformers/all-MiniLM-L6-v2', cache_dir='/opt/models')" \
    && chmod -R a+rX /opt/models

COPY app ./app

RUN useradd -m -u 1000 user
USER user

# Render sets $PORT; default 8000 elsewhere.
EXPOSE 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
