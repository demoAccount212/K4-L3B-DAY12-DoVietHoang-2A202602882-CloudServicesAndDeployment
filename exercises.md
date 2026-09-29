# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder (in nghiêng, có dấu hoa thị) ở dưới
> mỗi câu bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Đỗ Việt Hoàng  Mã học viên: 2A202602882

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: đêm trước ngày demo, bạn deploy lên Railway nhưng quên set biến
`AGENT_API_KEY`. Với fail-fast, container không thể vượt qua bước khởi tạo
cấu hình → healthcheck thất bại, dashboard báo deploy lỗi kèm ngay thông báo
`agent_api_key: Field required` → bạn thấy và sửa trong vài giây. Nếu để mặc
định `"changeme"`, service vẫn khởi động xanh, `/health` vẫn 200 nên mọi thứ
trông "ổn" — nhưng `"changeme"` là khóa công khai ai cũng đoán được: kẻ xấu
gọi `/ask` với key mặc định thì được trả lời **miễn phí trên chi phí của
bạn**, còn client thật dùng key đúng lại bị 401 mà không hiểu lý do. Lỗi
thầm lặng kiểu đó phát hiện muộn nhất lại hay bị bỏ qua lâu nhất.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thật thu được từ stdout của uvicorn khi gọi `/ask`:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:58:58.388812+00:00", "user_id": "sv-log", "tokens_in": 2, "tokens_out": 34, "cost_usd": 2.07e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Tổng hợp chi phí bằng máy theo trường dữ liệu**: mỗi dòng có `cost_usd`
   và `user_id` là số/chuỗi chuẩn → một câu `jq '[.cost_usd] | add'` hoặc
   query trên ELK/CloudWatch trả lời ngay "hôm nay tốn bao nhiêu, user nào
   tốn nhất". `print` chỉ là chuỗi text, máy không tách được trường nào ra
   để cộng.
2. **Lọc và truy vết theo thời gian sự cố**: có `timestamp` ISO và `event`
   nên lọc được "mọi `ask_completed` trong khoảng 14:00–14:05 khi báo lỗi"
   trên cả 3 replica (chúng in cùng định dạng, cùng một luồng log). Dòng
   `print("đã trả lời xong")` không có thời gian, không tên sự kiện, không
   user — không biết *ai* trả lời lúc nào nên không truy vết được.

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
| 1 stage (bản đầu) | 1.730 MB (1,73 GB) |
| Multi-stage | 288 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Chênh lệch ~1,4 GB, chủ yếu là:

- **Base image**: bản đầu dùng `python:3.11` bản đầy đủ (Debian full) — đã
  kèm sẵn `gcc/g++`, header, `apt`, docs... dùng để biên dịch extension C
  lúc `pip install`; nặng hơn bản `python:3.11-slim` rất nhiều.
- **Toolchain + cache pip theo cùng image**: một stage duy nhất nghĩa là
  image cuối vẫn chứa mọi thứ đã dùng để build (compiler, cache, thư mục
  tạm), không chỗ nào cắt bỏ.
- Bản multi-stage chỉ **copy kết quả** (`/usr/local` — site-packages, và
  `/app` — code) sang stage runtime slim → không compiler, không cache, không
  file tạm. Ngoài ra còn ít lỗ hổng hơn vì giảm bề mặt tấn công.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Thử thật (đổi 1 ký tự `SERVICE_NAME` rồi build, log BuildKit):

- **CACHED (dùng lại)**: `FROM`, `WORKDIR`, `COPY requirements.txt`, và quan
  trọng nhất là `RUN pip install` — `requirements.txt` không đổi nên cache
  hit, **không tải lại thư viện nào**. `COPY --from=builder /usr/local`
  cũng CACHED vì nội dung site-packages giữ nguyên.
- **Phải chạy lại**: `COPY . .` (nội dung source đổi → cache miss), kéo theo
  `COPY --from=builder /app` và `RUN groupadd` ở stage runtime chạy lại.

Nếu đặt `COPY . .` trước `RUN pip install`: sửa bất kỳ 1 dòng code nào cũng
làm invalid tầng `COPY . .` → tầng `pip install` nằm sau nó cũng miss → mỗi
lần sửa code đều phải **cài lại toàn bộ dependency từ PyPI** (chậm hàng
phút, phụ thuộc mạng, dễ fail khi mạng chập chờn) dù `requirements.txt`
không hề đổi. Thứ tự đúng biến thời gian build từ ~phút xuống ~giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: lỗ hổng trong code Python (ví dụ `pickle.loads` dữ liệu người
dùng đưa vào, hay `eval`, hay path traversal lúc upload file) → attacker
thực thi được lệnh tùy ý **trong container**. Container chạy root nên process
đó là root: attacker đọc mọi secret trong container, sửa code app, cài thêm
tool; và nếu kết hợp thêm một điều kiện thoát container (volume mount thư mục
host, gắn `docker.sock`, capability `SYS_ADMIN`/`--privileged`, hoặc một lỗ
hổng kernel) thì root trong namespace container → **root trên máy host**
vì không có gì tách biệt quyền hạn → chiếm nguyên host và lây sang các
container khác.

`USER appuser` cắt ngay ở bước đầu: sau khi thoát được code Python, kẻ tấn
công chỉ là một user thường (uid ≠ 0) trong container — thiếu quyền ghi file
hệ thống, thiếu capability mặc định của root. Các lỗ hổng lợi dụng đặc quyền
để leo thang (cần root/sysadmin mới phát huy) sẽ thất bại, chí ít thì "thoát
app" cũng không đồng nghĩa với "có quyền cao trên host".

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

