#!/bin/bash
set -e

echo "=========================================================="
echo " Bài 4: Thiết lập Custom Network & Named Volume (Docker CLI)"
echo "=========================================================="

echo ""
echo "[Bước 0] Dọn dẹp các tài nguyên cũ nếu đang tồn tại..."
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true

echo ""
echo "[Bước 1] Tạo Custom Bridge Network: app-net"
docker network create app-net

echo ""
echo "[Bước 2] Tạo Named Volume: db-data"
docker volume create db-data

echo ""
echo "[Bước 3] Khởi chạy Database Container (db-server: postgres:15-alpine)"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo ""
echo "[Bước 4] Khởi chạy Backend Container (app-container)"
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=testdb \
  alpine sleep infinity

echo ""
echo "[Bước 5] Kiểm tra DNS Resolution & Network Connectivity giữa 2 Container"
docker exec app-container ping -c 2 db-server

echo ""
echo "[Bước 6] Thực hiện kiểm tra Data Persistence:"
echo "--- 6.1: Đợi PostgreSQL sẵn sàng nhận kết nối..."
until docker exec db-server pg_isready -U postgres -d testdb > /dev/null 2>&1; do
  sleep 1
done

echo "--- 6.2: Tạo bảng và thêm dữ liệu mẫu vào PostgreSQL..."
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));"
docker exec -i db-server psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"

echo "--- 6.3: Dữ liệu hiện tại trước khi xóa container:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "--- 6.4: Xóa cứng Database Container (docker rm -f db-server)..."
docker rm -f db-server

echo "--- 6.5: Khởi chạy lại container DB mới gắn cùng Volume db-data..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo "--- 6.6: Đợi PostgreSQL mới sẵn sàng nhận kết nối..."
until docker exec db-server pg_isready -U postgres -d testdb > /dev/null 2>&1; do
  sleep 1
done

echo "--- 6.7: Xác minh dữ liệu không bị mất (Data Persistence):"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo ""
echo "=========================================================="
echo " Hoàn tất bài thực hành Bài 4 thành công!"
echo "=========================================================="
