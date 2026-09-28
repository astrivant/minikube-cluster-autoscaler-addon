# Build a Linux provider for the host's architecture, independent of the bridge OS.
FROM golang:1.27.1 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
COPY pkg ./pkg
ARG TARGETOS=linux
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -mod=readonly -trimpath -o /provider .

FROM scratch AS runtime
USER 65532:65532
EXPOSE 50051
ENTRYPOINT ["/provider"]
CMD ["--mode=serve", "--config=/state/config.json", "--state-dir=/state"]

# Release archives provide the Linux binary without requiring Go or source files.
FROM runtime AS production
COPY bin/provider-linux /provider

# Keep source builds as the default for plain `docker build .`.
FROM runtime AS development
COPY --from=build /provider /provider
