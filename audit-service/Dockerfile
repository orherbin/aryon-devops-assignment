FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim

# Install curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local

COPY --chown=appuser:appuser . .

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH

EXPOSE 8081

# Health check - verify the service is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8081", "--workers", "2", "--threads", "4", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
