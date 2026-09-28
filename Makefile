.PHONY: build test lint chart release hooks

build:
	go build -mod=readonly -trimpath -o bin/minikube-cluster-autoscaler-addon .

test:
	go test -race -coverprofile=coverage.out ./...

lint:
	pre-commit run --all-files

chart:
	bash scripts/chart-dependencies.sh
	helm lint charts/minikube-cluster-autoscaler-addon --set provider.address=192.168.105.1:50051 --kube-version 1.35.0

release:
	bash scripts/build-release.sh "$(VERSION)" "$(GOOS)" "$(GOARCH)"

hooks:
	pre-commit install
