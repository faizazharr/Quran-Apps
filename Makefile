# ─────────────────────────────────────────────────────────────────────────────
# Quran Player — developer convenience targets
#
# Usage:
#   make setup      — install git hooks (run once after cloning)
#   make check      — run the full pre-push gate locally
#   make fmt        — auto-format lib/ and test/
#   make analyze    — static analysis
#   make test       — run unit tests
#   make release    — tag a new release (triggers CD pipelines)
#   make clean      — flutter clean
# ─────────────────────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help

# ── Setup ─────────────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Install git hooks from .githooks/ (run once after cloning)
	@git config core.hooksPath .githooks
	@chmod +x .githooks/pre-commit .githooks/pre-push
	@echo "✓ Git hooks installed (.githooks/ → .git/hooks)"
	@echo "  pre-commit : dart format check"
	@echo "  pre-push   : format + analyze + tests"

# ── Quality gate (mirrors CI exactly) ────────────────────────────────────────

.PHONY: check
check: fmt-check analyze test ## Run the full CI gate locally (format + analyze + test)

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files
	@echo "→ dart format --set-exit-if-changed lib test"
	@dart format --set-exit-if-changed lib test

.PHONY: fmt
fmt: ## Auto-format lib/ and test/
	@echo "→ dart format lib test"
	@dart format lib test

.PHONY: analyze
analyze: ## Run flutter analyze with fatal-infos (same as CI)
	@echo "→ flutter analyze --fatal-infos"
	@flutter analyze --fatal-infos

.PHONY: test
test: ## Run unit tests
	@echo "→ flutter test"
	@flutter test

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	@echo "→ flutter test --coverage"
	@flutter test --coverage

# ── Build ─────────────────────────────────────────────────────────────────────

.PHONY: build-apk
build-apk: ## Build debug APK
	@flutter build apk --debug

.PHONY: build-aab
build-aab: ## Build release AAB (unsigned — uses debug signing fallback)
	@echo "→ flutter build appbundle --release"
	@flutter build appbundle --release
	@echo "✓ AAB → build/app/outputs/bundle/release/app-release.aab"

.PHONY: build-ipa
build-ipa: ## Build release IPA (requires valid signing identity)
	@echo "→ flutter build ipa --release"
	@flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
	@echo "✓ IPA → build/ios/ipa/"

.PHONY: clean
clean: ## flutter clean
	@flutter clean

# ── Release ───────────────────────────────────────────────────────────────────
# Creates a signed git tag from the version in pubspec.yaml and pushes it,
# which triggers the cd-android.yml and cd-ios.yml pipelines automatically.
#
# Prerequisites: working tree must be clean and on the `main` branch.

.PHONY: release
release: check ## Tag + push a release (runs CI gate first, then triggers CD)
	@# ── Guard: must be on main ────────────────────────────────────────────
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	  if [ "$$BRANCH" != "main" ]; then \
	    echo "✗ Must be on main (currently on $$BRANCH)"; exit 1; \
	  fi
	@# ── Guard: working tree must be clean ───────────────────────────────
	@if [ -n "$$(git status --porcelain)" ]; then \
	    echo "✗ Working tree is dirty — commit or stash changes first"; exit 1; \
	  fi
	@# ── Extract version from pubspec.yaml ───────────────────────────────
	@VERSION=$$(grep '^version:' pubspec.yaml | awk '{print $$2}'); \
	  TAG="v$$VERSION"; \
	  echo ""; \
	  echo "  Creating tag: $$TAG"; \
	  echo "  Commit:       $$(git rev-parse --short HEAD)"; \
	  echo ""; \
	  read -p "  Push $$TAG to origin? [y/N] " CONFIRM; \
	  if [ "$$CONFIRM" = "y" ] || [ "$$CONFIRM" = "Y" ]; then \
	    git tag -s "$$TAG" -m "Release $$TAG" 2>/dev/null \
	      || git tag "$$TAG" -m "Release $$TAG"; \
	    git push origin "$$TAG"; \
	    echo ""; \
	    echo "✓ Tag $$TAG pushed — CD pipelines are now running."; \
	    echo "  Android: https://github.com/$$(git remote get-url origin | sed 's/.*github.com[:/]//;s/\.git$$//')/actions/workflows/cd-android.yml"; \
	    echo "  iOS:     https://github.com/$$(git remote get-url origin | sed 's/.*github.com[:/]//;s/\.git$$//')/actions/workflows/cd-ios.yml"; \
	  else \
	    echo "Aborted."; \
	  fi

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available targets
	@echo ""
	@echo "Quran Player — Makefile targets"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ \
		{ printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
