# packaging/rpm/

## Responsibility

`packaging/rpm/` contains Fedora RPM packaging for Podmander. It defines how to
build, install, register, and locally produce binary/source RPMs for the
controller, agent, and CLI binaries plus their production packaging assets.

## Design

The RPM spec is the authoritative install manifest. It disables annotated builds
and separate debug packages, declares the Podmander package metadata, requires
the build/runtime tools needed by the packaged deployment, and uses systemd RPM
macros for lifecycle integration. Installation is explicit: each binary, config
file, and unit file is installed with `install -D` and listed in `%files`.

`build-rpm.sh` is a local convenience wrapper around `rpmbuild`. It preflights
the commands needed for a local build, derives the package version from
`alire.toml`, constructs an RPM topdir under `build/rpm`, packages the git file
set into the expected source tarball shape, and invokes `rpmbuild --nodeps` so
local builds can use the developer's installed `alr` even though Fedora does not
ship Alire.

## Flow

For local RPM creation, `build-rpm.sh` validates `git`, `rpmbuild`, `alr`,
`chrpath`, and `tar`; asks git for the repository root; reads the version from
`alire.toml`; creates `build/rpm/{BUILD,RPMS,SOURCES,SPECS,SRPMS}`; archives all
tracked and unignored files except `build/**`; copies `podmander.spec`; then
runs `rpmbuild`.

Inside the RPM build, `%build` runs `alr build --release`. `%install` copies the
three binaries to `%{_bindir}`, removes their RPATHs with `chrpath -d`, installs
the controller config to `%{_sysconfdir}/podmander/controller.toml`, and
installs the controller and agent units to `%{_unitdir}`. `%post`, `%preun`, and
`%postun` delegate unit registration/restart behavior to standard systemd RPM
macros.

## Integration

The spec integrates with the project build via Alire and with runtime service
management via `packaging/systemd/*.service`. It installs
`packaging/config/controller.toml` as `%config(noreplace)` so operator edits are
preserved. Runtime dependencies include Podman for container execution, while
the installed files expose `/usr/bin/podmander-controller`,
`/usr/bin/podmander-agent`, and `/usr/bin/podctl` to the host.
