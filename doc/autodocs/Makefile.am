#
# Makefile.am for y2c_nfs_server/doc/autodocs
#
# $Id$
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
MAINTAINERCLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp
	@YAST2DIR@/bin/ycpdoc -d. $(srcdir)/../../src/*.ycp

CLEANFILES = $(html_DATA)
