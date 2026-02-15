FROM node:18-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:18-slim
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 5000
CMD ["node", "index.js"]