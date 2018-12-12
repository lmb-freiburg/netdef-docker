#######################################################################
# Author: Nikolaus Mayer (2018), mayern@cs.uni-freiburg.de
#######################################################################

SHELL:=/bin/bash

default: lmb-freiburg-netdef

.phony: lmb-freiburg-netdef

lmb-freiburg-netdef:
	docker build                    \
	       -f Dockerfile            \
	       -t lmb-freiburg-netdef   \
	       --build-arg uid=$$UID    \
	       --build-arg gid=$$GROUPS \
	       .

