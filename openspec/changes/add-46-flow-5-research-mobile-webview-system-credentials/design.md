## Context

The current mobile owned-browser contract already supports app-owned browser
state inside the embedded `WebView` sandbox and intentionally keeps that state
separate from the user's external browser profile. That shipped behavior is the
right boundary for `add-32`, but it does not answer a different product
question:

- should the app intentionally integrate with Android system credential
  providers inside the embedded `WebView`
- and if so, under what trust, platform, and provider constraints

The Android platform now documents an explicit `Credential Manager + WebView`
path. That path is not equivalent to ambient autofill hints that may appear
over a normal login form, and it is not equivalent to our current app-owned
cookie/session reuse.

This change exists so the product can evaluate that path explicitly instead of
accidentally inheriting system-credential behavior from whatever a password
manager or `WebView` implementation happens to do today.

## Goals / Non-Goals

- Goals:
  - Define intentional Android system credential integration as a separate
    capability from app-owned embedded sign-in memory.
  - Keep current owned-browser claims honest when Android system credential
    support is absent, partial, or only ambient.
  - Document the prerequisite boundary for explicit support.
  - Keep reset and ownership boundaries explicit between app-owned browser
    state and provider-held credentials.
- Non-Goals:
  - Do not silently upgrade current owned-browser flows into system credential
    support.
  - Do not treat incidental autofill suggestions as reviewed product support.
  - Do not promise iOS parity in this slice.
  - Do not assume the current target provider already exposes the required web
    credential APIs or trust associations.

## Decisions

### Decision: Separate system credentials from app-owned browser memory

The product must keep these as distinct concepts:

- app-owned embedded browser session memory
- incidental Android autofill or password-manager hints
- intentional Android system credential integration

`add-32` only covers the first item. This change is about the third item. The
second remains incidental OS behavior until the product explicitly promotes it
into a reviewed capability.

### Decision: Android-first support is explicit and optional

The first slice is Android-only because the current authoritative platform
guidance and native integration path are Android-specific. The product should
not describe this as cross-platform mobile support until a reviewed iOS path
exists.

Even on Android, the capability remains optional and provider-gated. Ordinary
owned-browser continuation support must keep working without it.

### Decision: Intentional integration follows the documented Credential Manager + WebView path

The intentional path should align with the documented Android model rather than
inventing password scraping or heuristic form interception. That means the
design must account for:

- explicit `Credential Manager` support
- `WebView` feature support needed for app-mediated web authentication
- documented app-to-site trust binding such as Digital Asset Links
- relying-party web support for the relevant credential APIs and native/web
  message flow

If those prerequisites are absent, the product must fail closed for explicit
system credential integration instead of pretending that ambient hints provide
the same guarantee.

### Decision: Ambient autofill stays non-contractual by default

Android autofill services or password managers may surface suggestions inside a
`WebView` form even when the product has not implemented explicit system
credential support. That behavior is too provider-, device-, and service-
dependent to treat as the intentional contract.

The shell may later choose to suppress or de-emphasize ambient suggestions for
specific owned-browser flows, but this change does not assume that those hints
are either guaranteed or forbidden. It only states that they do not define the
official capability boundary.

### Decision: Reset boundaries remain split

The mobile shell already has an explicit reset path for app-owned embedded
browser state. That reset must remain scoped to app-owned cookies, storage, and
other embedded browser artifacts.

If a future flow uses Android credential providers intentionally, clearing the
embedded browser session must not claim to delete passwords, passkeys, or other
provider-held credentials. Those belong to the system credential provider
boundary, not the shell.

### Decision: Real-provider enablement requires evidence, not optimism

Before the product enables intentional system credential integration for a real
provider flow, it needs concrete evidence for that relying party:

- web capability proof that the flow exposes the required credential APIs or
  supported interaction model
- trust proof that the app and site satisfy the required association boundary
- native Android proof that the `WebView` and `Credential Manager` path works
  on the target device class
- UX proof that the resulting prompt and fallback behavior are understandable
  and fail closed

Without that evidence, the product should keep the capability in proposal or
research state.

## Risks / Trade-offs

- The official Android path may be technically correct but irrelevant to a
  provider whose web login does not use the required credential APIs.
  Mitigation: require provider-specific evidence before enablement.
- Ambient autofill can confuse operators into thinking explicit support already
  exists.
  Mitigation: keep the capability boundary documented and fail closed for
  unsupported flows.
- Mixing app-owned sign-in reset with provider-held system credentials can lead
  to false security expectations.
  Mitigation: keep ownership and reset semantics explicit in both spec and UI.
- Android-first support can create future parity pressure from iOS.
  Mitigation: call out Android-only scope now instead of implying mobile-wide
  support.

## Open Questions

- Does the current target provider expose the web credential surfaces required
  by the documented Android integration path, or would it still rely only on
  ambient form autofill?
- Should explicit system credential support be expressed in typed challenge
  metadata, in a mobile-runtime policy gate, or in both?
- Does the product want to suppress ambient autofill in flows where intentional
  support is not yet approved?
