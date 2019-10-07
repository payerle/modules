#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module --version
do_cmd echo "MODULEPATH=$MODULEPATH"
