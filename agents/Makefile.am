#
# Makefile.am for y2c_nfs_server/agents
#
# $Id$
#

agentsdir = $(YAST2DIR)/servers_non_y2
scrconfdir = $(YAST2DIR)/scrconf

agents_SCRIPTS = ag_exports

scrconf_DATA = etc_exports.scr

TESTS = test-exports
testdata = test-exports-i.in test-exports-i.out test-exports-o.out

EXTRA_DIST = $(agents_SCRIPTS) $(scrconf_DATA) $(TESTS) $(testdata)
