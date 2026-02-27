Name:           hyprwayland-scanner
Version:        0.4.5
Release:        %autorelease
Summary:        A Hyprland implementation of wayland-scanner, in and for C++

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprwayland-scanner
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        hyprwayland-scanner.1

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  cmake(pugixml)
BuildRequires:  gcc-c++

%description
A Hyprland implementation of wayland-scanner, in and for C++. It generates
RAII-ready, modern C++ bindings for Wayland protocols, for either servers or
clients. Requires a compiler with C++23 support.

%package        devel
Summary:        A Hyprland implementation of wayland-scanner, in and for C++

%description    devel
%{summary}.

%prep
%autosetup -p1

%build
%cmake
%cmake_build

%install
%cmake_install
install -Dpm644 %{SOURCE1} -t %{buildroot}%{_mandir}/man1

%files devel
%license LICENSE
%doc README.md
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1*
%{_libdir}/pkgconfig/%{name}.pc
%{_libdir}/cmake/%{name}/

%changelog
%autochangelog
