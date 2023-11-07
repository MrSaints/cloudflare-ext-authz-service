# syntax=docker/dockerfile:1.2

FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS dev

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

WORKDIR /cloudflare-ext-authz-service/

RUN apk add --no-cache build-base curl

ENV GO111MODULE on
ENV GOPROXY https://proxy.golang.org

COPY go.mod go.sum /cloudflare-ext-authz-service/

RUN go mod download

FROM --platform=$BUILDPLATFORM dev AS build

COPY ./ /cloudflare-ext-authz-service/

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

RUN mkdir /build/ && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -v \
    -ldflags "-s" -a -installsuffix cgo \
    -o /build/cloudflare-ext-authz-service \
    /cloudflare-ext-authz-service/ \
    && chmod +x /build/cloudflare-ext-authz-service

FROM --platform=$TARGETPLATFORM alpine:3.18 AS prod

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

RUN apk add --no-cache bash ca-certificates curl jq wget nano

COPY --from=build /build/cloudflare-ext-authz-service /cloudflare-ext-authz-service/run

ARG GRPC_HEALTH_PROBE_VERSION=v0.3.1
RUN wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-${TARGETARCH} || \
    { echo "Unsupported arch: ${TARGETARCH}" ; exit 1; }



ARG BUILD_VERSION
ENV CFEAZ_SERVICE_VERSION $BUILD_VERSION

ENTRYPOINT ["/cloudflare-ext-authz-service/run"]