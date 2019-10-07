#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load bar
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd bar
fi

do_cmd module purge
do_cmd module load bar/4.7
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd bar
fi
