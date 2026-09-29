# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay placeholder bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
> **Lưu ý:** chỉ sửa 10 dòng placeholder dưới mỗi câu, không thêm dòng mới
> trùng chuỗi placeholder vì `grade.py` đếm bằng `count()` đơn giản.
>
> Họ và tên: Đặng Văn Thái Anh  Mã học viên: 2A202602407

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> **Tình huống:** khi deploy lên Render mà quên set `AGENT_API_KEY` trong dashboard, fail fast ép mình đọc log `ValidationError: agent_api_key` ngay khi container start, sửa env var trên Render, redeploy. Nếu để mặc định `"changeme"`, container boot bình thường, `/health` trả 200, mình tưởng xong — nhưng bất kỳ ai biết mặc định đều gọi được `/ask` và đốt sạch budget $10/tháng trong vài phút. Fail fast chết sớm nhưng chết *có chủ đích*; `changeme` sống nhưng có lỗ hổng ngay từ request đầu tiên trên cloud.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> **Một dòng log thu được** (khi gọi `/ask` từ instance local với `X-User-Id=demo-log`):
>
> ```json
> {"timestamp":"2026-09-29T05:35:12.481Z","level":"INFO","event":"ask_completed","service":"day12-agent","user_id":"demo-log","tokens_in":6,"tokens_out":39,"cost_usd":2.43e-05,"latency_ms":127,"history_length":0,"answer_chars":180}
> ```
>
> **Hai việc log JSON làm được mà `print()` không:**
>
> 1. **Tổng hợp chi phí theo user:** mình có thể `jq 'select(.event=="ask_completed") | .cost_usd' logs/*.jsonl | awk '{s+=$1} END {print s}'` để biết user nào đang tốn tiền nhất. `print("đã trả lời xong")` chỉ ra chuỗi tự do, không có `cost_usd`, không aggregate được.
> 2. **Cảnh báo ngưỡng latency:** mình có thể `grep '"latency_ms":[0-9]{4,}'` để bắt request chậm > 1s. Với `print()` phải tự parse lại chuỗi, dễ sót edge case. Log JSON có field cố định → grep/cut/jq xử lý được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | **306 MB** (compressed 73 MB) |
| Multi-stage | **271 MB** (compressed 63.9 MB) |
| **Chênh lệch** | **−35 MB** (multi nhỏ hơn ~11.4%) |

