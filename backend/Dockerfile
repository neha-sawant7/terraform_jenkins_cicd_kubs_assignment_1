# FROM golang:1.19-buster AS build
# WORKDIR /app
# COPY backend ./backend
# RUN go env -w GOPROXY=https://proxy.golang.org
# RUN go get ./...
# RUN CGO_ENABLED=0 go build -o /app/server main.go

# FROM debian:buster-slim
# COPY --from=build /app/server /usr/local/bin/server
# EXPOSE 8080
# CMD ["/usr/local/bin/server"]



FROM golang:1.19-buster AS build
WORKDIR /app/backend
COPY backend ./
RUN go env -w GOPROXY=https://proxy.golang.org
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server main.go

FROM debian:buster-slim
COPY --from=build /app/server /usr/local/bin/server
EXPOSE 8080
CMD ["/usr/local/bin/server"]
