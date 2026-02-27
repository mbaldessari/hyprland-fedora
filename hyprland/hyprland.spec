Name:           hyprland
Version:        0.53.3
Release:        %autorelease
Summary:        Dynamic tiling Wayland compositor that doesn't sacrifice on its looks

# hyprland: BSD-3-Clause
# protocols/kde-server-decoration.xml: LGPL-2.1-or-later
# protocols/wayland-drm.xml: HPND-sell-variant
# protocols/wlr-data-control-unstable-v1.xml: HPND-sell-variant
# protocols/wlr-foreign-toplevel-management-unstable-v1.xml: HPND-sell-variant
# protocols/wlr-gamma-control-unstable-v1.xml: HPND-sell-variant
# protocols/wlr-layer-shell-unstable-v1.xml: HPND-sell-variant
# protocols/wlr-output-management-unstable-v1.xml: HPND-sell-variant
License:        BSD-3-Clause AND HPND-sell-variant AND LGPL-2.1-or-later
URL:            https://github.com/hyprwm/Hyprland
Source0:        %{url}/releases/download/v%{version}/source-v%{version}.tar.gz
Source4:        macros.hyprland
Source5:        hyprpm.1
Source6:        start-hyprland.1
Patch0:         bump-glaze-7.patch

%{lua:
hyprdeps = {
    "cmake",
    "gcc-c++",
    "meson",
    "glaze-devel",
    "pkgconfig(aquamarine)",
    "pkgconfig(cairo)",
    "pkgconfig(egl)",
    "pkgconfig(gbm)",
    "pkgconfig(gio-2.0)",
    "pkgconfig(glesv2)",
    "pkgconfig(hwdata)",
    "pkgconfig(hyprcursor)",
    "pkgconfig(hyprgraphics)",
    "pkgconfig(hyprland-protocols)",
    "pkgconfig(hyprlang)",
    "pkgconfig(hyprutils)",
    "pkgconfig(hyprwayland-scanner)",
    "pkgconfig(hyprwire)",
    "pkgconfig(libdisplay-info)",
    "pkgconfig(libdrm)",
    "pkgconfig(libinput) >= 1.28",
    "pkgconfig(libliftoff)",
    "pkgconfig(libseat)",
    "pkgconfig(libudev)",
    "pkgconfig(muparser)",
    "pkgconfig(pango)",
    "pkgconfig(pangocairo)",
    "pkgconfig(pixman-1)",
    "pkgconfig(re2)",
    "pkgconfig(systemd)",
    "pkgconfig(tomlplusplus)",
    "pkgconfig(uuid)",
    "pkgconfig(wayland-client)",
    "pkgconfig(wayland-protocols) >= 1.45",
    "pkgconfig(wayland-scanner)",
    "pkgconfig(wayland-server)",
    "pkgconfig(xcb-composite)",
    "pkgconfig(xcb-dri3)",
    "pkgconfig(xcb-errors)",
    "pkgconfig(xcb-ewmh)",
    "pkgconfig(xcb-icccm)",
    "pkgconfig(xcb-present)",
    "pkgconfig(xcb-render)",
    "pkgconfig(xcb-renderutil)",
    "pkgconfig(xcb-res)",
    "pkgconfig(xcb-shm)",
    "pkgconfig(xcb-util)",
    "pkgconfig(xcb-xfixes)",
    "pkgconfig(xcb-xinput)",
    "pkgconfig(xcb)",
    "pkgconfig(xcursor)",
    "pkgconfig(xkbcommon)",
    "pkgconfig(xwayland)",
    "udis86-devel",
    }
}

%define printbdeps(r) %{lua:
for _, dep in ipairs(hyprdeps) do
    print((rpm.expand("%{-r}") ~= "" and "Requires: " or "BuildRequires: ")..dep.."\\n")
end
}

BuildRequires:  desktop-file-utils
%printbdeps

