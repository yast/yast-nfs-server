#! /bin/bash
# $Id$

# params:
# $1 "read" or "write"
# $2 input file name
# $3 output file name (template, expected)
# $4 output file name (temporary, actual)
# $5 agent commands file
# $6 full path of the agent to run
set -o errexit

# kludge: break up the output into lines
ADD_LF_BEFORE_MAP='s/\$\[/\
\$\[/g'
ADD_LF_AFTER_LAST_COMMA='s/,\] $/,\
\] /g'
ADD_LF_AFTER_COMMA_OR_COLON='s/\([:,]\)/\1\
/g'

NORMALIZE="parseycp -n"

function run() {
    IN=$2
    OUT=$3
    OUT_TMP=$4
    export IN OUT OUT_TMP
    sh $5 \
	| $NORMALIZE \
	| $6 -l /dev/stderr \
	| $NORMALIZE \
	| sed -e 1d \
	| sed -e "$ADD_LF_BEFORE_MAP" -e "$ADD_LF_AFTER_LAST_COMMA" #-e "$ADD_LF_AFTER_COMMA_OR_COLON"
}

# MAIN
case $1 in
    read)
	run ${1+"$@"} > "$4"
	diff -u "$3" "$4"
	;;
    write)
	# test it twice - with the file existing and without it
	rm -f "$4"
	for i in 1 2; do
	    run ${1+"$@"} > /dev/null
	    diff -u "$3" "$4"
	done
	;;
    *)
	echo "$0: Expecting 'read' or 'write' as \$1, got '$1'"
	exit 1
esac
