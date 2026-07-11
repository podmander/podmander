%undefine _annotated_build
%global debug_package %{nil}

Name:           podmander
Version:        0.2.4
Release:        1%{?dist}
Summary:        Container orchestration for small multi-node deployments

License:        Apache-2.0
URL:            https://code.monospacementor.com/podmander/podmander
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  alire
BuildRequires:  chrpath
BuildRequires:  systemd-rpm-macros
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd
Requires:       podman

%description
Podmander generates configuration for specialized tools such as systemd,
Podman, Caddy, and Restic to orchestrate small multi-node deployments.

%prep
%autosetup

%build
alr build --release

%install
install -Dpm0755 bin/podmander-controller %{buildroot}%{_bindir}/podmander-controller
install -Dpm0755 bin/podmander-agent %{buildroot}%{_bindir}/podmander-agent
install -Dpm0755 bin/podctl %{buildroot}%{_bindir}/podctl

chrpath -d %{buildroot}%{_bindir}/podmander-controller
chrpath -d %{buildroot}%{_bindir}/podmander-agent
chrpath -d %{buildroot}%{_bindir}/podctl

install -Dpm0644 packaging/config/controller.toml %{buildroot}%{_sysconfdir}/podmander/controller.toml
install -Dpm0644 packaging/systemd/podmander-controller.service %{buildroot}%{_unitdir}/podmander-controller.service
install -Dpm0644 packaging/systemd/podmander-agent.service %{buildroot}%{_unitdir}/podmander-agent.service

%post
%systemd_post podmander-controller.service podmander-agent.service

%preun
%systemd_preun podmander-controller.service podmander-agent.service

%postun
%systemd_postun_with_restart podmander-controller.service podmander-agent.service

%files
%license LICENSE
%doc README.md examples/agent.toml
%{_bindir}/podmander-controller
%{_bindir}/podmander-agent
%{_bindir}/podctl
%dir %{_sysconfdir}/podmander
%config(noreplace) %{_sysconfdir}/podmander/controller.toml
%{_unitdir}/podmander-controller.service
%{_unitdir}/podmander-agent.service

%changelog
* Sat Jul 11 2026 Jochen Lillich <contact@geewiz.dev> - 0.2.4-1
- Return clear config parser errors for malformed TOML value shapes.

* Sat Jul 11 2026 Jochen Lillich <contact@geewiz.dev> - 0.2.3-1
- Consolidate agent repository timestamp conversion helpers.

* Sat Jul 11 2026 Jochen Lillich <contact@geewiz.dev> - 0.2.2-1
- Remove unnecessary mutating parameter modes.

* Sat Jul 11 2026 Jochen Lillich <contact@geewiz.dev> - 0.2.1-1
- Make handler owner references non-null.

* Tue Jun 30 2026 Jochen Lillich <contact@geewiz.dev> - 0.2.0-1
- Add initial local Fedora RPM packaging.
