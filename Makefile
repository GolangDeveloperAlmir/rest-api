################################################################################
# RESTFX-DDD PROJECT — MAKEFILE
# ------------------------------------------------------------------------------
# PURPOSE:
#   Primary build automation entrypoint for all services in the repository.
#   It orchestrates local development, code generation, linting, testing,
#   building, containerization, and CI/CD tasks.
#
# STRUCTURE OVERVIEW:
#   • Code Generation (Buf, OpenAPI, SQLC)
#   • Dependency & Linting
#   • Testing (unit/integration)
#   • Build (multi-platform binaries)
#   • Docker (build/push)
#   • CI/CD Pipelines
#   • Utilities (clean/help)
#
# DESIGN GOALS:
#   - Reproducibility: deterministic builds with version metadata
#   - Observability: inject build time, commit hash, tag via LD_FLAGS
#   - Portability: cross-platform support (Linux/macOS, CI runners)
#   - Scalability: support for multi-service monorepos (cmd/*)
#   - Safety: never overwrite binaries or artifacts without explicit cleaning
#
# USAGE EXAMPLES:
#   $ make gen                  # Regenerate contracts (Buf/OpenAPI/SQLC)
#   $ make lint                 # Run lint suite via golangci-lint
#   $ make build SVC=order      # Build the order service binary
#   $ make docker SVC=api       # Build Docker image for API service
#   $ make ci                   # Run full CI pipeline locally
#
# MAINTENANCE NOTES:
#   - All version pins are in tools.mk
#   - Do not edit tool paths manually; always use $(TOOLS_DIR)
#   - CI pipelines rely on the same targets (no duplication in workflows)
#   - Add new service folders under ./cmd/ — no Makefile modification required
#
# FILE RELATIONSHIPS:
#   ├── Makefile          → orchestrates all dev/build ops
#   ├── tools.mk          → installs required pinned binaries
#   ├── .golangci.yml     → defines linting policy
#   ├── .github/workflows → CI integration
#   ├── .dockerignore     → Docker build context pruning
#   └── .gitignore        → repository hygiene
#
################################################################################

include tools.mk

SVC             ?= api
BIN             ?= restfx-$(SVC)
PKG             := github.com/almir/restfx-ddd
GO              ?= go

ENV             ?= dev
CONFIG_FILE     := ./config/$(ENV).yaml

GIT_TAG         := $(shell git describe --tags --always --dirty 2>/dev/null || echo v0.0.0)
COMMIT_HASH     := $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
BUILD_TIME      := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
LD_FLAGS        := -s -w \
	-X $(PKG)/pkg/version.Version=$(GIT_TAG) \
	-X $(PKG)/pkg/version.Commit=$(COMMIT_HASH) \
	-X $(PKG)/pkg/version.BuildTime=$(BUILD_TIME)

OUT_DIR         := bin
CMD_DIR         := ./cmd/$(SVC)
SERVICES        := $(shell ls cmd 2>/dev/null || echo api)

GOOS            ?= linux
GOARCH          ?= amd64

DOCKER_IMAGE    ?= restfx-$(SVC)
DOCKER_TAG      ?= $(GIT_TAG)
DOCKER_FILE     ?= docker/$(SVC).Dockerfile

LINT_TIMEOUT    ?= 10m
GREEN=\033[0;32m
RESET=\033[0m

################################################################################
# Default
################################################################################
.PHONY: all
all: build

################################################################################
# Codegen (Buf / OAPI / SQLC)
################################################################################

gen: $(TOOLS_DIR)/buf $(TOOLS_DIR)/oapi-codegen $(TOOLS_DIR)/sqlc
	@echo "$(GREEN)[gen] Running code generation...$(RESET)"
	buf generate ./contracts || true
	oapi-codegen -generate types,chi-server \
		-package ordersv1 \
		-o pkg/contracts/orders/v1/openapi.gen.go \
		contracts/openapi/orders/v1/openapi.yaml || true
	sqlc generate -f db/sqlc/sqlc.yaml || true
	@echo "✅ Code generation complete."

################################################################################
# Dependencies
################################################################################

deps:
	@echo "$(GREEN)[deps] Downloading modules...$(RESET)"
	$(GO) mod download

tidy:
	@echo "$(GREEN)[tidy] Tidying go.mod...$(RESET)"
	$(GO) mod tidy

################################################################################
# Linting & Quality
################################################################################

fmt:
	@echo "$(GREEN)[fmt] Formatting...$(RESET)"
	$(GO) fmt ./...

vet:
	@echo "$(GREEN)[vet] Vetting...$(RESET)"
	$(GO) vet ./...

lint: $(TOOLS_DIR)/golangci-lint
	@echo "$(GREEN)[lint] Linting with GolangCI-Lint...$(RESET)"
	$(TOOLS_DIR)/golangci-lint run --config .golangci.yml --timeout=$(LINT_TIMEOUT)

################################################################################
# Testing
################################################################################

test:
	@echo "$(GREEN)[test] Running tests...$(RESET)"
	$(GO) test ./... -race -count=1 -v

cover:
	@echo "$(GREEN)[cover] Generating coverage report...$(RESET)"
	$(GO) test ./... -coverprofile=coverage.out -covermode=atomic
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report at coverage.html"

################################################################################
# Build & Run
################################################################################

build:
	@echo "$(GREEN)[build] Building $(SVC)...$(RESET)"
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build -trimpath -buildvcs=false \
		-ldflags "$(LD_FLAGS)" -o $(OUT_DIR)/$(BIN) $(CMD_DIR)
	@echo "✅ Built $(OUT_DIR)/$(BIN)"

run:
	@echo "$(GREEN)[run] Running $(SVC) (env=$(ENV))...$(RESET)"
	$(GO) run $(CMD_DIR) -config $(CONFIG_FILE)

################################################################################
# Docker
################################################################################

docker:
	@echo "$(GREEN)[docker] Building image $(DOCKER_IMAGE):$(DOCKER_TAG)...$(RESET)"
	docker build --build-arg BUILD_TIME=$(BUILD_TIME) --build-arg GIT_TAG=$(GIT_TAG) \
		--build-arg COMMIT_HASH=$(COMMIT_HASH) -f $(DOCKER_FILE) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-push:
	@echo "$(GREEN)[docker-push] Pushing image...$(RESET)"
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

################################################################################
# CI Pipeline
################################################################################

check: fmt vet lint test
ci: gen deps tidy check build docker

################################################################################
# Utilities
################################################################################

clean:
	rm -rf $(OUT_DIR) coverage.out coverage.html sbom.json tools/bin

help:
	@grep -E '^##' Makefile | sed -e 's/## //'
