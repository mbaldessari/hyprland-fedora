%global debug_package %{nil}

Name:           glaze
Version:        7.2.2
Release:        %autorelease
Summary:        Extremely fast, in memory, JSON and interface library

# glaze: MIT
# include/glaze/util/dragonbox.hpp: Apache-2.0 WITH LLVM-exception OR BSL-1.0
License:        MIT AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)
URL:            https://github.com/stephenberry/glaze
Source:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

# Use system ut and Eigen3 instead of FetchContent
Patch0:         glaze-use-system-deps.patch

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  boost-devel
BuildRequires:  eigen3-devel
BuildRequires:  openalgz-ut-devel

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
# The bundled Dragonbox is more recent than the version of Fedora. This is due
# to glaze using the upstream source version. The author of Dragonbox hasn't
# pushed another update since June 18, 2022, while pushing newer stuff on the
# repo. Therefore glaze has to have this bundled.
Provides:       bundled(dragonbox) = 1.1.3^20241029gitc3d81a9
%description    devel
Development files for %{name}.

%package        doc
Summary:        Documentation for %{name}
BuildArch:      noarch

%description    doc
Documentation and example files for %{name}.

%prep
%autosetup -p1

%build
%cmake \
    -DFETCHCONTENT_FULLY_DISCONNECTED:BOOL=TRUE \
    -DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS \
    -Dglaze_INSTALL_CMAKEDIR=%{_datadir}/cmake/%{name} \
    -Dglaze_DEVELOPER_MODE:BOOL=ON \
    -Dglaze_ENABLE_FUZZING:BOOL=OFF \
    -Dglaze_BUILD_NETWORKING_TESTS:BOOL=OFF
%cmake_build

%install
%cmake_install

%check
%ctest --exclude-regex 'glaze-install_test|find_package_test'

%files devel
%license LICENSE
%doc README.md
%{_datadir}/cmake/%{name}/
%{_includedir}/%{name}/

%files doc
%license LICENSE
%doc examples/
%doc docs/

%changelog
%autochangelog
