Name:           hyprland-guiutils
Version:        0.2.1
Release:        %autorelease -b1
Summary:        Hyprland GUI utility applications
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-guiutils
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++

#BuildRequires:  cmake(Qt6Quick)
#BuildRequires:  cmake(Qt6QuickControls2)
#BuildRequires:  cmake(Qt6WaylandClient)
#BuildRequires:  cmake(Qt6Widgets)
#BuildRequires:  qt6-qtbase-private-devel

BuildRequires:  pkgconfig(hyprutils) >= 0.6.0
BuildRequires:  pkgconfig(hyprlang) >= 0.2.4
BuildRequires:  pkgconfig(hyprtoolkit) >= 0.4.0
BuildRequires:  pkgconfig(xkbcommon)

BuildRequires:  libdrm-devel
BuildRequires:  pixman-devel

Obsoletes:      hyprland-qtutils < 0.2.0

%description
A collection of GUI utility applications for the Hyprland ecosystem, built
on hyprtoolkit. Includes hyprland-dialog for displaying dialog boxes,
hyprland-run as a launcher, hyprland-welcome for the welcome screen,
hyprland-donate-screen, and hyprland-update-screen. This package supersedes
hyprland-qtutils.

%prep
%autosetup -p1

%build
%cmake
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_bindir}/hyprland-dialog
%{_bindir}/hyprland-donate-screen
%{_bindir}/hyprland-update-screen
%{_bindir}/hyprland-run
%{_bindir}/hyprland-welcome

%changelog
%autochangelog
