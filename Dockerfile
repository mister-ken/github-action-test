# syntax=docker/dockerfile:1

FROM golang:1.25
LABEL org.opencontainers.image.source=https://github.com/mister-ken/github-action-test
WORKDIR /app
COPY go.mod go.sum ./
COPY token ./
# COPY kube_ca_cert ./
RUN go mod download
COPY *.go ./
ADD templates /app/templates
RUN CGO_ENABLED=0 GOOS=linux go build -o test-vault-client
EXPOSE 8080
CMD ["./test-vault-client"]
# CMD ["bash", "-c", "while true; do sleep 30; done;"] 