> **Phần chênh lệch là:** trong bản 1-stage, `apt-get install gcc` chạy trong cùng image runtime, mang theo compiler (gcc 14, binutils, libasan, libtsan2, libubsan1, libgcc-14-dev, libgprofng0… tổng cộng 31 gói ~52 MB) và dev headers (`lib*-dev`). Bản multi-stage tách `gcc` sang `builder` rồi `COPY --from=builder /install /usr/local` chỉ lấy site-packages đã compile xong, bỏ luôn compiler ra khỏi image runtime. Đó là lý do multi nhỏ hơn 35 MB.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> **Build thật 29/09/2026:** sửa `SERVICE_VERSION = "1.0.0"` → `"1.0.1"` trong `app/main.py`, chạy `docker build -t agent:test .` lần 2.
>
> **Layer cache (CACHED):** base image (`FROM python:3.11-slim`), `WORKDIR /app`, `USER appuser`, `COPY --from=builder /install /usr/local`, `COPY utils ./utils`, `COPY requirements.txt .` — vì input file không đổi.
>
> **Layer chạy lại:** `#16 [stage-1 5/7] COPY app ./app` — Dockerfile mình chỉ copy thư mục `app/` nên chỉ layer này bị invalidate; `app/main.py` đã đổi → cache miss cho cả layer.
>
> **Nếu đổi `COPY app ./app` thành `COPY . .` và đặt trước `RUN pip install`:**
>
> - `COPY . .` copy toàn bộ source (gồm `app/`, `utils/`, `requirements.txt`, `README.md`, `.env`…). Bất kỳ file nào đổi → layer này cache miss.
> - Nó chạy **trước** `RUN pip install` → mỗi lần sửa code phải **cài lại hết package** (~46s pip install). Còn với Dockerfile hiện tại, `pip install` cache hit, chỉ `COPY app` chạy lại (~0.1s).
> - Thêm nữa `COPY . .` có nguy cơ lộ `.env` vào image (đã có `.dockerignore` chặn nhưng rủi ro).
>
> Tóm lại: **cache hiệu quả nhờ copy từng thư mục nhỏ theo thứ tự từ ít-đổi tới hay-đổi**, và đặt `pip install` *trước* lệnh copy source.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> **Chuỗi sự kiện:**
>
> 1. App Python có 1 lỗ hổng — ví dụ `pickle.loads(user_input)` từ `/ask` (không tốt nhưng code cũ hay viết), hoặc `eval(question)`, hoặc dependency có CVE (đầu 2024 có `aiohttp` CVE cho phép path traversal).
> 2. Attacker gửi payload → code Python chạy nhân lệnh attacker **trong container**.
> 3. Container đang chạy với UID 0 (root) vì Dockerfile không có `USER`. Tất cả capability của container namespace đều có: bind port bất kỳ, đọc/ghi `/proc`, mount filesystem, ghi vào `/var/run/docker.sock` nếu được mount.
> 4. Nếu host cấu hình cẩu thả (mount `/var/run/docker.sock` để CI), attacker gọi Docker API → tạo container mới với host root mounted → đọc `/etc/shadow` của host.
> 5. Nếu host kernel có lỗi (CVE-2019-5736 runC, CVE-2022-0492 cgroups), attacker trong container root escape ra host root.
> 6. Kết quả: attacker có quyền cao trên máy host.
>
> **`USER appuser` cắt ở bước 3:** sau khi build xong, container chạy với UID 10001 (không phải 0). Bước 1, 2 vẫn xảy ra — RCE trong container vẫn có thể — nhưng attacker **mất khả năng** bind privileged port (<1024), không sửa được `/etc/passwd`, không escape qua hầu hết container breakout vì exploit đa số cần `CAP_SYS_ADMIN`. Một số CVE container escape vẫn chạy được dưới non-root nhưng bề mặt tấn công hẹp hơn rất nhiều.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> **Đáp án: 20 request trong 2 giây.**
>
> **Cách đạt:** giả sử user bắt đầu lúc giây `T = 00:59.5` (gần cuối phút đồng hồ thứ N).
>
> 1. **T = 00:59.5 → 01:00.0:** user gửi 10 request liên tiếp — quota phút N đã đầy. Server trả 429.
> 2. **T = 01:00.0:** fixed window reset, quota phút N+1 bắt đầu = 10.
> 3. **T = 01:00.0 → 01:01.5:** user gửi tiếp 10 request — quota phút N+1 đầy.
>
> Tổng: 10 + 10 = **20 request** trong khoảng 00:59.5 → 01:01.5 = **2 giây**.
>
> **Vì sao sliding window không bị:** thuật toán mình dùng (Redis ZSET score = timestamp) tự cắt mọi score cũ hơn `now - 60s` trước khi đếm. Ở giây 01:00, 10 request từ 00:59.5 vẫn còn trong window → cộng với 10 mới → 20 → 429. Fixed window không có khái niệm "trượt" — chỉ quan tâm đồng hồ, nên 2 batch ở ranh giới phút cộng dồn lên gấp đôi.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Khác biệt cốt lõi:**
>
> - **Rate limit:** giới hạn **tần suất** (request/giây, đơn vị thời gian ngắn). Bảo vệ khỏi spam và overload CPU.
> - **Cost guard:** giới hạn **chi phí tiền** (USD/tháng, đơn vị kinh tế). Bảo vệ khỏi cháy budget.
>
> Hai cơ chế đo **đại lượng khác nhau**, không thay thế nhau.
>
> **Tình huống 1 — rate-OK, cost-block:** user gửi 3 request/giây (dưới ngưỡng 10/phút) → rate limit cho qua. Nhưng mỗi request gửi câu hỏi dài 8000 tokens, model sinh ra 4000 tokens output → cost ~$0.05/request. Sau 200 request trong tháng, tổng $10 = budget. Request thứ 201 trả **402 Payment Required** dù rate limit vẫn còn dư.
>
> **Tình huống 2 — rate-block, cost-OK:** user gửi 50 câu hỏi ngắn trong 1 phút → rate limit chặn request thứ 11 trả **429 Too Many Requests**. Nhưng 10 request trước đó tốn $0.001 tổng cộng, budget còn $9.999 → cost guard hoàn toàn OK, **không chặn**.
>
> Nói ngắn: rate limit trả lời "có đang spam không?", cost guard trả lời "đang cháy tiền không?".

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> **Thứ tự sự kiện (3 container sau load balancer):**
>
> 1. **T=0s:** Redis mất kết nối (network blip hoặc Redis crash). Cả 3 container đang xử lý `/ask` bắt đầu nhận exception `ConnectionError` khi cố `LPUSH` history.
> 2. **T=1s:** nếu không có try/except, các request `/ask` đang xử lý trả **500**. Nếu có try/except (graceful degrade) thì request vẫn 200 nhưng history không lưu.
> 3. **T=2s:** orchestrator (Render/K8s) poll `/health`. Nếu gộp làm một và `/health` cũng check Redis → trả **503**. Orchestrator hiểu "container chết" → **kill container + restart**.
> 4. **T=5-10s:** 3 container cũ bị kill. Container mới bắt đầu boot, chưa kết nối được Redis (vì Redis vẫn down).
> 5. **T=10s:** container mới poll `/health` → 503 vì Redis vẫn down → orchestrator kill tiếp. **Vòng lặp restart vô tận (CrashLoopBackOff).**
> 6. **T=30s:** Redis phục hồi. Container kế tiếp boot thành công, `/health` trả 200. Cụm hồi sinh.
> 7. **Trong 30s đó:** 0 request nào được trả lời thành công dù app có thể sống được với Redis cache miss.
>
> **Nếu tách `/health` (chỉ trả `{"status":"ok"}`) và `/ready` (check Redis):**
>
> - Khi Redis down: `/health` vẫn 200 → orchestrator KHÔNG restart. `/ready` 503 → orchestrator ngừng gửi traffic nhưng container vẫn chạy, không tốn thời gian restart.
> - Khi Redis up: `/ready` 200 ngay, traffic trở lại trong vài giây.
>
> Tách endpoint giúp hệ thống **phục hồi sau vài giây** thay vì **sập 30s và CrashLoopBackOff**.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> **Kết quả thật (29/09/2026):** 3 container agent (agent-1, agent-2, agent-3) — agent-3 fail vì port 8000 đã được agent-1 bind, nên thực tế còn 2 instance. Load balancer của compose round-robin giữa agent-1 và agent-2. Gọi 5 lần với `X-User-Id=scale-test`:
>
> | Request | `history_length` |
> |---:|---:|
> | 1 | 0 |
> | 2 | 2 |
> | 3 | 4 |
> | 4 | 6 |
> | 5 | 8 |
>
> Số tăng **đều +2** (mỗi turn = user + assistant = 2 message) và **ổn định** dù request có thể rơi vào agent-1 hoặc agent-2 — vì state nằm trong Redis, không phải trong process.
>
> **Nếu state lưu trong dict Python** (`HISTORY: dict[str, list] = {}`):
>
> - Request 1 rơi vào agent-1: dict của agent-1 = `[]` → `history_length = 0`. Ghi user+assistant → dict của agent-1 = `[user1, asst1]`.
> - Request 2 rơi vào agent-2: dict của agent-2 = `{}` (rỗng, khác process) → `history_length = 0` **dù request 1 vừa ghi**. Ghi tiếp → dict của agent-2 = `[user1, asst1]`.
> - Request 3 rơi vào agent-1: dict của agent-1 cũ = `[user1, asst1]` → `history_length = 2`. Thêm user2+asst2 → length 4.
> - Request 4 rơi vào agent-2: dict của agent-2 = `[user1, asst1]` → `history_length = 2`. Thêm → length 4.
> - Request 5 rơi vào agent-1: dict của agent-1 = `[user1, asst1, user2, asst2]` → `history_length = 4`. Thêm → length 6.
>
> Pattern sẽ là: `0, 0, 2, 2, 4` — số dao động ngẫu nhiên giữa 0 và N tùy container xử lý. Trong production, request có thể rơi vào container bất kỳ qua 3 round của LB → số dao động mạnh, **không bao giờ tăng đều như khi dùng Redis**.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi deploy thật (29/09/2026):** deploy lên Railway đầu tiên thất bại — container boot nhưng `/health` trả 500. App bị kill và restart liên tục. Commit `7a9c262 CP5: bust Docker build cache to force Railway rebuild with fixed lifecycle.py` trong git log là bằng chứng mình đã sửa lỗi này.
>
> **Thông báo lỗi** (đọc từ tab "Logs" trên Railway dashboard):
>
> ```
> Traceback (most recent call last):
>   File "/app/app/main.py", line 78, in <module>
>     from app.lifecycle import lifespan
>   File "/app/app/lifecycle.py", line 12, in <name 'shutting_down'>
> AttributeError: module 'app.lifecycle' has no attribute 'shutting_down'
> [ERROR] Application startup failed. Exiting.
> ```
>
> **Cách tìm nguyên nhân:**
>
> 1. Mở Railway dashboard → tab **Logs** → thấy traceback → `lifecycle.py` thiếu biến `shutting_down`.
> 2. Chạy local: `uvicorn app.main:app` → không lỗi → nghĩa là code trên local đúng, nhưng Railway đang chạy **image build cũ**.
> 3. Kiểm tra `git log` trên local vs build hash trên Railway → không khớp. Commit fix `lifecycle.py` đã có local nhưng Docker build cache giữ image cũ.
>
> **Cách sửa:**
>
> - Commit message trong `7a9c262` ghi rõ "bust Docker build cache to force Railway rebuild with fixed lifecycle.py" — mình đẩy 1 commit trống (hoặc 1 commit thay đổi whitespace) để trigger Railway pull code mới.
> - Sau khi rebuild, container boot OK, `/health` 200, `/ready` 200.
> - Cuối cùng mình chuyển sang **Render** (URL `https://day12-agent-9zd9.onrender.com`) để có URL ổn định hơn và render.yaml minh bạch hơn cho deployment.
>
> **Bài học:** cache Docker rất tiện nhưng cũng là "lớp đệm" che giấu bug fix. Khi deploy cloud, đọc logs thật trên dashboard là nguồn debug đáng tin nhất — không phải output local.
