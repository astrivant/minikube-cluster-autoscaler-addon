# Build a Linux provider for the host's architecture, independent of the bridge OS.
FROM golang:1.27.1 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
COPY internal ./internal
ARG TARGETOS=linux
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -mod=readonly -trimpath -o /provider .

FROM scratch
COPY --from=build /provider /provider
USER 65532:65532
EXPOSE 50051
ENTRYPOINT ["/provider"]
CMD ["--mode=serve", "--config=/state/config.json", "--state-dir=/state"]
