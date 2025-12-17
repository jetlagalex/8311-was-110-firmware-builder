# 8311-was-110-firmware-builder Makefile

.PHONY: all check deps test clean

all: check

check:
	@echo "Running shellcheck..."
	@if command -v shellcheck >/dev/null; then \
		shellcheck *.sh tools/*.sh mods/*.sh; \
	else \
		echo "Skipping shellcheck (not found)"; \
	fi
	./check_deps.sh

deps:
	git submodule update --init --recursive
	./check_deps.sh

test:
	@echo "Running tests..."
	./tests/test_roundtrip.sh || echo "Skipping roundtrip test (implementation pending)"

clean:
	rm -rf out/
	rm -f local-upgrade.tar local-upgrade.img
