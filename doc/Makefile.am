#
# Makefile.am for nfs-server/doc
#
# $Id$
#

htmldir = $(docdir)

screenshots = \
	nfs-server*.png \
	abort.png
workflow.png: workflow.dia $(screenshots)
	dia --export=$@ $<
MAINTAINERCLEANFILES = workflow.png

html_DATA = index.html workflow.dia workflow.png $(screenshots)
EXTRA_DIST = $(html_DATA)
