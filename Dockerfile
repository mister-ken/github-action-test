# syntax=docker/dockerfile:1

FROM golang:1.25

LABEL org.opencontainers.image.source=https://github.com/mister-ken/github-action-test

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
ADD templates /app/templates
RUN CGO_ENABLED=0 GOOS=linux go build -o test-vault-client
EXPOSE 8080

CMD ["./test-vault-client"]