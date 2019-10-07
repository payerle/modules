#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load pgi/18.4
do_cmd module load openmpi/3.1
do_cmd module load foo/1.1
do_cmd module list
do_cmd foo
do_cmd module switch pgi intel/2018
do_cmd module list
do_cmd foo
do_cmd mpirun
