#
# Makefile.am for .../testsuite
#

AUTOMAKE_OPTIONS = dejagnu

ycp_testfiles = $(wildcard tests/*.out) $(wildcard tests/*.err) $(wildcard tests/*.ycp) $(wildcard tests/*.yh)

epag_misc = lib/yast2_epag.exp run/runtest-epag.sh
epag_testfiles = $(wildcard $(RPMNAME).test/ag_*.exp tests.epag/*.[rw].run tests.epag/*.[rw].data tests.epag/*.rw.ycp)
EXTRA_DIST = $(ycp_testfiles) $(epag_testfiles) $(epag_misc)

testsuite_prepare = @ydatadir@/testsuite/Makefile.testsuite

# explicitly list files we want for the ycp tests
# don't mess with: Makefile.am .cvsignore
all-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) \
	        dirs \
		config/default.exp config/unix.exp config/unknown.exp \
		run/runtest.sh $(RPMNAME).test/testsuite.exp
	mkdir -p tmp

clean-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) clean

check-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) check

# EOF
