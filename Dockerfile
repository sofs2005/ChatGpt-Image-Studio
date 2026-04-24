FROM node:24-alpine AS web-builder
WORKDIR /workspace/web

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./
RUN npm run build

FROM golang:1.26-alpine AS backend-builder
WORKDIR /workspace/backend

COPY backend/go.mod backend/go.sum ./
RUN go mod download

COPY backend/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/chatgpt2api-studio .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata && update-ca-certificates

WORKDIR /app/backend

COPY --from=backend-builder /out/chatgpt2api-studio /app/backend/chatgpt2api-studio
COPY backend/internal/config/config.defaults.toml /app/backend/data/config.defaults.toml
COPY --from=web-builder /workspace/web/dist/. /app/backend/static/

RUN mkdir -p /app/backend/data/auths /app/backend/data/sync_state /app/backend/data/tmp/image

EXPOSE 7000

CMD ["./chatgpt2api-studio"]
