#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load openmpi/3.1 && do_cmd mpirun
do_cmd module list