Requires:       xorg-x11-server-Xwayland%{?_isa}
Requires:       aquamarine%{?_isa} >= 0.9.2
Requires:       hyprcursor%{?_isa} >= 0.1.13
Requires:       hyprgraphics%{?_isa} >= 0.1.6
Requires:       hyprlang%{?_isa} >= 0.6.3
Requires:       hyprutils%{?_isa} >= 0.8.4

# Used in the default configuration
Recommends:     kitty
Recommends:     wofi
Recommends:     playerctl
Recommends:     brightnessctl
Recommends:     hyprland-guiutils
# Lack of graphical drivers may hurt the common use case
Recommends:     mesa-dri-drivers
# Logind needs polkit to create a graphical session
Recommends:     polkit
# https://wiki.hyprland.org/Useful-Utilities/Systemd-start
Recommends:     %{name}-uwsm

Recommends:     (qt5-qtwayland if qt5-qtbase-gui)
Recommends:     (qt6-qtwayland if qt6-qtbase-gui)

%description
Hyprland is a dynamic tiling Wayland compositor that doesn't sacrifice
on its looks. It supports multiple layouts, fancy effects, has a
very flexible IPC model allowing for a lot of customization, a powerful
plugin system and more.

%package        uwsm
Summary:        UWSM session integration for Hyprland
BuildArch:      noarch
Requires:       uwsm
%description    uwsm
Wayland session desktop entry for launching Hyprland through the Universal
Wayland Session Manager (uwsm). Install this package to start Hyprland
as a properly managed systemd user session from your display manager.

%package        devel
Summary:        Header and protocol files for %{name}
License:        BSD-3-Clause
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       cpio
%printbdeps -r
Requires:       git-core
Requires:       pkgconfig(xkbcommon)

%description    devel
Development files for building Hyprland plugins and applications that
interact with the compositor. Includes protocol definitions, header files,
and pkgconfig integration. Also provides an RPM macro for the Hyprland
version to simplify plugin packaging.


%prep
%autosetup -n hyprland-source -p1

rm -rf subprojects/hyprland-protocols subprojects/udis86

sed -i \
  -e "s|@@HYPRLAND_VERSION@@|%{version}|g" \
  %{SOURCE4}


%build

%cmake \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DNO_TESTS=TRUE \
    -DBUILD_TESTING=FALSE
%cmake_build


%install

%cmake_install
install -Dpm644 %{SOURCE4} -t %{buildroot}%{_rpmconfigdir}/macros.d
install -Dpm644 %{SOURCE5} %{SOURCE6} -t %{buildroot}%{_mandir}/man1
ln -s Hyprland.1 %{buildroot}%{_mandir}/man1/hyprland.1


%check
desktop-file-validate %{buildroot}%{_datadir}/wayland-sessions/hyprland.desktop
desktop-file-validate %{buildroot}%{_datadir}/wayland-sessions/hyprland-uwsm.desktop


%files
%license LICENSE
%{_bindir}/[Hh]yprland
%{_bindir}/hyprctl
%{_bindir}/hyprpm
%{_bindir}/start-hyprland
%{_datadir}/hypr/
%{_datadir}/wayland-sessions/hyprland.desktop
%{_datadir}/xdg-desktop-portal/hyprland-portals.conf
%{_mandir}/man1/hyprctl.1*
%{_mandir}/man1/hyprland.1*
%{_mandir}/man1/Hyprland.1*
%{_mandir}/man1/hyprpm.1*
%{_mandir}/man1/start-hyprland.1*
%{bash_completions_dir}/hypr*
%{fish_completions_dir}/hypr*.fish
%{zsh_completions_dir}/_hypr*

%files uwsm
%{_datadir}/wayland-sessions/hyprland-uwsm.desktop

%files devel
%{_datadir}/pkgconfig/hyprland.pc
%{_includedir}/hyprland/
%{_rpmconfigdir}/macros.d/macros.hyprland


%changelog
%autochangelog
