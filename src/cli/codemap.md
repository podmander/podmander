# src/cli/

## Responsibility

`src/cli/` implements the production packages behind the `podctl` CLI. Its job
is to keep `podctl` a lean operator-facing client: parse subcommands and global
options, load connection credentials, perform client-side liveness checks on
input files, send a `Stack_Submission` to the Controller, and format the
Controller's `Stack_Submission_Result` for the terminal.

The folder does not own authoritative Stack TOML parsing or validation. For
`podctl deploy`, it submits raw Stack TOML and an enrollment secret to the
Controller, then reports whether the Stack Submission was accepted or rejected.
It also does not report eventual deployment outcome; deployment is asynchronous
after the Controller accepts, registers, and schedules the submission.

## Design

- `Podmander.Podctl` is the root namespace package for CLI code.
- `Podmander.Podctl.Commands` wires the CLIC subcommand framework for the
  `podctl` executable. It defines global switches (`--controller=`, `--token=`)
  as shared CLIC-populated string access values and instantiates the command
  dispatcher with `podctl` metadata and output/error hooks.
- `Podmander.Podctl.Commands.Deploy` is the CLIC command object for
  `podctl deploy`. It owns command metadata, usage shape (`<path>`), argument
  presence checks, config loading, outcome-to-output formatting, and process
  exit behavior.
- `Podmander.Podctl.Config` centralizes connection configuration. A
  discriminated `Load_Result` returns either a `Connection_Config` or an error
  message. The default Controller endpoint is `tcp://localhost:5555`; config is
  read from `~/.config/podmander/podctl.toml` unless a path is supplied, and
  command-line overrides win over file values. A token is required.
- `Podmander.Podctl.Deploy` contains deploy submission logic independent of the
  CLIC command object. It exposes `Deploy_Outcome`, `Deploy_Result`,
  `Check_TOML_File`, and `Exit_Code_For`, keeping domain behavior testable
  without terminal process control.
- `Podmander.Podctl.Connection` wraps the ZeroMQ/CURVE Controller connection in
  a limited `Controller_Connection`, hiding certificate/socket management and
  providing `Open`, `Send`, `Receive`, and `Close` operations.

## Flow

`podctl` command parsing/config/deploy request flow:

1. The CLIC dispatcher created in `Podmander.Podctl.Commands.Instance` parses
   the `podctl` command line. Global switches populate `Controller_Value` and
   `Token_Value`.
2. For `podctl deploy <path>`, `Podmander.Podctl.Commands.Deploy.Execute`
   verifies that a path argument was provided. Missing input is reported to
   stderr and exits with status 1.
3. `Execute` calls `Podmander.Podctl.Config.Load`, passing any global switch
   overrides. Config loading starts from the default Controller endpoint, reads
   optional TOML keys `controller` and `token`, applies flag overrides, and
   fails if no token is available.
4. On successful config load, `Execute` calls `Podmander.Podctl.Deploy.Submit`
   with the Stack TOML path and connection config.
5. `Submit` parses the join token with `Podmander.Enrollment.Parse_Join_Token`.
   A malformed token becomes `Token_Error`.
6. `Submit` checks the Stack TOML file before networking. Missing/unopenable or
   empty files become `File_Error`; valid files are read as raw TOML text.
7. `Submit` opens a CURVE DEALER connection to the Controller through
   `Podmander.Podctl.Connection.Open`, using the Controller address from config
   and the server public key embedded in the join token. The socket identity is
   `podctl`, and receives time out after 5 seconds.
8. `Submit` sends a `Stack_Submission` containing the raw TOML and enrollment
   secret. The Controller is responsible for authorization, parsing,
   validation, registration, and scheduling.
9. `Submit` waits for a reply. A timeout yields `Timeout`; a decoded
   `Stack_Submission_Result` maps `Success = True` to `Accepted` and
   `Success = False` to `Rejected`; malformed or unexpected replies become
   `Rejected` with an explanatory message. The connection is closed before the
   result returns.
10. `Execute` prints accepted messages to stdout. Non-accepted outcomes are
    printed to stderr prefixed with `Error:` and converted to process exit codes
    by `Exit_Code_For` (`Token_Error` 1, `File_Error` 2, `Timeout` 3,
    `Rejected` 4).

## Integration

- Depends on CLIC for command parsing, help text, and dispatch.
- Depends on TOML file I/O for optional `podctl` connection configuration.
- Depends on `Podmander.Enrollment` to parse the join token and derive the
  Controller CURVE public key plus enrollment secret.
- Depends on `Podmander.Messages`, `Podmander.Messages.Stack_Submissions`, and
  `Podmander.Messages.Stack_Submission_Results` for protocol encoding/decoding
  of `Stack_Submission` and `Stack_Submission_Result`.
- Depends on CZMQ Ada bindings for DEALER sockets, certificates, message send,
  receive, CURVE server key setup, and receive timeout handling.
- Consumes the Controller request/reply endpoint. The Controller is the
  authoritative consumer of `Stack_Submission` and producer of
  `Stack_Submission_Result`; downstream scheduling and agent deployment are
  outside this folder.
- Provides reusable CLI-layer seams consumed by command objects and tests:
  config loading, Stack TOML liveness checks, deploy submission outcomes, exit
  code mapping, and Controller connection operations.
