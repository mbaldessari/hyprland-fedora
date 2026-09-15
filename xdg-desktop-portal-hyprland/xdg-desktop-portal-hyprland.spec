Name:           xdg-desktop-portal-hyprland
Epoch:          1
Version:        1.4.1
Release:        %autorelease -b7
Summary:        XDG Desktop Portal backend for Hyprland

# xdg-desktop-portal-hyprland: BSD-3-Clause
# protocols/wlr-foreign-toplevel-management-unstable-v1.xml: HPND-sell-variant
# protocols/wlr-screencopy-unstable-v1.xml: MIT
License:        BSD-3-Clause AND HPND-sell-variant AND MIT
URL:            https://github.com/hyprwm/xdg-desktop-portal-hyprland
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        hyprland-share-picker.1
Patch0:         0001-feat-add-wlr-data-control-protocol-binding-and-wl_se.patch
Patch1:         0002-feat-upgrade-InputCapture-portal-to-version-2.patch
Patch3:         0003-feat-implement-org.freedesktop.impl.portal.Clipboard.patch
Patch4:         0004-Fix-paste-deadlock.patch
Patch5:         0005-Fix-sigpipe.patch
Patch6:         0006-fix-fd.patch

BuildRequires:  meson
BuildRequires:  gcc-c++
BuildRequires:  systemd-rpm-macros

BuildRequires:  pkgconfig(gbm)
BuildRequires:  pkgconfig(hyprland-protocols)
BuildRequires:  pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(hyprwayland-scanner)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(libpipewire-0.3)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  pkgconfig(Qt6Widgets)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(sdbus-c++)
BuildRequires:  pkgconfig(uuid)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-protocols)
BuildRequires:  pkgconfig(wayland-scanner)

Requires:       dbus
# required for Screenshot portal implementation
Requires:       grim
Recommends:     hyprpicker
Requires:       xdg-desktop-portal
# required for hyprland-share-picker
Requires:       slurp
Requires:       qt6-qtwayland

Enhances:       hyprland
Supplements:    hyprland
Supplements:    hyprland-git

%description
An XDG Desktop Portal backend for Hyprland. It allows applications to interact
with the Hyprland compositor through the standardized XDG Desktop Portal
framework, enabling sandboxed applications (such as Flatpaks) to properly
integrate with the desktop environment by providing portal services such as
screen sharing and other system services.


%prep
%autosetup -p1


%build
%meson
%meson_build


%install
%meson_install
install -Dpm644 %{SOURCE1} -t %{buildroot}%{_mandir}/man1


%post
%systemd_user_post %{name}.service

%preun
%systemd_user_preun %{name}.service


%files
%license LICENSE
%doc README.md
%{_bindir}/hyprland-share-picker
%{_mandir}/man1/hyprland-share-picker.1*
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service
%{_datadir}/xdg-desktop-portal/portals/hyprland.portal
%{_libexecdir}/%{name}
%{_userunitdir}/%{name}.service


%changelog
%autochangelog
