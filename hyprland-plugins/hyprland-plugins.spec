%global __provides_exclude_from ^(%{_libdir}/hyprland/.*\\.so)$

%global plugins %{shrink:
                borders-plus-plus
                csgo-vulkan-fix
                hyprbars
                hyprexpo
                hyprfocus
                hyprscrolling
                hyprtrails
                hyprwinwrap
                xtra-dispatchers
}

# Fallback if hyprland-devel macros are not installed (e.g. spectool)
%{!?_hyprland_version:%define _hyprland_version 0.53.3}


Name:           hyprland-plugins
Version:        0.53.0
Release:        %autorelease
Summary:        Official plugins for Hyprland

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-plugins
Source:         %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  meson
BuildRequires:  hyprland-devel >= %{version}

Requires:       hyprland = %_hyprland_version

# print Recommends: for each plugin
%{lua:for w in rpm.expand('%plugins'):gmatch("%S+") do print("Recommends: hyprland-plugin-"..w..'\n') end}

%description
A collection of official plugins for the Hyprland compositor. Includes
window decoration enhancements, visual effects, layout extensions, and
additional dispatchers. Each plugin is packaged separately so you can
install only the ones you need.

%define _package() \%package -n hyprland-plugin-%1\
Summary:       %1 plugin for Hyprland\
Requires:      hyprland = %_hyprland_version\
\%description  -n hyprland-plugin-%1\
\%1 plugin for Hyprland.\
\%files -n     hyprland-plugin-%1\
\%%license LICENSE\
\%dir %{_libdir}/hyprland\
\%{_libdir}/hyprland/lib%1.so\

# expand %%_package for each plugin
%{lua:for w in rpm.expand('%plugins'):gmatch("%S+") do print(rpm.expand("%_package "..w)..'\n\n') end}


%prep
%autosetup -n %{name}-%{version} -p1


%build
for plugin in %{plugins}
do
pushd $plugin
%meson --libdir=%{_libdir}/hyprland
%meson_build
popd
done


%install
for plugin in %{plugins}
do
pushd $plugin
%meson_install
popd
done


%files


%changelog
%autochangelog
