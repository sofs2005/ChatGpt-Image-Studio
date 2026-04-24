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
ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_TIME=unknown
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -ldflags="-s -w -X chatgpt2api/internal/buildinfo.Version=${VERSION} -X chatgpt2api/internal/buildinfo.Commit=${COMMIT} -X chatgpt2api/internal/buildinfo.BuildTime=${BUILD_TIME}" \
      -o /out/chatgpt2api-studio .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata && update-ca-certificates

WORKDIR /app

COPY --from=backend-builder /out/chatgpt2api-studio /app/chatgpt2api-studio
COPY backend/internal/config/config.defaults.toml /app/data/config.example.toml
COPY --from=web-builder /workspace/web/dist /app/static

RUN mkdir -p /app/data/auths /app/data/sync_state /app/data/tmp/image

EXPOSE 7000

CMD ["./chatgpt2api-studio"]
