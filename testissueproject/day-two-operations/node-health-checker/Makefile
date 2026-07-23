.PHONY: build test clean docker-build docker-push deploy undeploy

# Variables
APP_NAME := node-health-checker
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
DOCKER_REGISTRY ?= your-registry
DOCKER_IMAGE := $(DOCKER_REGISTRY)/$(APP_NAME):$(VERSION)
DOCKER_IMAGE_LATEST := $(DOCKER_REGISTRY)/$(APP_NAME):latest

# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOCLEAN := $(GOCMD) clean
GOMOD := $(GOCMD) mod
BINARY_NAME := $(APP_NAME)

all: test build

## Build the Go binary
build:
	@echo "Building $(BINARY_NAME)..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(BINARY_NAME) -v ./cmd

## Run tests
test:
	@echo "Running tests..."
	$(GOTEST) -v -race -coverprofile=coverage.out ./...

## Run tests with coverage report
coverage: test
	@echo "Generating coverage report..."
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## Clean build artifacts
clean:
	@echo "Cleaning..."
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html

## Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

## Build Docker image
docker-build:
	@echo "Building Docker image $(DOCKER_IMAGE)..."
	docker build -t $(DOCKER_IMAGE) -t $(DOCKER_IMAGE_LATEST) .

## Push Docker image
docker-push: docker-build
	@echo "Pushing Docker image..."
	docker push $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE_LATEST)

## Deploy to Kubernetes
deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f deployments/daemonset.yaml
	kubectl apply -f deployments/service.yaml
	@echo "Waiting for rollout..."
	kubectl rollout status daemonset/node-health-checker -n kube-system

## Undeploy from Kubernetes
undeploy:
	@echo "Removing from Kubernetes..."
	kubectl delete -f deployments/service.yaml --ignore-not-found=true
	kubectl delete -f deployments/daemonset.yaml --ignore-not-found=true

## View logs
logs:
	kubectl logs -n kube-system -l app=node-health-checker --tail=100 -f

## Check pod status
status:
	kubectl get pods -n kube-system -l app=node-health-checker -o wide

## Run locally (requires root for dmesg/systemctl access)
run:
	@echo "Running locally (requires root)..."
	sudo ./$(BINARY_NAME) --log-level=debug

## Format code
fmt:
	@echo "Formatting code..."
	$(GOCMD) fmt ./...

## Lint code
lint:
	@echo "Linting code..."
	golangci-lint run ./...

## Help
help:
	@echo "Available targets:"
	@echo "  build         - Build the Go binary"
	@echo "  test          - Run tests"
	@echo "  coverage      - Generate coverage report"
	@echo "  clean         - Clean build artifacts"
	@echo "  deps          - Download dependencies"
	@echo "  docker-build  - Build Docker image"
	@echo "  docker-push   - Push Docker image"
	@echo "  deploy        - Deploy to Kubernetes"
	@echo "  undeploy      - Remove from Kubernetes"
	@echo "  logs          - View pod logs"
	@echo "  status        - Check pod status"
	@echo "  run           - Run locally"
	@echo "  fmt           - Format code"
	@echo "  lint          - Lint code"
	@echo "  help          - Show this help"
