#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load pgi/19.4
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
do_cmd module unload foo
do_cmd module load openmpi/3.1
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo

do_cmd module unload foo
do_cmd module unload openmpi
do_cmd module switch pgi intel/2019
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
do_cmd module unload foo
do_cmd module load intelmpi
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
do_cmd module unload foo
do_cmd module switch intelmpi mvapich/2.3.1
do_cmd module load foo/2.4
do_cmd module list 
do_cmd foo
do_cmd module unload foo
do_cmd module switch mvapich openmpi/4.0
do_cmd module load foo/2.4
do_cmd module list 
do_cmd foo

do_cmd module unload foo
do_cmd module unload openmpi
do_cmd module switch intel/2019 gcc/9.1.0
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
do_cmd module unload foo
do_cmd module load mvapich/2.3.1
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
do_cmd module unload foo
do_cmd module switch mvapich openmpi/4.0
do_cmd module load foo/2.4
do_cmd module list
do_cmd foo
