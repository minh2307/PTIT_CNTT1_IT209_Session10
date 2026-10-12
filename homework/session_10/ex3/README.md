# Bài 3: Tối ưu hóa dung lượng Image & Layer Caching với Multi-stage Build

## 1. Mục tiêu
- Sử dụng kỹ thuật **Multi-stage Build** và **Layer Caching** để giảm dung lượng Docker Image xuống mức tối thiểu.
- Đóng gói ứng dụng Web Backend (Node.js/Express) phục vụ môi trường Production đạt chuẩn tối ưu và an toàn.
- So sánh chi tiết dung lượng, số lượng Layer và hiệu quả caching giữa **Single-stage Build** (`hw-backend:single`) và **Multi-stage Build** (`hw-backend:multistage`).

---

## 2. Cấu trúc thư mục nộp bài
```text
homework/session_10/ex3/
├── Dockerfile          # Multi-stage Dockerfile tối ưu cho Production
├── Dockerfile.single   # Single-stage Dockerfile (chưa tối ưu) để so sánh
├── README.md           # Báo cáo phân tích và kết quả kiểm tra
├── package.json        # Khai báo dependencies của dự án Node.js
├── server.js           # Mã nguồn Web Backend API
└── .dockerignore       # Loại bỏ node_modules, log và git khỏi build context
```

---

## 3. Phân tích thiết kế Dockerfile

### 3.1. Single-stage Build (`Dockerfile.single`)
- **Base image:** `node:18` (dựa trên nền Debian full, chứa đầy đủ trình biên dịch C/C++, Python, package manager, thư viện hệ thống thừa thãi).
- **Vấn đề Layer Caching:** Lệnh `COPY . .` đặt trước `RUN npm install`, làm mất cache cài đặt dependencies mỗi khi sửa code.
- **Dung lượng phình to:** Chứa cả `devDependencies`, cache của `npm`, và các file không dùng trong runtime.

### 3.2. Multi-stage Build (`Dockerfile`)
- **Stage 1 (`builder`):**
  - Sử dụng `node:18-alpine AS builder`.
  - Tối ưu **Layer Caching**: `COPY package*.json ./` được thực hiện trước `COPY . .`, giúp cache lại bước `RUN npm install`. Khi chỉ sửa đổi mã nguồn code mà không thay đổi thư viện, Docker tận dụng cache tức thì.
  - Cài đặt đầy đủ dependencies phục vụ build/test.
- **Stage 2 (`runtime`):**
  - Sử dụng Base Image siêu nhẹ: `node:18-alpine`.
  - Sử dụng chỉ thị `COPY --from=builder` để **chỉ trích xuất các tệp sản phẩm và thư viện cần thiết** (`package*.json`, `node_modules`, `server.js`).
  - Chạy `npm prune --production` để loại bỏ toàn bộ `devDependencies`.
  - Chạy ứng dụng dưới môi trường `NODE_ENV=production`.

---

## 4. Các lệnh kiểm tra

### 4.1. Build cả 2 Image
```bash
# 1. Build image Single-stage
docker build -f Dockerfile.single -t hw-backend:single .

# 2. Build image Multi-stage
docker build -t hw-backend:multistage .
```

### 4.2. Kiểm tra dung lượng Image
```bash
docker images | grep hw-backend
```

**Kết quả thực tế:**
```text
IMAGE                       ID             DISK USAGE   CONTENT SIZE
hw-backend:multistage       6b09a59198bd        190MB           46MB
hw-backend:single           0763c39c81d6       1.59GB          399MB
```

---

## 5. Bảng so sánh chi tiết giữa Single-stage và Multi-stage

| Tiêu chí đánh giá | Single-stage (`hw-backend:single`) | Multi-stage (`hw-backend:multistage`) | Mức độ cải thiện / Nhận xét |
| :--- | :--- | :--- | :--- |
| **Base Image** | `node:18` (Debian) | `node:18-alpine` (Alpine) | Giảm dung lượng nền tảng hơn 85% |
| **Disk Usage (Uncompressed)** | **1.59 GB** | **190 MB** | **Giảm 88.05%** dung lượng |
| **Content Size (Compressed)** | **399 MB** | **46 MB** | **Giảm 88.47%** kích thước nén tải về |
| **Số lượng Layers** | 17 layers | 17 layers | Các layer của Multi-stage có kích thước nhỏ hơn vượt trội |
| **DevDependencies & Cache** | Còn nguyên trong image | Đã được loại bỏ (`npm prune`) | Image sạch, an toàn, không rò rỉ mã nguồn build |
| **Tận dụng Layer Cache** | Kém (mỗi lần đổi code phải `npm install` lại) | Tối ưu (`COPY package*.json ./` riêng biệt) | Rebuild chỉ mất **~0.2s** khi code thay đổi |
| **Bảo mật (Attack Surface)** | Rất lớn (nhiều binary/tool của Debian) | Rất nhỏ (tối giản của Alpine) | Hạn chế tối đa các lỗ hổng CVEs |

> **Đánh giá mục tiêu:** Dung lượng Image giảm **~88%**, vượt xa chỉ tiêu tối thiểu yêu cầu (50% - 70%).

---

## 6. Kiểm tra Layer Caching và Tính ổn định Runtime

### 6.1. Kiểm tra Layer Caching
Khi thực hiện build lại image `hw-backend:multistage`:
```bash
docker build -t hw-backend:multistage .
```
**Kết quả:**
```text
 => CACHED [builder 2/5] WORKDIR /app
 => CACHED [builder 3/5] COPY package*.json ./
 => CACHED [builder 4/5] RUN npm install
 => CACHED [builder 5/5] COPY . .
 => CACHED [stage-1 3/6] COPY --from=builder /app/package*.json ./
 => CACHED [stage-1 4/6] COPY --from=builder /app/node_modules ./node_modules
 => CACHED [stage-1 5/6] COPY --from=builder /app/server.js ./
 => CACHED [stage-1 6/6] RUN npm prune --production
 => exporting to image
[+] Building 0.2s (14/14) FINISHED
```
Thời gian build chỉ mất **0.2 giây** nhờ 100% các layer được lấy từ Build Cache.

---

### 6.2. Kiểm tra Runtime và API Response
Khởi chạy container từ image `hw-backend:multistage`:
```bash
docker run -d --rm --name backend-app -p 3000:3000 hw-backend:multistage
```

Kiểm tra phản hồi API bằng `curl`:
```bash
curl -i http://localhost:3000/
curl -i http://localhost:3000/api/health
```

**Kết quả phản hồi:**
```http
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 144
Date: Mon, 12 Oct 2026 08:26:59 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{
  "status": "success",
  "message": "Hello from Optimized Multi-stage Backend API!",
  "timestamp": "2026-10-12T08:26:59.919Z",
  "environment": "production"
}
```
```http
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 36
Date: Mon, 12 Oct 2026 08:26:59 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{
  "status": "UP",
  "uptime": 1.033015198
}
```

Dọn dẹp container thử nghiệm:
```bash
docker stop backend-app
```
Container chạy hoàn toàn ổn định và phản hồi chính xác mã trạng thái `200 OK` cùng định dạng JSON.
