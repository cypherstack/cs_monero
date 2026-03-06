# Unified entry point for Guix-based cs_monero development.
#
# Quick start:
#   make -C guix setup          # fetch Flutter SDK + pin Guix channels
#   make -C guix shell          # enter dev shell with all deps
#   make -C guix monero-c       # build monero_c native libs (reproducible)
#   make -C guix app            # build example Flutter app (reproducible)

.PHONY: setup shell shell-pinned monero-c monero-c-fast app app-fast pin clean help

# Fetch Flutter SDK + pin Guix channels (first-time setup).
setup:
	./pin-channels.sh
	./scripts/fetch-flutter.sh

# Interactive dev shell (uses latest local Guix).
shell:
	./scripts/shell-linux.sh

# Interactive dev shell (fully pinned — reproducible).
shell-pinned:
	./scripts/shell-linux.sh --pinned

# Build monero_c native libs (fully pinned — reproducible).
monero-c:
	./scripts/build-monero-c.sh --pinned

# Build monero_c with latest local Guix (faster, less reproducible).
monero-c-fast:
	./scripts/build-monero-c.sh

# Build example Flutter app (fully pinned — reproducible).
app:
	./scripts/build-app.sh --pinned

# Build with latest local Guix (faster, less reproducible).
app-fast:
	./scripts/build-app.sh

# Full reproducible build: native libs + example app.
all: monero-c app

# Re-pin Guix channels to current versions.
pin:
	./pin-channels.sh

# Remove fetched Flutter SDK and build artifacts.
clean:
	rm -rf ../.flutter-sdk
	rm -rf ../build
	rm -rf ../built_outputs

help:
	@echo "cs_monero Guix build targets:"
	@echo ""
	@echo "  setup          Fetch Flutter SDK + pin Guix channels"
	@echo "  shell          Interactive dev shell (latest Guix)"
	@echo "  shell-pinned   Interactive dev shell (pinned, reproducible)"
	@echo "  monero-c       Build monero_c native libs (pinned)"
	@echo "  monero-c-fast  Build monero_c native libs (latest Guix)"
	@echo "  app            Build example Flutter app (pinned)"
	@echo "  app-fast       Build example Flutter app (latest Guix)"
	@echo "  all            Full reproducible build (monero-c + app)"
	@echo "  pin            Re-pin Guix channels"
	@echo "  clean          Remove SDK + build artifacts"
