# syntax=docker/dockerfile:1.2

FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS dev
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

WORKDIR /cloudflare-ext-authz-service/

RUN apk add --no-cache build-base curl

ENV GO111MODULE on
ENV GOPROXY https://proxy.golang.org

COPY go.mod go.sum /cloudflare-ext-authz-service/

RUN go mod download

FROM --platform=$BUILDPLATFORM dev AS build
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

COPY ./ /cloudflare-ext-authz-service/

RUN mkdir /build/ && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -v \
    -ldflags "-s" -a -installsuffix cgo \
    -o /build/cloudflare-ext-authz-service \
    /cloudflare-ext-authz-service/ \
    && chmod +x /build/cloudflare-ext-authz-service

FROM --platform=$TARGETPLATFORM alpine:3.18 AS prod
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

LABEL org.label-schema.vcs-url="https://github.com/MrSaints/cloudflare-ext-authz-service" \
      maintainer="Ian L. <os@fyianlai.com>"

RUN apk add --no-cache bash ca-certificates curl jq wget nano

COPY --from=build /build/cloudflare-ext-authz-service /cloudflare-ext-authz-service/run

ARG BUILD_VERSION
ENV CFEAZ_SERVICE_VERSION $BUILD_VERSION

ENTRYPOINT ["/cloudflare-ext-authz-service/run"]
