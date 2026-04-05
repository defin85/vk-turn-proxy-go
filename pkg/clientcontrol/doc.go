// Package clientcontrol exposes the versioned local client control plane used by
// desktop sidecars and embedded mobile hosts.
//
// The semantic contract is shared across both hosting models:
//   - desktop shells talk to a local-only HTTP daemon such as cmd/clientd
//   - mobile shells embed Host directly through Go bindings
//
// Both modes share the same version negotiation, profile/session/challenge
// resources, typed event stream, and diagnostics export.
package clientcontrol
