## ADDED Requirements
### Requirement: Smarthome descriptor is explicitly gated by the committed rollout

The system SHALL advertise the `smarthome` provider descriptor only when the
committed flow-6 shipping gate and camera-stream action surface are ready for
that provider family.

#### Scenario: Smarthome is still unshipped

- **GIVEN** the repository has not yet satisfied the committed flow-6 rollout
  gate for `smarthome`
- **WHEN** a shell reads the ordinary shipped provider catalog
- **THEN** the product does not advertise `smarthome` as shipped support
- **AND** archived research, presets, or test-only traces do not override that
  fail-closed state

#### Scenario: Smarthome is promoted into shipped support

- **GIVEN** the repository has satisfied the committed flow-6 rollout gate for
  `smarthome`
- **WHEN** a compatible shell reads the provider descriptor for that family
- **THEN** the host advertises a stable `smarthome` descriptor
- **AND** the descriptor exposes the committed account, device, browser, and
  input constraints for that provider family

### Requirement: Smarthome entry posture is explicit

The system SHALL keep `smarthome` account or device posture explicit in the
descriptor and fail closed when the required surface is unavailable.

#### Scenario: Smarthome requires account or device context

- **GIVEN** the committed `smarthome` flow requires authenticated account,
  device selection, or another provider-declared context
- **WHEN** a shell evaluates the `smarthome` descriptor
- **THEN** the descriptor states that committed posture explicitly
- **AND** the shell does not guess that posture from provider-name heuristics
  alone

#### Scenario: Smarthome browser posture is provider-declared

- **GIVEN** the committed `smarthome` flow requires one specific browser or
  navigation posture
- **WHEN** a shell evaluates the `smarthome` descriptor
- **THEN** the descriptor states that committed browser posture explicitly
- **AND** the shell does not silently downgrade the flow to an unsupported
  continuation surface

### Requirement: Successful smarthome resolution yields a camera-stream artifact

The system SHALL map successful `smarthome` resolution to the committed
`camera_stream` artifact family and its action surface.

#### Scenario: Smarthome resolution succeeds

- **GIVEN** a `smarthome` provider flow reaches its committed resolved state
- **WHEN** the host returns the ordinary resolution record
- **THEN** the record identifies the artifact family as `camera_stream`
- **AND** it exposes the committed camera-stream action surface such as
  `open_camera`
- **AND** it does not claim conference or tunnel semantics

#### Scenario: Smarthome resolution does not reach a committed camera result

- **GIVEN** a `smarthome` flow fails to produce the committed camera-stream
  result
- **WHEN** the host finalizes that resolution attempt
- **THEN** the attempt fails explicitly
- **AND** it does not synthesize a fake `camera_stream`, `conference_room`, or
  `generic_turn` artifact

### Requirement: Smarthome ordinary reads stay redacted and fail closed

The system SHALL keep `smarthome` stream or player secrets redacted in
ordinary reads and fail closed for blocked or incomplete provider flows.

#### Scenario: Smarthome ordinary reads remain redacted

- **GIVEN** a resolved `smarthome` artifact uses provider-owned stream,
  player, archive, or bootstrap secrets internally
- **WHEN** the host returns ordinary reads, events, or persisted shell state
- **THEN** those secret-bearing fields remain redacted
- **AND** only the non-secret camera-stream summary and action surface are
  exposed

#### Scenario: Smarthome flow is blocked or incomplete

- **GIVEN** a `smarthome` flow is blocked by provider behavior, missing device
  context, or an unsupported continuation posture
- **WHEN** the host cannot reach the committed resolved state
- **THEN** the attempt fails explicitly
- **AND** the product does not claim partial success from incomplete provider
  state alone
