#
# Makefile.am for nfs_server/doc
#
# $Id$
#

SUBDIRS = autodocs

docdir = @DOCDIR@
htmldir = $(docdir)

screenshots = \
	nfs-server1.png \
	nfs-server2.png \
	save.png \
	abort.png
workflow.png: workflow.dia $(screenshots)
	dia --export=$@ $<
MAINTAINERCLEANFILES = workflow.png

html_DATA = index.html workflow.dia workflow.png $(screenshots)
EXTRA_DIST = $(html_DATA)
