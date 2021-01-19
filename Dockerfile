FROM golang:1.15-alpine AS dev

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

WORKDIR /cloudflare-ext-authz-service/

RUN apk add --no-cache build-base curl

ENV GO111MODULE on
ENV GOPROXY https://proxy.golang.org

COPY go.mod go.sum /cloudflare-ext-authz-service/

RUN go mod download


FROM dev as build

COPY ./ /cloudflare-ext-authz-service/

RUN mkdir /build/

RUN CGO_ENABLED=0 \
    go build -v \
    -ldflags "-s" -a -installsuffix cgo \
    -o /build/cloudflare-ext-authz-service \
    /cloudflare-ext-authz-service/ \
    && chmod +x /build/cloudflare-ext-authz-service


FROM alpine:3.12 AS prod

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

RUN apk add --no-cache bash ca-certificates curl jq wget nano

COPY --from=build /build/cloudflare-ext-authz-service /cloudflare-ext-authz-service/run

RUN GRPC_HEALTH_PROBE_VERSION=v0.3.1 && \
    wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
    chmod +x /bin/grpc_health_probe

ARG BUILD_VERSION
ENV CFEAZ_SERVICE_VERSION $BUILD_VERSION

ENTRYPOINT ["/cloudflare-ext-authz-service/run"]
