.PHONY: build test vuln lint chart chart-docs demo-test release hooks

build:
	go build -mod=readonly -trimpath -o bin/minikube-cluster-autoscaler-addon .

test:
	go test -race -coverprofile=coverage.out ./...

vuln:
	go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 -scan=module

lint:
	pre-commit run --all-files

chart:
	bash scripts/chart-dependencies.sh
	helm lint charts/minikube-cluster-autoscaler-addon --set provider.address=192.168.105.1:50051 --kube-version 1.35.0
	helm lint charts/autoscaling-demo --kube-version 1.35.0

scripts/chart-docs/node_modules/.package-lock.json: scripts/chart-docs/package.json scripts/chart-docs/package-lock.json
	npm ci --prefix scripts/chart-docs --ignore-scripts

chart-docs: scripts/chart-docs/node_modules/.package-lock.json
	npm --prefix scripts/chart-docs run generate

demo-test:
	python3 scripts/test-demo.py

release:
	bash scripts/build-release.sh "$(VERSION)" "$(GOOS)" "$(GOARCH)"

hooks:
	pre-commit install
