Name:           hyprland-qt-support
Version:        0.1.0
Release:        %autorelease -b10
Summary:        Qt6 QML style provider for Hyprland applications
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-qt-support
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc
Patch:          cmake.patch

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  qt6-rpm-macros

BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6QuickControls2)
BuildRequires:  cmake(Qt6Qml)

BuildRequires:  pkgconfig(hyprlang)

%description
A Qt6 QML style provider for Hyprland applications. It allows users to apply
Hyprland-themed styling to Qt6/QML applications, enabling visual consistency
between Qt applications and the Hyprland window manager environment.

%prep
%autosetup -p1

%build
%cmake -DINSTALL_QMLDIR=%{_qt6_qmldir}
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_libdir}/libhyprland-quick-style-impl.so
%{_libdir}/libhyprland-quick-style.so
%{_qt6_qmldir}/org/hyprland/

%changelog
%autochangelog
