#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load openmpi/3.1
err=$?
do_cmd module list
if [ $err -eq 0 ]; then
	do_cmd mpirun
fi
