#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load foo
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd foo
fi

do_cmd module purge
do_cmd module load foo/1.1
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd foo
fi

do_cmd module purge
do_cmd module load pgi/18.4
do_cmd module load foo
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd foo
fi
