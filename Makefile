.DEFAULT_GOAL := ci

ACT_WORKFLOW ?= .github/workflows/ci.yml
ACT_JOB ?= test

.PHONY: ci codex-onboard codex-onboard-workflow verify-docs build-go build-gui-linux package-gui-linux-deb build-gui-windows build-gui-android build-gui-android-play-release verify-gui-android-play-release-local-delivery build-gui-android-windows-mirror smoke-android-embedded-host smoke-android-vpn-service wg-e2e-check wg-e2e wg-live-vk-check wg-live-vk-run wg-live-vk-start wg-live-vk-continue wg-live-vk-cleanup android-phone-check android-phone-status android-phone-start android-phone-stop android-phone-diagnostics sync-version-assets check-version-assets sync-publish-identity check-publish-identity ci-act ci-act-dry ci-act-verbose deps-act

ci:
	python3 ./scripts/verify-agent-docs.py
	./scripts/sync-publish-identity.py --check
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

build-gui-linux:
	bash ./scripts/build-linux-gui-package.sh

package-gui-linux-deb:
	bash ./scripts/package-linux-gui-deb.sh

build-gui-windows:
	./scripts/build-windows-gui-from-wsl.sh

build-gui-android:
	bash ./scripts/build-android-gui-linux.sh

build-gui-android-play-release:
	bash ./scripts/build-android-play-release-linux.sh

verify-gui-android-play-release-local-delivery:
	bash ./scripts/verify-android-play-release-local-delivery.sh

build-gui-android-windows-mirror:
	bash ./scripts/build-android-gui-from-wsl.sh

smoke-android-embedded-host:
	bash ./scripts/smoke-android-embedded-host.sh

smoke-android-vpn-service:
	python3 ./scripts/smoke-android-vpn-service.py

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

sync-publish-identity:
	./scripts/sync-publish-identity.py

check-publish-identity:
	./scripts/sync-publish-identity.py --check

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
