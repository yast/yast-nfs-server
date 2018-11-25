# Sources for nfs-server

module_DATA = \
  modules/NfsServer.rb

client_DATA = \
  clients/nfs-server.rb \
  clients/nfs_server.rb \
  clients/nfs_server_auto.rb

yncludedir = @yncludedir@/nfs_server
ynclude_DATA = \
  include/nfs_server/ui.rb \
  include/nfs_server/routines.rb

scrconf_DATA = \
  scrconf/cfg_nfs.scr \
  scrconf/etc_idmapd_conf.scr \
  scrconf/etc_exports.scr

agent_SCRIPTS = \
  servers_non_y2/ag_exports

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/nfs_server.rnc

desktop_DATA = \
  desktop/nfs_server.desktop

scalable_DATA = \
  icons/hicolor/scalable/apps/yast-nfs-server.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
