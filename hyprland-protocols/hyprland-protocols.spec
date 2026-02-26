Name:           hyprland-protocols
Version:        0.7.0
Release:        %autorelease
Summary:        Wayland protocol extensions for Hyprland
BuildArch:      noarch

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-protocols
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc

BuildRequires:  meson

%description
Wayland protocol extensions for Hyprland. These protocols bridge the gap
between Hyprland and the functionality offered by KDE/GNOME, and allow
applications some extra functionality under Hyprland. Includes protocols for
screen sharing, global keybindings, input focus handling, display management,
and more.

%package        devel
Summary:        Wayland protocol extensions for Hyprland

%description    devel
%{summary}.


%prep
%autosetup -p1


%build
%meson
%meson_build


%install
%meson_install


%files devel
%license LICENSE
%doc README.md
%{_datadir}/pkgconfig/%{name}.pc
%{_datadir}/%{name}/


%changelog
%autochangelog
