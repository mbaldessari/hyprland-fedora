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

%if !%{defined build_for}
%global build_for release
%endif

%define pluginsmeta %{lua:
rpm.define("pluginsmetaname hyprland-plugins")
rpm.define("hyprlandpkg hyprland")
}

%pluginsmeta

Name:           %{pluginsmetaname}
Version:        0.53.0
Release:        %autorelease
Summary:        Official plugins for Hyprland

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-plugins
Source:         %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  meson
BuildRequires:  %{hyprlandpkg}-devel

Requires:       %{hyprlandpkg} = %_hyprland_version

# print Recommends: for each plugin
%{lua:for w in rpm.expand('%plugins'):gmatch("%S+") do print("Recommends: hyprland-plugin-"..w..(rpm.expand("%build_for") == "git" and "-git" or "")..'\n') end}

%description
A collection of official plugins for the Hyprland compositor. Includes
window decoration enhancements, visual effects, layout extensions, and
additional dispatchers. Each plugin is packaged separately so you can
install only the ones you need.

%define _package() \%package -n hyprland-plugin-%1%{?pluginssuffix:%{pluginssuffix}}\
Summary:       %1 plugin for %{hyprlandpkg}\
Requires:      %{hyprlandpkg} = %_hyprland_version\
\%description  -n hyprland-plugin-%1%{?pluginssuffix:%{pluginssuffix}}\
\%1 plugin for %{hyprlandpkg}.\
\%files -n     hyprland-plugin-%1%{?pluginssuffix:%{pluginssuffix}}\
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
