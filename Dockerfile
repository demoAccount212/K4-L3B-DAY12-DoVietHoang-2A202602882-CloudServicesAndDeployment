FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

FROM python:3.11-slim

WORKDIR /app

# Copy installed packages and app from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /app /app

RUN groupadd -r appgroup && useradd -r -g appgroup -M appuser

USER appuser

HEALTHCHECK CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

EXPOSE 8000

CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}