%global debug_package %{nil}

Name:           glaze
Version:        7.1.0
Release:        %autorelease
Summary:        Extremely fast, in memory, JSON and interface library

# glaze: MIT
# include/glaze/util/dragonbox.hpp: Apache-2.0 WITH LLVM-exception OR BSL-1.0
License:        MIT AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)
URL:            https://github.com/stephenberry/glaze
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++

%description
Glaze is one of the fastest JSON libraries in the world. It reads and writes
from object memory, simplifying interfaces and offering exceptional
performance. It provides automatic compile-time reflection for C++ structs
without requiring metadata or macros. Glaze is a header-only library
supporting multiple serialization formats including JSON, BEVE, CBOR, CSV,
and MessagePack.

%package        devel
Summary:        Development files for %{name}
BuildArch:      noarch
Provides:       %{name}-static = %{version}-%{release}
%description    devel
Development files for %{name}.

%prep
%autosetup -p1

%build
%cmake \
    -Dglaze_INSTALL_CMAKEDIR=%{_datadir}/cmake/%{name} \
    -Dglaze_DISABLE_SIMD_WHEN_SUPPORTED:BOOL=ON \
    -Dglaze_DEVELOPER_MODE:BOOL=OFF \
    -Dglaze_ENABLE_FUZZING:BOOL=OFF
%cmake_build

%install
%cmake_install

%files devel
%license LICENSE
%doc README.md
%{_datadir}/cmake/%{name}/
%{_includedir}/%{name}/

%changelog
%autochangelog
