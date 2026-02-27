Name:           hypridle
Version:        0.1.7
Release:        %autorelease -b4
Summary:        Hyprland's idle daemon
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hypridle
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        hypridle.1

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  systemd-rpm-macros

BuildRequires:  cmake(hyprwayland-scanner)
BuildRequires:  pkgconfig(hyprland-protocols)
BuildRequires:  pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(sdbus-c++)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-protocols)

%description
Hyprland's idle daemon, based on the ext-idle-notify-v1 Wayland protocol.
It supports D-Bus loginctl commands (lock, unlock, before-sleep) and D-Bus
inhibit (used by e.g. Firefox and Steam). Users can configure timeout-based
actions through listeners that execute commands when the system becomes idle
and when activity resumes.

%prep
%autosetup -p1

%build
%cmake
%cmake_build

%install
%cmake_install
rm %{buildroot}%{_datadir}/hypr/hypridle.conf
install -Dpm644 %{SOURCE1} -t %{buildroot}%{_mandir}/man1

%files
%license LICENSE
%doc README.md assets/example.conf
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1*
%{_userunitdir}/%{name}.service

%post
%systemd_user_post %{name}.service

%preun
%systemd_user_preun %{name}.service

%postun
%systemd_user_postun %{name}.service

%changelog
%autochangelog
