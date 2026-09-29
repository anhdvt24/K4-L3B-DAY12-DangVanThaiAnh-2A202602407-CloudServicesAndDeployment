# ═══════════════════════════════════════════════════════════════
# Stage 1: builder — cài dependency (có compiler nếu cần)
# ═══════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

# Force Railway/Docker cache to rebuild from this point on.
# Thay đổi giá trị này mỗi lần cần bust cache build.
ARG CACHEBUST=1

WORKDIR /install

# Một số thư viện (vd cryptography) cần gcc để biên dịch wheel
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ═══════════════════════════════════════════════════════════════
# Stage 2: runtime — chỉ copy kết quả từ builder, không có compiler
# ═══════════════════════════════════════════════════════════════
FROM python:3.11-slim

WORKDIR /app

# Tạo user thường (UID cố định để không trùng user hệ thống)
RUN useradd --create-home --uid 10001 appuser

# Copy dependency đã cài từ stage builder
COPY --from=builder /install /usr/local

# Copy source SAU khi cài dependency để tận dụng cache
ARG CACHEBUST=1
COPY app ./app
COPY utils ./utils
COPY requirements.txt .

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Cloud (Railway/Render/Cloud Run) tự gán $PORT; mặc định 8000 cho local
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
