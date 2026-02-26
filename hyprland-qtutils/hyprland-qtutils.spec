Name:           hyprland-qtutils
Version:        0.1.5
Release:        %autorelease -b3
Summary:        Hyprland Qt/QML utility applications
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-qtutils
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc
Patch:          fix-build.diff

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  chrpath
BuildRequires:  cmake
BuildRequires:  gcc-c++

BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6QuickControls2)
BuildRequires:  cmake(Qt6WaylandClient)
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  qt6-qtbase-private-devel

BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  wayland-devel

Requires:       hyprland-qt-support%{?_isa}

%description
A collection of Qt/QML utility applications for the Hyprland ecosystem.
Includes hyprland-dialog for displaying dialog boxes, hyprland-donate-screen,
and hyprland-update-screen. Requires hyprland-qt-support for consistent
styling.

%prep
%autosetup -p1

%build
%cmake
%cmake_build

%install
%cmake_install
chrpath --delete %{buildroot}%{_bindir}/hyprland-dialog
chrpath --delete %{buildroot}%{_bindir}/hyprland-donate-screen
chrpath --delete %{buildroot}%{_bindir}/hyprland-update-screen

%files
%license LICENSE
%doc README.md
%{_bindir}/hyprland-dialog
%{_bindir}/hyprland-donate-screen
%{_bindir}/hyprland-update-screen

%changelog
%autochangelog
