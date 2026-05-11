## 1. Packaging and install surface
- [ ] 1.1 Define the first repo-owned Ubuntu install/package entrypoint for
      RelayDock `linux_tun`
- [ ] 1.2 Define how the desktop bundle, Linux helper, and privilege-mediation
      metadata are staged together
- [ ] 1.3 Keep unsupported Linux targets fail-closed until they gain their own
      documented package/install path

## 2. Support promotion
- [ ] 2.1 Promote `linux_tun` runtime-execution support only for the documented
      packaged Ubuntu target
- [ ] 2.2 Promote desktop-shell affordances only when the packaged host reports
      that supported Linux target honestly
- [ ] 2.3 Define the verification/runbook bar required before Linux support is
      considered shipped

## 3. Validation
- [ ] 3.1 Run `openspec validate add-85-flow-10-linux-tun-packaging-support-promotion --strict --no-interactive`
