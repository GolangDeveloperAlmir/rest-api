################################################################################
# RESTFX-DDD PROJECT — tools.mk
# ------------------------------------------------------------------------------
# PURPOSE:
#   Centralized toolchain manager for installing and pinning CLI dependencies.
#
# WHY:
#   Ensures that all contributors and CI environments use the exact same
#   versions of build tools — eliminating "works on my machine" drift.
#
# INCLUDED TOOLS:
#   - buf             → protobuf contract generator
#   - oapi-codegen    → OpenAPI spec → Go code generator
#   - sqlc            → SQL → type-safe Go queries generator
#   - golangci-lint   → Static analysis suite (integrated with .golangci.yml)
#
# DESIGN PRINCIPLES:
#   • Pinned versions per release for deterministic reproducibility.
#   • Installs into isolated $(TOOLS_DIR) (never pollutes global $GOPATH).
#   • CI-friendly: cached via GitHub/GitLab runners.
#
# USAGE:
#   $ make install-tools   # Install all required tools
#   $ make clean-tools     # Remove tools/bin directory
#
# EXAMPLES:
#   $(TOOLS_DIR)/buf --version
#   $(TOOLS_DIR)/sqlc generate -f db/sqlc/sqlc.yaml
#
# MAINTENANCE:
#   • Update tool versions only after validating backward compatibility.
#   • Always test generation pipelines (`make gen`) after bumping versions.
#   • Avoid mixing go install versions across branches.
################################################################################

BUF_VERSION          := v1.27.0
OAPI_CODEGEN_VERSION := v0.5.0
SQLC_VERSION         := v1.26.0
GOLANGCI_LINT_VERSION:= v1.59.2

TOOLS_DIR            := tools/bin
GOBIN                := $(TOOLS_DIR)
PATH                := $(GOBIN):$(PATH)

.PHONY: install-tools clean-tools

install-tools: $(TOOLS_DIR)/buf \
               $(TOOLS_DIR)/oapi-codegen \
               $(TOOLS_DIR)/sqlc \
               $(TOOLS_DIR)/golangci-lint
	@echo "✅ All tools installed into $(TOOLS_DIR)"

$(TOOLS_DIR)/buf:
	@mkdir -p $(TOOLS_DIR)
	@echo "🔧 Installing buf $(BUF_VERSION)..."
	GO111MODULE=on GOBIN=$(TOOLS_DIR) go install github.com/bufbuild/buf/cmd/buf@$(BUF_VERSION)

$(TOOLS_DIR)/oapi-codegen:
	@mkdir -p $(TOOLS_DIR)
	@echo "🔧 Installing oapi-codegen $(OAPI_CODEGEN_VERSION)..."
	GO111MODULE=on GOBIN=$(TOOLS_DIR) go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@$(OAPI_CODEGEN_VERSION)

$(TOOLS_DIR)/sqlc:
	@mkdir -p $(TOOLS_DIR)
	@echo "🔧 Installing sqlc $(SQLC_VERSION)..."
	GO111MODULE=on GOBIN=$(TOOLS_DIR) go install github.com/kyleconroy/sqlc/cmd/sqlc@$(SQLC_VERSION)

$(TOOLS_DIR)/golangci-lint:
	@mkdir -p $(TOOLS_DIR)
	@echo "🔧 Installing golangci-lint $(GOLANGCI_LINT_VERSION)..."
	curl -sSfL https://github.com/golangci/golangci-lint/releases/download/$(GOLANGCI_LINT_VERSION)/golangci-lint-$(GOLANGCI_LINT_VERSION)-$(shell uname -s)-$(shell uname -m).tar.gz \
	  | tar -xz -C $(TOOLS_DIR) --strip-components=1 golangci-lint-$(GOLANGCI_LINT_VERSION)-$(shell uname -s)-$(shell uname -m)/golangci-lint
	chmod +x $(TOOLS_DIR)/golangci-lint

clean-tools:
	rm -rf $(TOOLS_DIR)
