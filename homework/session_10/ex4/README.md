# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu
- Tạo **Custom Bridge Network** (`app-net`) để các Container giao tiếp nội bộ qua tên service (Docker DNS resolution).
- Tạo **Named Volume** (`db-data`) lưu trữ dữ liệu bền vững cho Database.
- Kết nối cụm 2 Container: **Backend Container** (`app-container`) và **PostgreSQL Database** (`db-server`).
- Kiểm tra tính bền vững của dữ liệu (**Data Persistence**): Thêm dữ liệu ➔ Xóa cứng container DB ➔ Khởi chạy lại container DB mới gắn cùng Volume ➔ Xác minh dữ liệu nguyên vẹn.

---

## 2. Cấu trúc thư mục nộp bài
```text
homework/session_10/ex4/
├── commands.sh
└── README.md
```

---

## 3. Các bước thực hiện

### Bước 1: Tạo Custom Bridge Network
Tạo mạng bridge riêng tên `app-net`:
```bash
docker network create app-net
```

### Bước 2: Tạo Named Volume
Tạo volume lưu trữ dữ liệu bền vững tên `db-data`:
```bash
docker volume create db-data
```

### Bước 3: Khởi chạy Database Container (`db-server`)
Chạy PostgreSQL 15 Alpine, kết nối vào mạng `app-net`, mount volume `db-data` vào thư mục dữ liệu chuẩn `/var/lib/postgresql/data`:
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```

### Bước 4: Khởi chạy Backend Container (`app-container`)
Khởi chạy container backend tham gia cùng mạng `app-net`, cấu hình biến môi trường trỏ đến database thông qua hostname `db-server`:
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=testdb \
  alpine sleep infinity
```

---

## 4. Kiểm tra kết nối mạng & DNS Resolution

Chạy lệnh ping từ `app-container` tới `db-server`:
```bash
docker exec -it app-container ping -c 2 db-server
```

**Kết quả thực tế:**
```text
PING db-server (172.27.0.2): 56 data bytes
64 bytes from 172.27.0.2: seq=0 ttl=64 time=0.070 ms
64 bytes from 172.27.0.2: seq=1 ttl=64 time=0.113 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.070/0.091/0.113 ms
```
> **Nhận xét**: Container `app-container` đã phân giải thành công hostname `db-server` thành địa chỉ IP nội bộ `172.27.0.2` thông qua Docker embedded DNS trên custom network `app-net`.

---

## 5. Kiểm tra Data Persistence (Độ bền vững dữ liệu)

### Bước 5.1: Thêm dữ liệu mẫu vào DB
Tạo bảng `users` và chèn 2 bản ghi:
```bash
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));"
docker exec -i db-server psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
**Kết quả:**
```text
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```

### Bước 5.2: Xóa cứng Database Container
Xóa bỏ hoàn toàn container đang chạy:
```bash
docker rm -f db-server
```

### Bước 5.3: Khởi tạo Container DB mới gắn lại Volume `db-data`
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```

### Bước 5.4: Xác minh dữ liệu không bị mất
Chờ PostgreSQL khởi động xong và truy vấn lại dữ liệu:
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
**Kết quả:**
```text
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```
> **Kết luận**: Dù container cũ đã bị xóa hoàn toàn (`docker rm -f`), toàn bộ dữ liệu vẫn được bảo toàn nguyên vẹn nhờ việc mount Named Volume `db-data`.

---

## 6. Lệnh kiểm tra và Kết quả theo yêu cầu

### 6.1. Kiểm tra Network:
```bash
docker network ls | grep app-net
```
**Output:**
```text
ae8d75c0cf43   app-net                            bridge    local
```

### 6.2. Kiểm tra Volume:
```bash
docker volume ls | grep db-data
```
**Output:**
```text
local     db-data
```

### 6.3. Kiểm tra chi tiết Network `app-net`:
```bash
docker network inspect app-net
```
**Output trích dẫn (phần Containers):**
```json
"Containers": {
    "792c43f172e0b53b0b6c431cbdd66bf98b644cdddaff08bb2b8de2e2e4be74b8": {
        "Name": "db-server",
        "EndpointID": "73b50c39532f369a75ca96fb297a3ca2cb46b13e088ef1ce30f74c603965a941",
        "MacAddress": "3a:d4:64:62:0f:c3",
        "IPv4Address": "172.27.0.2/16",
        "IPv6Address": ""
    },
    "a2bbe3e21bc73ed4200028c237c2d2e7df50f76f4c3da713abdf5a5a7c680b34": {
        "Name": "app-container",
        "EndpointID": "9d5fcb25f5211edbb4f6df928a8cbf444d4c7fc9c818f42b8512e4eb21e1a1f2",
        "MacAddress": "ba:27:3e:9d:60:26",
        "IPv4Address": "172.27.0.3/16",
        "IPv6Address": ""
    }
}
```

### 6.4. Kiểm tra DNS Resolution từ Backend Container:
```bash
docker exec -it app-container ping -c 2 db-server
```
**Output:**
```text
PING db-server (172.27.0.2): 56 data bytes
64 bytes from 172.27.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.27.0.2: seq=1 ttl=64 time=0.098 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.082/0.090/0.098 ms
```

### 6.5. Chạy toàn bộ quy trình tự động bằng script
Để chạy toàn bộ bài thực hành từ đầu đến cuối một cách tự động:
```bash
chmod +x commands.sh
./commands.sh
```
