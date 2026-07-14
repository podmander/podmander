# packaging/systemd/

## Responsibility

`packaging/systemd/` contains the system service definitions installed by the
RPM package. These units make the Controller and Agent host-managed daemons and
define the filesystem directories systemd creates for their persistent and
runtime state.

## Design

The units keep process management in systemd rather than in Podmander code:

- `podmander-controller.service` runs `/usr/bin/podmander-controller --config
  /etc/podmander/controller.toml`, binding the packaged controller config to
  the daemon process.
- `podmander-agent.service` runs `/usr/bin/podmander-agent` with application
  defaults or operator-provided environment/service overrides.
- Both units are simple long-running services, wait for `network-online.target`,
  restart on failure, and install into `multi-user.target`.
- `StateDirectory=` and `RuntimeDirectory=` delegate directory creation,
  ownership, and cleanup semantics to systemd.

## Flow

During package installation, RPM installs these files under the system unit
directory and invokes standard systemd macros to reload unit metadata. When the
operator enables or starts a unit, systemd creates the declared state/runtime
directories, starts the binary, and restarts it after failures according to the
unit policy. The controller unit passes the packaged TOML path to the
application, so controller runtime config enters through `/etc/podmander` before
the Controller opens its database and control-channel bind socket.

## Integration

- Installed by `packaging/rpm/podmander.spec` alongside the Podmander binaries
  and packaged controller config.
- The controller unit's `StateDirectory=podmander/controller` aligns with the
  default database path in `packaging/config/controller.toml`.
- The services expose the production daemon entry points built from `src/bin/`
  and keep lifecycle concerns outside the Controller and Agent packages.
