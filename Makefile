.DEFAULT_GOAL := ci

ACT_WORKFLOW ?= .github/workflows/ci.yml
ACT_JOB ?= test

.PHONY: ci codex-onboard codex-onboard-workflow verify-docs build-go build-gui-windows build-gui-android smoke-android-embedded-host wg-e2e-check wg-e2e wg-live-vk-check wg-live-vk-run wg-live-vk-start wg-live-vk-continue wg-live-vk-cleanup android-phone-check android-phone-status android-phone-start android-phone-stop android-phone-diagnostics sync-version-assets check-version-assets ci-act ci-act-dry ci-act-verbose deps-act

ci:
	python3 ./scripts/verify-agent-docs.py
	./scripts/sync-version-assets.py --check
	go test ./...
	go build ./...

codex-onboard:
	bash ./scripts/codex-onboard.sh

codex-onboard-workflow:
	bash ./scripts/codex-onboard.sh --workflow

verify-docs:
	python3 ./scripts/verify-agent-docs.py

build-go:
	./scripts/build-go-matrix.sh

build-gui-windows:
	./scripts/build-windows-gui-from-wsl.sh

build-gui-android:
	bash ./scripts/build-android-gui-from-wsl.sh

smoke-android-embedded-host:
	bash ./scripts/smoke-android-embedded-host.sh

wg-e2e-check:
	bash ./scripts/e2e-wg-over-transport.sh --check-only

wg-e2e:
	bash ./scripts/e2e-wg-over-transport.sh

wg-live-vk-check:
	bash ./scripts/e2e-wg-live-vk.sh check

wg-live-vk-run:
	bash ./scripts/e2e-wg-live-vk.sh run

wg-live-vk-start:
	bash ./scripts/e2e-wg-live-vk.sh start

wg-live-vk-continue:
	bash ./scripts/e2e-wg-live-vk.sh continue

wg-live-vk-cleanup:
	bash ./scripts/e2e-wg-live-vk.sh cleanup

android-phone-check:
	python3 ./scripts/android-phone-session.py check

android-phone-status:
	python3 ./scripts/android-phone-session.py status

android-phone-start:
	python3 ./scripts/android-phone-session.py start --replace-existing

android-phone-stop:
	python3 ./scripts/android-phone-session.py stop --session-id latest

android-phone-diagnostics:
	python3 ./scripts/android-phone-session.py diagnostics --session-id latest

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
