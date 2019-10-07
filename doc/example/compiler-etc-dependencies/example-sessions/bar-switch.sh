#!/bin/bash

do_cmd()
{	cmd="$@"
	echo $MPS1 $cmd
	$cmd
}

do_cmd module purge
do_cmd module load gcc/9.1.0
do_cmd module load simd/avx
do_cmd module load bar/5.4
do_cmd module list
do_cmd bar
do_cmd module switch simd simd/avx2
do_cmd module list
do_cmd bar
