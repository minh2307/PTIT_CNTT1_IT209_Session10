# ==========================================
# Stage 1: Build & Dependencies (builder)
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Tận dụng Build Cache: copy package files trước
COPY package*.json ./

# Cài đặt toàn bộ dependencies (kể cả devDependencies để phục vụ build/test)
RUN npm install

# Copy toàn bộ mã nguồn
COPY . .

# ==========================================
# Stage 2: Production Runtime (siêu nhẹ)
# ==========================================
FROM node:18-alpine

WORKDIR /app

ENV NODE_ENV=production

# Sử dụng chỉ thị COPY --from=builder để chỉ trích xuất tệp sản phẩm cần thiết
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

# Loại bỏ devDependencies để thu gọn dung lượng tối đa
RUN npm prune --production

EXPOSE 3000

CMD ["node", "server.js"]
