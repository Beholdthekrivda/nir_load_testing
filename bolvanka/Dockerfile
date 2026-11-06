FROM gcc:latest AS builder

WORKDIR /build

COPY sha1_sum.c .

RUN gcc -static sha1_sum.c -o sha1_sum


FROM alpine:latest AS work

WORKDIR /app

COPY --from=builder /build/sha1_sum .

ENTRYPOINT ["/app/sha1_sum"]

CMD ["time", "10"]
