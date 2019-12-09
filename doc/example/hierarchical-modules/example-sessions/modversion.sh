#!/bin/bash

source $MOD_GIT_ROOTDIR/doc/example/hierarchical-modules/example-sessions/common_code.sh

do_cmd module --version
do_cmd echo "MODULEPATH=$MODULEPATH"
