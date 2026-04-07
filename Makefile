.DEFAULT_GOAL := ci

ACT_WORKFLOW ?= .github/workflows/ci.yml
ACT_JOB ?= test

.PHONY: ci build-go build-gui-windows sync-version-assets check-version-assets ci-act ci-act-dry ci-act-verbose deps-act

ci:
	./scripts/sync-version-assets.py --check
	go test ./...
	go build ./...

build-go:
	./scripts/build-go-matrix.sh

build-gui-windows:
	./scripts/build-windows-gui-from-wsl.sh

sync-version-assets:
	./scripts/sync-version-assets.py

check-version-assets:
	./scripts/sync-version-assets.py --check

ci-act: deps-act
	act -j $(ACT_JOB) -W $(ACT_WORKFLOW)

ci-act-dry: deps-act
	act -n -j $(ACT_JOB) -W $(ACT_WORKFLOW)

ci-act-verbose: deps-act
	act --verbose -j $(ACT_JOB) -W $(ACT_WORKFLOW)

deps-act:
	@command -v act >/dev/null 2>&1 || { echo "act is required; install it first."; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "docker is required for act."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "docker daemon is not available."; exit 1; }