**20 request** trong 2 giây. Cách đạt: gửi 10 request vào giây ~59 của phút
T (dùng hết hạn mức của cửa sổ A), rồi chờ đồng hồ sang giây 00 của phút
T+1 — bộ đếm cửa sổ cố định reset về 0 → gửi tiếp 10 request ngay trong giây
00–01 (cửa sổ B). Tổng cộng 10 + 10 = **20 request trong vòng ~2 giây** — 10
cái cuối của phút cũ và 10 cái đầu của phút mới, vượt gấp đôi hạn mức.

Sliding window không bị vậy vì nó đếm theo từng timestamp trong 60 giây vừa
qua: 10 request ở giây 59 vẫn còn "nằm" trong cửa sổ khi sang giây 00 → số
còn lại chỉ được phép là 0 → chặn ngay từ request thứ 11.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác nhau: **rate limit** đo *tần suất* trong cửa sổ ngắn (số request/phút
của từng user) để bảo vệ khả năng xử lý và sự công bằng; **cost guard** đo
*tổng tiền* tích lũy (bộ ngân sách tháng) để bảo vệ ví tiền. Một bên đếm
"số lần gọi", bên kia cộng "số đô".

- **Rate limit cho qua, cost guard chặn**: một user gửi đều 1 request/phút
  (luôn dưới 10/phút) nhưng mỗi prompt rất dài, mỗi lần tốn ~0,05 USD → hết
  tháng chạm 10 USD → cost guard trả 402 dù tần suất chưa bao giờ vi phạm.
- **Ngược lại**: ngân sách tháng còn gần đầy, user bắn 15 request trong 1
  phút với prompt nhỏ, mỗi cái chỉ vài xu (cost guard thấy tổng mới vài chục
  cent, cho qua) → rate limit chặn 429 từ request thứ 11.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:

1. ~10 giây sau (chu kỳ healthcheck), **cả 3 container** cùng trả về "unhealthy"
   vì chúng đều phụ thuộc Redis và Redis cùng lúc mất kết nối.
2. Orchestrator/LB coi cả 3 là unhealthy → gỡ hết khỏi load balancer → mọi
   request nhận 502/503, và/hoặc với `restartPolicy` thì lần lượt **restart
   cả 3 container** — dù process app vẫn sống tốt, lỗi chỉ nằm ở data layer.
3. Container vừa restart xong mà Redis chưa hồi → healthcheck tiếp tục fail →
   rơi vào **vòng restart (crash loop)**, xảy ra đồng loạt trên cả 3.
4. Đến giây thứ 30 Redis hồi phục: hàng loạt container cùng reconnect một lúc
   (thundering herd) và phải chờ healthcheck pass mới nhận traffic → downtime
   thực tế kéo dài **nhiều hơn 30 giây**.

Trong khi đó nếu tách bạch: app hoàn toàn vẫn chạy được — `/health` trả 200
(process vẫn sống, không cần restart ai), chỉ `/ready` trả 503 để LB ngừng
đẩi request vào; Redis hồi là traffic tự quay lại ngay, không có restart
đồng loạt, không crash loop.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Thử thật với 3 replica, cùng `X-User-Id=sv-scale`, gọi xoay vòng 6 lần (mỗi
`/ask` lưu 2 message: user + assistant):

```
call#1 -> agent-1: history_length=0
call#2 -> agent-2: history_length=2
call#3 -> agent-3: history_length=4
call#4 -> agent-1: history_length=6
call#5 -> agent-2: history_length=8
call#6 -> agent-3: history_length=10
```

Con số tăng đều (0,2,4,6,8,10) dù request rơi vào replica khác nhau — vì
mọi replica đọc/ghi **cùng một Redis**, app vì thế là stateless.

Nếu lưu trong dict Python (in-process) thì mỗi replica chỉ thấy lịch sử do
**chính nó** xử lý: call#1 vào agent-1 (dict trống) → 0; call#2 vào agent-2
(cũng trống) → **0 thay vì 2**; call#3 → 0; call#4 quay lại agent-1 → 2...
Kết quả sẽ là dạng 0,0,0,2,0,0,... — lịch sử "nhấp nháy" tùy replica nào
nhận request, model trả lời mà không biết câu chuyện trước đó, và số lượt
"user_id" này trong Redis... không tồn tại.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi gặp: deploy lên Railway, `GET /health` trả 200 (app chạy) nhưng `GET
/ready` và `POST /ask` đều trả **500 Internal Server Error** (đáng lẽ `/ask`
không key phải là 401).

Tìm nguyên nhân: 500 là exception chưa được bắt, xảy ra **trước** bước xác
thực (vì 401 không bao giờ tới) — mà dependency duy nhất chạy trước auth là
`get_settings()` validate `Settings`; trong đó chỉ `agent_api_key` là bắt
buộc, không có default. Suy ra: **biến `AGENT_API_KEY` chưa được set trên
Railway** (app khởi động được vì Settings chỉ được gọi khi có request). Kiểm
tra Variables trên dashboard → đúng là thiếu (chưa set biến nào).

Sửa: vào Railway → service → tab Variables, set `AGENT_API_KEY` (khóa giống
local), `REDIS_URL=${{Redis.REDIS_URL}}` (tham chiếu runtime tới Redis plugin),
`RATE_LIMIT_PER_MINUTE`, `MONTHLY_BUDGET_USD`, `LOG_LEVEL` → Railway tự
redeploy → kiểm tra lại: `/ready` trả 200 `{"status":"ready","redis":true}`,
`/ask` trả 401/401→200 như kỳ vọng.

Bài học: đọc tín hiệu HTTP sai thứ tự (500 ≠ 401) chính là manh mối để khoanh
vùng đúng tầng lỗi — thay vì mò vào code auth.
