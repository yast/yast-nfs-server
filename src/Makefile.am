#
# Makefile.am for y2c_nfs_server/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
yincludedir = $(YAST2DIR)/include/nfs_server
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	nfs_server.ycp	\
	nfs_server_write.ycp

yinclude_DATA =		\
	routines.ycp	\
	ui.ycp

modules_DATA =		\
	NfsServer.ycp

menu_DATA = menuentry_nfs_server.y2cc

EXTRA_DIST = $(clients_DATA) $(yinclude_DATA) $(modules_DATA) $(menu_DATA)
