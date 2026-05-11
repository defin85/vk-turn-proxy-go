## 1. Linux packaged host boundary
- [ ] 1.1 Extend the desktop host-boundary specs so `linux_tun` uses a
      dedicated packaged host instead of the generic non-Windows fallback
- [ ] 1.2 Define a repo-owned privileged helper boundary for Linux native TUN,
      route, and DNS primitives while keeping the Flutter shell unprivileged
- [ ] 1.3 Define which execution inputs may cross into the helper and keep
      transport-profile, provider, and shell state outside that privileged
      helper

## 2. Canonical startup and failure semantics
- [ ] 2.1 Extend the canonical desktop startup contract so helper privilege
      denial remains a typed control-plane failure rather than a second helper
      API
- [ ] 2.2 Define helper lifecycle and cleanup rules so partial Linux-native
      state is torn down on host or helper failure
- [ ] 2.3 Keep `linux_tun` support fail-closed in this change until later
      ready-path and packaging changes land

## 3. Validation
- [ ] 3.1 Run `openspec validate add-83-flow-10-linux-tun-host-boundary --strict --no-interactive`
