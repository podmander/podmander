# packaging/

## Responsibility

`packaging/` contains the production installation assets that turn the built
Podmander binaries into a host-managed service deployment. It owns the files
installed by distribution packaging: default controller configuration, systemd
unit files, and Fedora RPM build metadata/scripts.

## Design

The directory is split by packaging concern:

- `config/` stores default runtime configuration shipped under `/etc`.
- `systemd/` stores unit files for the controller and agent daemons.
- `rpm/` stores Fedora-specific package metadata and the local RPM build helper.

The assets deliberately defer runtime behavior to platform tools. systemd owns
process lifecycle and service state directories, the RPM spec owns filesystem
placement and package scriptlets, and the Podmander binaries keep their runtime
configuration parsing inside the application.

## Flow

The RPM build helper creates a source tarball from tracked and unignored project
files, copies the RPM spec into the RPM build tree, and invokes `rpmbuild`. The
spec builds the release binaries with Alire, strips build-time RPATHs, installs
the binaries, installs `config/controller.toml` under `/etc/podmander`, and
installs both systemd units under the system unit directory. On package install,
upgrade, or removal, RPM systemd macros notify systemd about the controller and
agent units.

## Integration

Packaging integrates with the Ada build through `alr build --release` and with
the installed runtime through `/usr/bin/podmander-controller`,
`/usr/bin/podmander-agent`, and `/usr/bin/podctl`. The controller unit passes
the packaged config path to the controller binary. Both daemon units depend on
network availability and use systemd-managed state/runtime directories under
`podmander/...`, matching the default controller database path in the shipped
configuration.
