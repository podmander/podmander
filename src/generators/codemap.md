# src/generators/

## Responsibility

Derived artifact generation. Production code here turns Podmander's Abstract
Service Definition representation into Podman Quadlet output, currently a
`.container` unit string or file.

## Design

- `Podmander.Generators` is a pure namespace package for generator families.
- `Podmander.Generators.Quadlet` is the concrete generator for Podman Quadlets.
  Its public API is deliberately small: `Render` for pure string generation and
  `Write_File` for filesystem output.
- The generator consumes `Podmander.Config.Service_Definition` directly. That
  type is the current in-code Abstract Service Definition: service name, image,
  environment, ports, volumes, optional description, and install target.
- Rendering builds an unbounded string section by section. Required values become
  `[Container]` fields; optional values are omitted or defaulted rather than
  represented as empty Quadlet directives.

## Flow

- A parsed and validated `Service_Definition` enters `Render`.
- If present, `Description` creates a `[Unit]` section. `[Container]` is always
  emitted with `Image`, followed by one `Environment`, `PublishPort`, and
  `Volume` line per configured entry.
- `[Install]` is always emitted. `WantedBy` comes from the service definition
  when set, otherwise it defaults to `multi-user.target`.
- `Write_File` calls `Render`, creates the output directory, and writes
  `<service-name>.container` containing the Quadlet text.

## Integration

- Upstream input comes from `src/config`, where TOML is parsed into the Abstract
  Service Definition record.
- Controller-side deployment planning can render the Quadlet text and place it
  into a Deployment_Command for delivery to an agent.
- Agent-side execution treats Quadlet as the OS boundary: after a
  Deployment_Command is handled, the rendered `.container` content is what
  systemd and Podman interpret, not a Podmander-owned runtime format.
