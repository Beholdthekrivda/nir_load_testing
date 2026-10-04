FROM golang:alpine AS builder

RUN apk add --no-cache git ca-certificates

RUN go install go.k6.io/xk6/cmd/xk6@latest

RUN xk6 build --with github.com/grafana/xk6-kafka

FROM alpine:latest

COPY --from=builder /go/k6 /usr/bin/k6

COPY test.js /test.js
COPY payloads.json /payloads.json

ENTRYPOINT ["k6", "run", "/test.js"]
