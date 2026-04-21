## 1. Contract updates
- [ ] 1.1 Extend `runtime-execution-planning` so packaged system-tunnel support
      claims are explicit about IPv4-only versus dual-stack coverage
- [ ] 1.2 Extend `platform-tunnel-integration` so startup validates
      address-family coverage and fails closed when dual-stack prerequisites are
      incomplete
- [ ] 1.3 Extend `client-control-plane` so shells receive typed
      address-family coverage metadata instead of inferring full-tunnel support
      from `ready=true`
- [ ] 1.4 Extend `wireguard-turn-carrier` so dual-stack support claims require a
      host-owned, family-complete strict WireGuard execution lease

## 2. Host and carrier implementation
- [ ] 2.1 Implement dual-stack-aware strict WireGuard materialization for the
      packaged system-tunnel path without leaking raw carrier secrets
- [ ] 2.2 Implement family-aware route preparation and exclusion handling for
      packaged Android and desktop system-tunnel hosts
- [ ] 2.3 Keep IPv4-only hosts and builds explicit as limited or unavailable
      instead of treating them as complete dual-stack support

## 3. Evidence and documentation
- [ ] 3.1 Add fail-closed test coverage for dual-stack underlays with missing
      IPv6 route preparation or exclusion handling
- [ ] 3.2 Add evidence that distinguishes IPv4-only readiness from verified
      dual-stack egress coverage
- [ ] 3.3 Update operator-facing runbooks to state whether a packaged
      system-tunnel path is IPv4-only or dual-stack-capable

## 4. Validation
- [ ] 4.1 Run
      `openspec validate add-47-flow-5-research-ipv6-aware-system-tunnel-path --strict --no-interactive`
