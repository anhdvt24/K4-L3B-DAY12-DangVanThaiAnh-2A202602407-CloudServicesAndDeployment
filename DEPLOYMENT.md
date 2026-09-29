# Thông Tin Deploy — Checkpoint 5

> Service đã deploy tại: https://day12-agent-9zd9.onrender.com
>
> Platform: Render Blueprint (đọc từ `render.yaml`)
>
> Ngày deploy: 29/09/2026
>
> **Chỉ ghi TÊN biến môi trường, không dán giá trị secret.**

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Đặng Văn Thái Anh |
| Mã học viên | 2A202602407 |
| Repo | https://github.com/anhdvt24/K4-L3B-DAY12-DangVanThaiAnh-2A202602407-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-9zd9.onrender.com |
| Platform | Render (Blueprint từ `render.yaml`) |
| Ngày deploy | 29/09/2026 |

## Biến Môi Trường Đã Set Trên Cloud

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Render tự gán, không ghi đè |
| `AGENT_API_KEY` | ✅ | nhập lúc tạo Blueprint (`sync: false`), giá trị không lưu repo |
| `REDIS_URL` | ✅ | tự lấy từ service `day12-redis` qua `fromService` trong render.yaml |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — kỳ vọng 200 {"status":"ok"}
curl -i https://day12-agent-9zd9.onrender.com/health

# 2. Readiness — kỳ vọng 200 {"status":"ready","redis":true}
curl -i https://day12-agent-9zd9.onrender.com/ready

# 3. Không có API key — kỳ vọng 401
curl -i -X POST https://day12-agent-9zd9.onrender.com/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'
```

## Kết Quả Chạy Thật

Lấy ngày 29/09/2026 bằng `httpx` (Python) — an toàn hơn curl với PowerShell:

```
===== /health =====
HTTP 200
application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}

===== /ready =====
HTTP 200
{"status":"ready","redis":true}

===== /ask (không có X-API-Key) =====
HTTP 401
{"detail":"invalid or missing API key"}
```

3/3 endpoint đúng theo rubric:

- `/health` 200 → liveness pass
- `/ready` 200 với `redis:true` → Redis add-on kết nối được
- `/ask` 401 khi thiếu key → middleware auth chạy đúng trước rate limit / cost guard

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — Render dashboard hiển thị 2 service (day12-agent + day12-redis) đều xanh, URL `day12-agent-9zd9.onrender.com` hiển thị rõ
- `screenshots/health.png` — terminal chạy `curl /health` trả về HTTP 200 + JSON
