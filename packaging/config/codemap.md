# packaging/config/

## Responsibility

`packaging/config/` contains production default configuration files installed by
packages. Currently it ships the controller's default TOML runtime config.

## Design

The configuration is intentionally minimal and host-oriented. It defines only
the controller settings needed for a packaged service to start predictably:

- `bind = "tcp://*:5555"` exposes the controller on the default CZMQ endpoint.
- `db_path = "/var/lib/podmander/controller/podmander.db"` stores durable
  controller state in the systemd `StateDirectory` created for the service.
- `log_level = "info"` provides a production default without enabling verbose
  diagnostics.

Package metadata installs this file as `%config(noreplace)`, so local operator
changes survive package upgrades.

## Flow

During RPM installation, `controller.toml` is copied to
`/etc/podmander/controller.toml`. At service start, the controller systemd unit
executes `podmander-controller --config /etc/podmander/controller.toml`, causing
the application to read these packaged defaults before opening its network bind
address and database.

## Integration

The config file is referenced directly by `packaging/rpm/podmander.spec` and by
`packaging/systemd/podmander-controller.service`. Its database path aligns with
the controller unit's `StateDirectory=podmander/controller`, which systemd maps
to `/var/lib/podmander/controller` on Fedora-style systems.
