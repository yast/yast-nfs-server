#
# Makefile.am for y2c_nfs_server/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/nfs_server
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	nfs_server.ycp	\
	nfs_server_write.ycp

include_DATA =		\
	io.ycp		\
	ui.ycp

menu_DATA = menuentry_nfs_server.ycp

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA)
