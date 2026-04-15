Name:           hyprlock
Version:        0.9.4
Release:        %autorelease -b1
Summary:        Hyprland's GPU-accelerated screen locking utility
# hyprlock: BSD-3-Clause
# protocols/wlr-screencopy-unstable-v1.xml: MIT
License:        BSD-3-Clause AND MIT
URL:            https://github.com/hyprwm/hyprlock
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        hyprlock.1

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++

BuildRequires:  cmake(hyprwayland-scanner)
BuildRequires:  pkgconfig(cairo)
BuildRequires:  pkgconfig(egl)
BuildRequires:  pkgconfig(gbm)
BuildRequires:  pkgconfig(hyprgraphics)
BuildRequires:  pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  pkgconfig(opengl)
BuildRequires:  pkgconfig(pam)
BuildRequires:  pkgconfig(pangocairo)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-egl)
BuildRequires:  pkgconfig(wayland-protocols)
BuildRequires:  pkgconfig(sdbus-c++)
BuildRequires:  pkgconfig(xkbcommon)

%description
Hyprland's simple, yet multi-threaded and GPU-accelerated screen locking
utility. It provides visual features including blurred screenshot backgrounds,
gradient borders, animations, and shadows. Supports the ext-session-lock
protocol, fractional scaling, and native fingerprint authentication through
libfprint.

%prep
%autosetup -p1

%build
%cmake -DCMAKE_BUILD_TYPE=Release
%cmake_build

%install
%cmake_install
rm %{buildroot}%{_datadir}/hypr/%{name}.conf
install -Dpm644 %{SOURCE1} -t %{buildroot}%{_mandir}/man1

%files
%license LICENSE
%doc README.md assets/example.conf
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1*
%config(noreplace) %{_sysconfdir}/pam.d/%{name}

%changelog
%autochangelog
