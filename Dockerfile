FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /app /app

RUN addgroup --system appgroup && adduser -G appgroup -S appuser

USER appuser

HEALTHCHECK CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "${PORT:-8000}"]