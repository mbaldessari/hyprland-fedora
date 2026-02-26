Name:           hyprwire
Version:        0.3.0
Release:        %autorelease -b1
Summary:        A fast and consistent wire protocol for IPC

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprwire
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  ninja-build
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(libffi)
BuildRequires:  pkgconfig(pugixml)

%description
A fast and consistent wire protocol for IPC, heavily inspired by Wayland.
Hyprwire is designed to be strict (both sides must agree on the protocol),
fast (simple initial handshakes for quick information exchange), and simple
to use (modern C++ API abstracting memory-sensitive operations).

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}
%description    devel
Development files for %{name}.

%prep
%autosetup -p1

%build
%cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_libdir}/lib%{name}.so.%{version}
%{_libdir}/lib%{name}.so.3

%files devel
%doc README.md
%{_bindir}/%{name}-scanner
%{_includedir}/%{name}/
%{_libdir}/cmake/%{name}-scanner/
%{_libdir}/lib%{name}.so
%{_libdir}/pkgconfig/%{name}.pc
%{_libdir}/pkgconfig/%{name}-scanner.pc

%changelog
%autochangelog
