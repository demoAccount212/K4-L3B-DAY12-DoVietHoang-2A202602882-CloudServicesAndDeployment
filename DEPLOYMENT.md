# Thông Tin Deploy — Checkpoint 5

> File này đã hoàn thiện sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Đỗ Việt Hoàng |
| Mã học viên | 2A202602882 |
| Repo | https://github.com/demoAccount212/K4-L3B-DAY12-DoVietHoang-2A202602882-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://k4-l3b-day12-doviethoang-2a202602882-cloudservic-production.up.railway.app |
| Platform | Railway — build tự động từ GitHub (Deploy from GitHub repo), cấu hình trong `railway.toml` |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán, app đọc lúc chạy (không set tay) |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Railway Redis plugin — tham chiếu runtime `${{Redis.REDIS_URL}}` |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-29, output thực tế:

```
# 1. GET /health → HTTP 200
{"status":"ok","service":"day12-agent","version":"1.0.0"}

# 2. GET /ready → HTTP 200 (Redis đã kết nối)
{"status":"ready","redis":true}

# 3. POST /ask không có API key → HTTP 401

# 4. POST /ask có API key → HTTP 200
{"answer":"Ngắn gọn: Deploy là gì phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.","user_id":"sv-test","history_length":0,"cost_usd":2.265e-05,"tokens":{"in":3,"out":37}}

# 5. Rate limit — 15 lần liên tục (user sv-test, hạn mức 10/phút)
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
# (9 lần 200 vì đã có 1 request trước đó trong cùng cửa sổ 60 giây →
#  đúng 10 request/phút được phép, các lần sau trả 429)
```

## Ảnh Chụp Màn Hình

Khi deploy cloud thật, test không yêu cầu ảnh (mục này chỉ bắt buộc với
phương án dự phòng). Nếu cần minh chứng: `screenshots/health.png` — kết quả
gọi `/health` từ trình duyệt.
