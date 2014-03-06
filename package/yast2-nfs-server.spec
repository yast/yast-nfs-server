#
# spec file for package yast2-nfs-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-nfs-server
Version:        3.1.3
Release:        0
URL:            https://github.com/yast/yast-nfs-server

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+
# Changed implementation for checking if service is enabled 2.23.23 (affects testsuite)
BuildRequires:	yast2 >= 2.23.23
BuildRequires:	perl-XML-Writer update-desktop-files yast2-testsuite
BuildRequires:  yast2-devtools >= 3.1.10
# Service::Find
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22
Requires:	yast2-nfs-common
Recommends:     nfs-kernel-server

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - NFS Server Configuration

%description
The YaST2 component for configuration of an NFS server. NFS stands for
network file system access. It allows access to files on remote
machines.

%package -n yast2-nfs-common
Summary:	Configuration of NFS, common parts
Group:		System/YaST

%description -n yast2-nfs-common
-

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/nfs_server
%{yast_yncludedir}/nfs_server/*
%{yast_clientdir}/nfs-server.rb
%{yast_clientdir}/nfs_server.rb
%{yast_clientdir}/nfs_server_auto.rb
%{yast_moduledir}/NfsServer.rb
%{yast_desktopdir}/nfs_server.desktop
%{yast_scrconfdir}/etc_exports.scr
%{yast_agentdir}/ag_exports
%doc %{yast_docdir}
%{yast_schemadir}/autoyast/rnc/nfs_server.rnc

%files -n yast2-nfs-common
%defattr(-,root,root)
%{yast_scrconfdir}/cfg_nfs.scr
%{yast_scrconfdir}/etc_idmapd_conf.scr
