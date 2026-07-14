# src/shared/

## Responsibility

Shared runtime utilities used by multiple Podmander deliverables. This folder
keeps cross-cutting process concerns out of the protocol, config, controller,
agent, and CLI packages: command-line option lookup, log emission, runtime
configuration helpers, and Join Token enrollment support.

## Design

- `Podmander.Args` is intentionally minimal: it scans `Ada.Command_Line` for
  `--key=value` and `--key value` forms and leaves command semantics to callers.
- `Podmander.Logging` centralizes log filtering and formatting behind a
  `Log_Level` enum. Output goes to terminal-friendly labelled lines when stdout
  is a TTY and to syslog-priority-prefixed lines otherwise.
- `Podmander.Runtime_Config_Helpers` contains small adapters for executable
  startup: parsing textual log levels and resolving `--config` while tracking
  whether the path was explicit or defaulted.
- `Podmander.Enrollment` owns Join Token mechanics. It models controller-side
  enrollment state as an `Enrollment_Config`, generates a secret through
  `getrandom(2)`, renders tokens as `PTKN-<controller-z85-pubkey>-<hex-secret>`,
  and parses that shape back into public key and secret fields.

## Flow

- Executables ask `Args` or `Runtime_Config_Helpers` for startup values, then
  configure `Logging` before doing domain work.
- Controller enrollment code ensures an enrollment secret exists, combines it
  with the controller CURVE public key to produce a Join Token, and later checks
  incoming enrollment secrets with `Secret_Matches`.
- Agent startup parses the operator-provided Join Token to recover the
  controller public key and enrollment secret before sending registration
  protocol messages.
- Invalid duration arguments fall back to defaults with a warning; malformed
  Join Tokens raise `Parse_Error`; CSPRNG failures raise `CSPRNG_Error` rather
  than using a weaker random source.

## Integration

- Used by controller, agent, and CLI startup paths rather than by a single
  domain subsystem.
- Enrollment supports the protocol registration path: Join Token data becomes
  the `Enrollment_Secret` sent in registration and Stack_Submission-related
  messages, while controller-side state validates that secret.
- Logging is the common diagnostic surface for shared code and callers; `Args`
  depends on it for invalid duration warnings and usage output.
- Runtime configuration helpers bridge process arguments into higher-level
  runtime config loading without depending on config-file parsing internals.
