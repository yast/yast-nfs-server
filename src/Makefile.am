# Makefile.am for nfs-server/src

myincludedir = @yncludedir@/nfs_server

client_DATA =		\
	nfs-server.ycp	\
	nfs_server.ycp	\
	nfs_server_auto.ycp

myinclude_DATA =	\
	routines.ycp	\
	ui.ycp

module_DATA =		\
	NfsServer.ycp

desktop_DATA = nfs_server.desktop

nfs_server:
	ln -sf . nfs_server

ycpchook = nfs_server

EXTRA_DIST = $(client_DATA) $(myinclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
