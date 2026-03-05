%global debug_package %{nil}

Name:           openalgz-ut
Version:        1.1.0
Release:        %autorelease
Summary:        A simple and fast compiling C++23 unit test library

License:        MIT
URL:            https://github.com/openalgz/ut
Source:         %{url}/archive/v%{version}/ut-%{version}.tar.gz

# Fix utConfig.cmake using PROJECT_NAME instead of hardcoded "ut",
# which breaks find_package(ut) when called from other projects.
Patch0:         openalgz-ut-fix-config.patch

BuildRequires:  cmake
BuildRequires:  gcc-c++

%description
A simple and fast compiling unit test library for C++23. It supports both
runtime and compile-time testing with a minimal API including test suites,
named tests, expect assertions, and exception checking. It is a header-only,
single header library.

%package        devel
Summary:        Development files for %{name}
BuildArch:      noarch
Provides:       %{name}-static = %{version}-%{release}
%description    devel
Development files for %{name}.

%prep
%autosetup -n ut-%{version} -p1

%build
%cmake \
    -Dut_DEVELOPER_MODE:BOOL=OFF
%cmake_build

%install
%cmake_install

%files devel
%license LICENSE
%doc README.md
%{_datadir}/ut/
%{_includedir}/ut/

%changelog
%autochangelog
