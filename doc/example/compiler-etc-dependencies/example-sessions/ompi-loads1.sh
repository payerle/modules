#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load pgi/19.4
do_cmd module load openmpi/4.0
do_cmd module list
do_cmd mpirun

do_cmd module unload openmpi
do_cmd module switch pgi intel/2019
do_cmd module load openmpi/4.0
do_cmd module list
do_cmd mpirun

do_cmd module unload openmpi
do_cmd module switch intel gcc/9.1.0
do_cmd module load openmpi/4.0
do_cmd mpirun

do_cmd module unload openmpi
do_cmd module switch gcc gcc/8.2.0
do_cmd module load openmpi/4.0
do_cmd module list

