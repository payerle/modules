.. _compiler-etc-dependencies:

================================================
Handling Compiler and other Package Dependencies
================================================

When creating a collection of software (applications and libraries)
for users to use, there is a problem of ensuring that the
user is using the correct builds of everything.  Generally,
if an user is attempting to compile code making use of the system
software collection, you want to ensure that the user is compiling
his code with the same compiler that was used to compile the library.
This tends to be particularly true of C++ and Fortran code using modules,
and parallel codes using MPI libraries.

As a result, in environemnts supporting multiple compilers,
software libraries often end up with multiple installs of libraries
and applications of the same version, depending on the compiler
and other libraries used to build them.  Sometimes there are 
even additional installs for variants with different threading
models, number formats, level of vectorization support, etc.
This cookbook describes various strategies for handling the modulefiles 
to support all these different builds for each package.

For each strategy, we will provide an overview of how it works,
and then show how an user might interact with it, usually a similar 
sequence for each case.  
We then try to summarize the strengths, weaknesses, and other attributes of each strategy.  We also try to
discuss differences in using on older (3.x) and newer (4.x) Environmental
Modules versions.

In addition to displaying examples for each strategy in this
document, we have set up a the test environment as a playground in
which you can explore.  As the examples are a bit more elaborate
than in some other cookbooks, and as they make use of the same modulefile
names, the examples for the different strategies do not play well
with each other.  So each strategy has its own modulefile tree underneath
``doc/example/compiler-etc-dependencies``.  Furthermore, we use some 
modulefile names (e.g. gcc,
intel, pgi, openmpi, etc) that likely are present on your system as well,
so your production environment might interfere with the examples as
well.  It is therefore recommended
that you spawn a new shell, do a ``module purge``, and then set
your ``MODULEPATH`` environmental variable to the appropriate path
for example modulefiles for the strategy that you wish to explore.

Some of the modulefiles, etc. require knowledge of where they were
installed.  To avoid requiring you to update lines in numerous
files, we require you to set the environmental variable
``MOD_GIT_ROOTDIR`` to location where the modules git working directory
was cloned.  E.g., if you issued the command 
``module clone  https://github.com/cea-hpc/modules.git ~/modules.test``
you should set ``MOD_GIT_ROOTDIR`` to ``~/modules.test``.  Please
ensure it is exported (use ``setenv`` in csh and related shells,
or ``export`` in Bourne derived shells like bash).  This is just
a hack to make the examples work better; if you opt to use one of
these strategies in production, you will want to hard code some
relevant paths; the comments in the modulefiles will describe
what needs to be done.

As there are a fair number of modulefiles, we make use of various tricks
in the cookbook ``Tips for Code Reuse`` to minimize the amount of repeated
code.  In general, the actual modulefiles are small "stubfiles", setting one or a few
Tcl variables, and then sourcing a ``common`` tcl file which does all the
real work.   Symlinks are used where possible to avoid duplicating files.
We also in some cases use Tcl procedures; for the sake of the
examples these our sourced in the files as needed, but if one were to
use the strategies needing such in production it would be better to follow
the suggestions in ``Exposing Procedures and Variables to Modulefiles`` and
place the required procedures in site config script.

--------------------
Overview of Examples
--------------------

For the example cases, we make use of the example software library
(located at ``$MOD_GIT_ROOTDIR/doc/example/compiler-etc-dependencies/fake-sw-root``)
consisting of

  * GNU compiler versions 8.2.0 and 9.1.0
  * Intel Parallel Studio suite, versions 2018 and 2019. 

    + We assume this includes Intel compilers, Intel MPI, and MKL, and that loading the ``intel`` module
      will setup the environment for all of the above.

  * PGI compiler suite versions 18.4 and 19.4
  * OpenMPI version 4.0, built for:

    + gcc/9.1.0 
    + intel/2019 
    + pgi/19.4

  * OpenMPI version 3.1, built for:

    + gcc versions 8.2.0 and 9.1.0
    + intel versions  2018 and 2019
    + pgi versions 18.4 and 19.4

  * mvapich version 2.3.1, built for:

    + gcc/9.1.0 
    + intel/2019 
    + pgi/19.4

  * mvapich version 2.1, built for:

    + gcc versions 8.2.0 and 9.1.0
    + intel versions  2018 and 2019
    + pgi versions 18.4 and 19.4

  * foo version 2.4, built for:

    + gcc/9.1.0 and openmpi/4.0
    + gcc/9.1.0 and mvapich/2.3.1
    + gcc/9.1.0 and no MPI
    + intel/2019 and openmpi/4.0
    + intel/2019 and mvapich/2.3.1
    + intel/2019 and intelmpi
    + intel/2019 and no MPI
    + pgi/19.4 and openmpi/3.1
    + pgi/19.4 and no MPI

  * foo version 1.1, built for:

    + gcc/8.2.0 and openmpi/3.1
    + gcc/8.2.0 and mvapich/2.1
    + gcc/8.2.0 and no MPI
    + intel/2018 and openmpi/3.1
    + intel/2018 and mvapich/2.1
    + intel/2018 and intelmpi
    + intel/2018 and no MPI
    + pgi/18.4 and openmpi/3.1
    + pgi/18.4 and mvapich/2.1
    + pgi/18.4 and no MPI

  * bar version 5.4, built with:

   + gcc/9.1.0 and supporting avx2
   + gcc/9.1.0 and supporting avx

  * bar version 4.7, built for:

    + gcc/8.2.0 and supporting avx
    + gcc/8.2.0 and supporting sse4.1


I.e., we have 3 families of compiler suites with 2 different versions each.  And
two MPI families (openmpi and mvapich) with two versions each, with the
most recent version only built with the latest compiler version of each family,
and the older version built with both versions of each compiler family.
In addition, it is assumed that the intel compiler suites include Intel's MPI
library built for that compiler.  The application foo depends on the compiler and optionally on MPI libraries
and has two versions; the newer version *mostly* has builds for the latest compiler
and MPI (for pgi it only supports the latest compiler and older openmpi), and the
older version *mostly* has builds for the older compiler and MPI.  The bar application
depends on compiler and has variants depending on size of integers used in the API.

The ``fake-sw-root`` tree does not contain any real code (there are dummy scripts
for e.g. ``gcc``, ``mpirun``, etc.  that just echo then name of the code and what
compiler, etc. it was supposed to be built for) but show how such a directory tree might
be laid out.  Note that there are also a bunch of subdirectories named ``1`` 
containing symlinks, these are for the strategy using the Flavours add-on and are
discussed there.

We also assume that the gcc/8.2.0 compiler is the system default; i.e. it is
the compiler provided by default by the Linux distro used by the system, and
therefore might potentially be available to users without loading any modules.


--------
Flavours
--------

The ``Flavours`` strategy uses the ``Flavours`` extension to Tcl Environmental
Modules from Mark Dixon at the University of Leeds.  The code is available
via git, etc. from https://sourceforge.net/projects/flavours.  Unlike the
other strategies discussed, this requires the separate download and installation
of an extension to Environmental Modules.

Installation and Implementation
-------------------------------

More details can be found at the website for this extension, but to install this
you basically just need to:

#. Clone the git repo somewhere (``git clone https://git.code.sf.net/p/flavours/code flavours-code``)
#. Rename the standard Environmental Modules ``modulecmd`` file (in the ``bin`` subdirectory
   under the installation root) to ``modulecmd.wrapped``.
#. Copy the ``modulecmd.wrapper`` file from Flavours to the ``bin`` subdirectory above.  Make sure
   the ``modulecmd.wrapper`` file is executable.
#. Symlink ``modulecmd.wrapper`` to ``modulecmd``
#. Edit ``modulecmd.wrapper`` where indicated to give fully qualified path to ``modulecmd.wrapped``
#. Copy the ``flavours.tcl`` and ``pkgIndex.tcl`` files to some (possibly new) directory under
   the modules installation roor, and set TCLLIBPATH to that directory (you probably will want to
   add that to the various modules init scripts)

The ``module`` command invokes ``modulecmd``, which in this case is results
in the Flavours wrapper bash script ``modulecmd.wrapper`` being invoked.  This
calls the renamed standard ``modulecmd.wrapped`` command.  This wrapper
command catches and processes certain output from the modulefile evaluation
intended for its consumption.

The modulefiles themselves make use of various commands in the Tcl module ``flavours``.
Many of these are just flavours variants of standard modulefile commands, e.g.
``flavours prepend-path`` versus ``prepend-path``.  Some important flavours
commands:

*  ``package require flavours``: This loads the Tcl package flavours, and should occur
   near the top of your modulefile
*  ``flavours init``:  This initializes the flavours package, and should be the first
   of the flavours commands issued.  Typically call right after the package load.
*  ``flavours prereq``: Like the standard ``prereq`` command, this declares a prerequisite.
   But it also does quite a bit more, as is discussed further below.
*  ``flavours root``: This is used to set the root for where the package is actually 
   installed.  This is used when generating the ``flavours path``
*  ``flavours revision``: I believe this is intended to allow for changes in the path format in future
   versions of ``flavours``.  It is used in constructing the final path to the package.
*  ``flavours conflict``: This is similar to the standard conflict command, but enhanced
   to recognize the flavours prereqs above.
*  ``flavours commit``: This should be called after the ``root``, ``revision``, and ``prereq``
   subcommands of ``flavours`` are called, and before any of the ``path`` subcommands.  
   I believe this is responsible for taking all those values to above and constructing the
   path to the package.
*  ``flavours path``: This returns a string with the path to the specific build of the package.
*  ``flavours prepend-path`, ``flavour append-path``:  These work much like the standard
   ``prepend-path`` and ``append-path``, except that the value being prepended/appended
   to the environmental variable has the path (as returned by ``flavours path``) prepended
   to it with the appropriate directory separator.  E.g., to add to the PATH variable the bin subdirectory
   of the root directory where the specific build was installed, use ``flavours prepend-path PATH bin``
*  ``flavours cleanup``: This should be called after all ``flavours`` subcommands are finished
   and before exiting the script to ensure proper cleanup.  Among other things, it ensures 
   that any packages that depend on this package will get reloaded if this package is switched out.

The ``flavours prereq`` command accepts the new ``-class`` parameter, allowing
it to require a class of packages; e.g. one could use ``-class compiler`` to indicate
that it has a prereq on a compiler (any of classes ``gnu``, ``intel``, or ``pgi``).
The allowable classes, and the package basenames that are in each class, is defined in
``flavours.tcl`` in the Tcl associative array ``_class``.  The ones shipped by default are

* compiler: consisting of gnu, intel, and pgi
* mpi: consisting of openmpi, mvapich2, mvapich, intelmpi
* linalg: consisting of mkl, atlas, acml, netlib

You will likely want to adjust these if you go with flavours in production.

The ``flavours prereq`` command also accepts the parameter ``-optional``, which declares
optional prerequisites.  Although it sounds a little oxymoronic, this comes into play
with the secondary purpose of the command in declaring the components of the path, as 
discussed below.  If a prereq is not optional, the modulefile will complain if nothing
satisfying the prereq has been module loaded previously.  If the prereq is optional,
the modulefile will not complain if it was not loaded, but will use the prereq in
constructing the path to the build of the package if it was loaded.

The ``flavours prereq`` command also defines the components which will comprise the final
path to the directory containing the specific build of the package.  The order of the
prereq commands controls the order of the components in the path.

The modulefile will check that all non-optional ``flavours prereq`` commands are satisfied,
and then construct a path to the installation root for this build of the package using
the packages satisfying the prereqs.  The resultant path is composed of:

* the value from ``flavours root``
* directory separator (/)
* the value from ``flavours revision``
* directory separator (/)
* a ``prefix`` created by concatenating the package names satisfying the prereqs, in order.
  The package name and version will be separated by a hypen (-), as will the different 
  components.

So if ``flavours root`` was set to ``/local/software/foo/1.7``, ``revision`` to 1, and the
package had prereqs compiler and mpi, and gnu/9.1.0 and openmpi/4.0 were loaded, the
resulting path would be ``/local/software/foo/1.7/1/gnu-9.1.0-openmpi-4.0``.  

The modulefile actually will test for the existance of that directory, and if not found will
return an error to the that the package was not built for that combination of prereqs.
You either need to install your packages using the above directory schema, or create
symlinks linking that scheme to where you actually install the packages.

Examples
--------

We now look at the example modulefiles for flavours.  To use the examples,
you must

#. Have Flavours installed.  **NOTE** these examples will NOT work without 
   the Flavours installed.
#. Set (and export) MOD_GIT_ROOTDIR to where you git-cloned the modules source
#. Do a ``module purge``, and then set your MODULEPATH 
   to ``$MOD_GIT_ROOTDIR/doc/example/compiler-etc-dependencies/flavours``

We start with the ``module avail`` command:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules4.3.1/modavail.out

We note that we only see the package names and versions; e.g. foo/2.4, without any mention
of the compilers and MPI libraries for which it is built.  This terser stype was an intentional
design goal of the authors.  Also of note are the intelmpi and simd packages.  The Flavours
approach relies on seeing what modules have been loaded previously in order to determine what
'flavor' of the requested package should be loaded.  To support the different builds of ``bar``
which depend on the CPU vectorization commands supported, we need to add a "dummy" package ``simd``.
The module definition is quite trivial; a simple stub file like

.. include:: ../../example/compiler-etc-dependencies/flavours/simd/avx
    :literal:

and the main content in the ``common`` file:


.. include:: ../../example/compiler-etc-dependencies/flavours/simd/common
    :literal:

Basically it just declares a help procedure and whatis text.  This way, an user can
load the appropriate simd module to control which variant of bar they will get.  The
only interesting aspect is that near the beginning of the file we do a 
``package require flavours`` and ``flavours init``, and add a  ``flavours cleanup``
near the bottom.  The lines at the beginning instruct Tcl command to load the Flavours
package, and then initialize the package.
The ``flavours cleanup`` is required so that if the simd module is switched out,
any modulefiles that depend on it get reloaded.

In our example, we assumed that the Intel MPI libraries are automatically set up properly if one
were to load the ``intel`` module, and we assumed the Intel MPI libraries were not supported
for either the GNU or PGI compilers.  However, we also wished to allow for ``foo`` to 
be used without any MPI support.  So we need a way to distinguish if someone wants to
use an Intel compiler build of ``foo`` without MPI or with the Intel MPI libraries.  Our
choice for this example was to require one to explicitly module load ``intelmpi`` if one
wished to use the Intel MPI variant --- we do not bother with a real version number because
assuming the version is determined by the version of ``intel`` (the Intel Parallel Studio version).
So the intelmpi modulefile is similar to the simd modulefiles, a dummy modulefile.  Again,
it includes the ``flavours init`` and ``flavours cleanup`` wrapping to ensure proper reloading
of dependent modules should it be switched out.

If you were to support Intel MPI for non-intel compilers, you could create your intelmpi
modulefiles as usual, and then add a ``default`` or ``intel`` "dummy" version to use the
version that is part of the ``intel`` Parallel Studio.  Or you could separate the intelmpi 
bits from the ``intel`` modulefile so both non-intel and intel compilers need to explicitly
module load intelmpi.

The modulefiles for the various compilers are all pretty much standard, except for the 
same three ``flavours`` lines as the simd modulefile: ``package require flavours``, 
``flavours init``, and ``flavours cleanup``.  These are required to
ensure dependent modulefiles get reloaded if the compiler is switched out.
We also note that the modulefile for the GNU Compiler Collection is referred to as ``gnu``, not ``gcc`` 
(this is due to how the ``compiler`` class is defined in ``flavours.tcl``).

With the openmpi and mvapich MPI libraries, things start to get interesting.  These all
should setup the environment for a different build depending on the compiler loaded.  The
real work is done in the ``common`` tcl file, as shown below:

.. include:: ../../example/compiler-etc-dependencies/flavours/openmpi/common
    :literal:

Like the previous cases, the file starts with the Tcl command to load the
package, followed by the ``flavours init`` command.

The ``flavours prereq`` command states that this package requires a compiler to have been previously
loaded, and that the path to the specific build to use will depend on that.  We note the use
of the ``-class`` parameter; the exact definition of the compiler class is in the ``compiler``
field of the Tcl associative hash ``_class`` defined in ``flavours.tcl``.

The ``flavours root`` sets the root directory of where the builds for this package is installed.
We use the MOD_GIT_ROOTDIR environment variable for convenience in this example, but in production
you would generally hardcode a path.  The result of all the directives is that the build will be
found in a path named after the compiler (since in this case there is only one ``flavour prereq``);
e.g. for gcc version 9.1.0, we expect to find the build in ``$swroot/openmpi/4.0/1/gnu-9.1.0``.
If you do not use that naming convention for your installation directories, you can use symlinks
to fake it.

The ``flavours path`` command in the ``setenv MPI_DIR`` statement sets MPI_DIR to the aforementioned
build path.  The ``flavours prepend-path`` commands prepend to the environmental variable specified
by the first argument the result of prepending the ``flavours path`` to their second argument.  E.g.,
the first such, assuming openmpi version 4.0 was requested and gnu/9.1.0 loaded, would be basically
the same as a standard Modules ``prepend-path PATH $swroot/openmpi/4.0/1/gnu-9.1.0/bin`` command.

The following shows how this would appear to the user:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules4.3.1/ompi-loads1.out
    :literal:

Here we note that once a compiler is loaded, the PATH and the other environmental 
variables are set appropriately to point to the bin dir for the particular build of 
openmpi/4.0, as evidenced by the output of our fake mpirun command.  At the end, we attempt
to load openmpi/4.0 for gnu/8.2.0, and receive an error because our fake SW library does not contain
a matching build.  This is determined from the ``flavours path``; if the
path does not exist (in this example ``$swroot/openmpi/4.0/1/gnu-8.2.0``) it will
abort in this fashion.  

In the above, we have explicitly unloaded openmpi, switched the compilers, and
then reloaded openmpi.  A nice feature of Flavours is that it can handle the 
switching out of compilers or other modulefiles which other modulefiles depend on,
as:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules3.2.10/ompi-switch.out
    :literal:

Note that when we switched between the pgi and intel compilers above, Flavours
automatically "unloaded" and "reloaded" the openmpi module.  This happens in
the ``flavours cleanup`` portion of the compiler modulefiles, and is due to
``openmpi`` declaring a ``flavours prereq`` on the compiler class.
**NOTE**: The above behavior with switch was done with version 3.2.10
of Environmental Modules; it does not* appear to work with 4.3.1. 

We also note that if we attempt to load openmpi without having previously loading a compiler,
we will get an error:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules4.3.1/ompi-defaults.out
    :literal:

In particular, there is no support for a "default" compiler; if e.g. you wished to make the
distribution supply gcc a default, you will need to do a module load of that compiler (possibly
a dummy modulefile like simd/intelmpi if the compiler is already in the user's path)
in your user's start up dot files or similar.  We also note that there is no additional 
intelligence in the version defaulting --- in the last example, we have gnu/8.2.0 loaded and if
we try to load openmpi without specifying a version, it defaults to version 4.0
as that is the latest version of openmpi without regard for the fact that there
is no build of openmpi version 4.0 for gnu/8.2.0 (but there is such for openmpi/3.1).

The situation for ``foo`` is more complicated, as it depends both on the compiler and
optionally on the MPI library.  But with Flavours, the modulefile is only slightly more 
complicated, e.g. for the common file is:

.. include:: ../../example/compiler-etc-dependencies/flavours/foo/common
    :literal:

Basically, the main difference is the addition of the 
line ``flavours prereq -optional -class mpi``.
This instructs Flavours that there is an additional, optional prereq.  The
order of the prereq lines matter, as that controls the resultant ``flavors path``.
With the current configuration, assuming ``gnu/9.1.0`` and ``openmpi/4.0`` were loaded,
the path would become ``$swroot/foo/2.4/1/gnu-9.1.0-openmpi-4.0``.  If the order were
reversed, the ``openmpi-4.0`` would precede the ``gnu-9.1.0``.  Because the MPI requirement
is optional, if ``gnu/9.1.0`` was loaded and no MPI library loaded, the path would
evaluate to ``$swroot/foo/2.4/1/gnu-9.1.0``.

We show how it works below:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules4.3.1/foo-loads.out
    :literal:

So basically, if the user loads a compiler, the 
the environment variables (PATH, etc) are set up for the correct build of foo.
If no MPI library was loaded, a version of foo built without MPI will be loaded,
otherwise, a version of foo built with the loaded MPI library will be loaded.
This is shown by the output of the ``foo`` command.  Note
also how we use the dummy ``intelmpi`` package to indicate a desire for the
intelmpi enabled version.  

The 3.x version of Environmental Modules supports using the switch command on
either the compiler or MPI library, and will result in reloading of foo and the MPI
library.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules3.2.10/foo-switch.out
    :literal:

In particular note the final case, wherein we load intel/2019 and foo, getting the
version of foo built without MPI. When we subsequently load openmpi, foo is reloaded
to be the openmpi version (this is because the hooks to reload foo are in the ``flavours cleanup``
part of the openmpi modulefile, and foo declared its optional dependency on MPI).
Also, we don't bother showing it, but if you were to attempt to load foo without 
at least a compiler loaded, it would display an error.  

Our final example for flavours is the ``bar`` command.  Here in addition to the
compiler dependency, we have versions for different SIMD vectorization supported.
Again, the difference in the modulefile is small, e.g.

.. include:: ../../example/compiler-etc-dependencies/flavours/bar/common
    :literal:

Basically, the optional ``flavours prereq`` on the mpi class from the ``foo`` package
is replaced by a (mandatory) ``flavours prereq`` on the ``simd`` dummy package.
We note that Flavours package knows nothing about our ``simd`` dummy package until
we add it as a prereq for bar.  (This is in contrast to the compiler and mpi classes).
Usage would be like:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/flavours/modules4.3.1/bar-loads.out
    :literal:

Here we note that as both the compiler and simd prereqs are non-optional, it complains
unless both have been previously loaded.  When both have been loaded, the PATH and
other environmental variables are set appropriately for the requested build; and if
it does not exist and error is produced.

Summary of Flavours
-------------------

* It is an external extension to Environmental Modules, requiring additional installation steps.
* The git repository appears to have been last updated in 2013; although I believe this means
  that it has not been updated for Environmental Modules 4.x, my (albeit minimal) experimentation
  indicates that it still works, with the exception of automatic reloading of a module if any of
  the modules it depends on are switched.  (All the examples with a mod431-flavours prompt were
  done using Environmental Modules 4.3.1 with flavours added; i.e. everything but the ones 
  demonstrating the use of ``module switch`` on a compiler, etc. to show reload of the 
  modulefiles depending on it).   However, the Flavours package does not appear to be actively supported.
* The Flavours package fully supports the ``module switch`` syntax, with the switching
  out of a dependency (e.g. a compiler) causing the reload of all modulefiles depending on it.
  At least for Environmental Modules 3.x; I have not had success with that on 4.x.
* The syntax for modulefiles is elegant, and one can easily extend the basic compiler dependency
  modulefile to add additional dependencies.  Even for packages/dummy packages that the Flavours
  extension knows nothing about (e.g. simd in the above example).
* The Flavours package will provide a shorter module avail output, only e.g. giving package name and
  version and not listing a separate modulefile for each combination of package, version, compiler+version,
  MPI library+version, etc.  
* The Flavours package will fail with an error message if user tries to load a package which was
  not built for the values of the depenency packages loaded.
* The Flavours package will fail to load with an error message if any dependent package is not
  already loaded.  In particular, it will not attempt to default these.
* The Flavours package does not include any mechanism for more intelligent defaulting.  I.e., if an
  user requests to load a package without specifying the version desired, the version will be defaulted
  to the latest version (or whatever the ``.modulerc`` file specifies) without regard for which versions
  support the versions of the compiler and other prereq-ed packages the user has loaded.  While one
  could write custom .modulerc files for such, Flavours does not provide any tools for simplifying
  such.


-------------------
Home-brewed flavors
-------------------

Although the "Flavours" extension described above has an elegance about it,
one can achieve much of the same functionality in modulefiles using standard
Environmental Modules and Tcl commands.  This can be facilitated by the definition
of some useful Tcl procedures.  For lack of a better name, we will refer to
this strategy as "home-brewed flavors".

Implementation
--------------

This strategy just makes use of standard Environmental Modules and Tcl procedures
to query what modules of a given type are loaded and to construct the path to the
software package accordingly.  To avoid needless (and error prone) repetition of
code, we collect these into several Tcl procedures of our own.  Ideally, these
should be placed in a site configuration Tcl file and exposed to modulefiles
as explained in the cookbook ``Exposing Procedures and Variables to Modulefiles``.
However, to avoid the need for that in these examples, we instead have placed them
into a file and use the ``MOD_GIT_ROOTDIR`` to locate and source that file in the
relevant modulefiles.  (Actually, we have a single tcl file that is sourced both 
for this and some other strategies, and it sources several files so that we can
break up the discussion of the the Tcl procedures.  All of that is just for the
purposes of this cookbook; normally you just put the procedures you need in the
one site config file).

We discuss the various Tcl procedures here, as they are what provide most of the
functionality.  We start with the routines for generic loaded modules:

.. include:: ../../example/compiler-etc-dependencies/tcllib/LoadedModules.tcl
    :literal:

This defines the two Tcl procedures:

* **GetLoadedModules** : this returns the list of loaded modules, from the LOADEDMODULES
* **GetTagOfModuleLoaded** : this takes as argument the base name of a package,
  and returns the first full spec for the matching package, or an empty
  string if no matching package found.

The Tcl procedure **GetTagOfModuleLoaded** can be used to find out what version
of a given package is loaded, and is enough for many packages.  However, for
compilers, and similar, a bit more is needed.  For compilers:

.. include:: ../../example/compiler-etc-dependencies/tcllib/CompilerUtils.tcl
    :literal:

We defined four procedures above:

* **GetDefaultCompiler** : this simply returns the name of our default compiler, which for
  this example is gcc/8.2.0
* **RequireCompiler** : this simply does a module load on the specified compiler.  
  It is kept as a separate procedure just in case you wish to intercept and prevent
  the loading of the default compiler (e.g. because no modulefile exists for it).
  In our example, there is a modulefile for it and so it is just a wrapper for ``module load``.
* **GetKnownCompilerFamilies** : this simply returns a Tcl list of known
  compiler families.
* **GetLoadedCompiler**: this is the procedure that does the main work, and is 
  described in detail below.

The **GetLoadedCompiler** procedure basically checks if any packages matching
the names in **GetKnownCompilerFamilies** have been previously loaded.  If so,
it returns the modulefile specification for the first one found, and returns.
If not, if ``pathDefault`` is set and there is a recognized compiler name and version
in the last two components of the module specification, it will return 
that compiler. Otherwise, if the optional flag ``useDefault`` is set, it will return the
value from **GetDefaultCompiler**.  If all else fails, returns the empty string.

If the optional parameter ``loadIt`` is set, if a compiler was defaulted (i.e.
not returned because it was already loaded), the procedure will call ``RequireCompiler``
to module load it.  

If the optional parameter ``requireIt`` is set, we invoke ``prereq`` on the compiler
found before returning.

A similar set of procedures exist for the MPI libraries, namely:

.. include:: ../../example/compiler-etc-dependencies/tcllib/MpiUtils.tcl
    :literal:

The three procedures here are analogues of the compiler versions:

* **RequireMPI** : this basically does a module load of the specified MPI library.  It
  has some added logic so that it will not do a module load if the MPI library is ``nompi``.
  Also, if the optional parameter ``noLoadIntel`` is set, if the MPI library is ``intelmpi``
  (or a variant of that name) and the loaded compiler in ``intel``, we assume that no
  additional module needs to be loaded.  For this strategy, we want to load ``intelmpi``
  modules, because, just like in the ``Flavours`` strategy, we need to provide dummy
  ``intelmpi`` modules to allow one to request the use of the Intel MPI library.
* **GetKnownMpiFamilies** : this returns a list of known MPI library family names.
  Used in **GetLoadedMPI**
* **GetLoadedMPI** : This is the analogue of **GetLoadedCompiler**.  If an MPI library is
  loaded, it will return the name of that module.  If the optional ``requireIt`` flag
  is set, it will do a ``prereq`` on the MPI library before returning.  The first optional
  argument, ``useIntel``, indicates whether this module should return ``intelmpi`` if no
  MPI library is loaded but an Intel compiler is loaded.

The modulefiles for the compilers are basically standard; unlike the 
``Flavours`` strategy there is nothing special needed in these.  Likewise
for the dummy ``simd`` and ``intelmpi`` modules (the latter is only this
basic because we assume intelmpi is only available if an Intel compiler
is loaded.  If one allowed for intelmpi with other compilers, it would 
more closely resemble the other MPI libraries).

The interesting bit begins with the openmpi and mvapich modulefiles.  These
both depend on the compiler, we show the main part of the openmpi modulefile
below:

.. include:: ../../example/compiler-etc-dependencies/homebrewed/openmpi/common
    :literal:

We begin by sourcing the ``common_utilities`` file which defined the previously
described Tcl procedures.  Normally it is recommended that you put those
procedures in a site config Tcl script and expose them to the modulefiles
using the techniques described in the cookbook 
``Exposing Procedures and Variables to Modulefiles``.  Even if you opt
against that and decide to source a Tcl file, it is recommended to hard code
the path.

The next interesting bit comes when we set the local Tcl variable ``ctag``
by calling the ``GetLoadedCompiler`` procedure.  We allow the procedure to
default the compiler, and because we have a default compiler defined we
should always get a value.  (If no default compiler was defined, one would
have to handle the error if no compiler was loaded/defaulted.)  We then use
the value of ``ctag`` to set the path to the build of the package.  To ensure
that the package is built for this compiler, we do a quick check that the
package installation path exists.  

The modulefile for ``foo`` is a bit more complex:

.. include:: ../../example/compiler-etc-dependencies/homebrewed/foo/common
    :literal:

The main difference between this modulefile, depending on both compiler and
optionally MPI, and the openmpi modilefile above, is that in addition to
detecting which compiler is loaded, we call ``GetLoadedMPI`` to determine
the MPI library which was loaded, and use both of them in constructing the
prefix to the installed foo.


Examples
--------

The ``homebrewed flavors`` strategy behaves much like the ``Flavours``
strategy in practice.  The module avail command,

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/modavail.out
    :literal:

looks basically the same, showing the a concise listing of packages and 
versions without information on the compilers and MPI libraries they were
built with.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/ompi-loads1.out
    :literal:

Again, once a compiler is loaded, loading openmpi will set the PATH, etc. for
the correct build of openmpi, as evidenced by the output of the fake
mpirun command.  Notice that the ``module list`` command only shows
the version of openmpi loaded, and contains no information about what
compiler it was built with (you just have to assume it matches the loaded
compiler).  And again we note that if one attempts to load a version
of openmpi (e.g. 4.0) that was not built for the specified compiler (e.g.
gcc/8.2.0), an error is generated.

Unlike in ``Flavours``, we did not put any code in the modulefiles to cause
dependent modulefiles to be reloaded if a module they depend on gets switched
out.  However, the automated module handling in Environmental Modules 4.2.0
does just that, so we can do something like:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/ompi-switch.out
    :literal:

Note that we include the ``--auto`` option to the module command; the 
automatic module handling is still *experimental* and disabled by default and
this flag is one way to enable it.  If one were to run the switch without the
automated module handling (i.e. an earlier version of modules or with the 
option not enabled), the modulefile for the compiler will be switched out,
but that for openmpi would not, leading to a mismatch, as indicated in the
snippet below (using Environmental Modules 3.2.10):

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules3.2.10/ompi-switch.out
    :literal:

And the ``module list`` command really does not inform you of this (other than perhaps
by the fact that the openmpi module is after the foo module).  We note that the modulefile is able to 
default the compiler, so when we attempt to load openmpi without having
previously loaded a compiler, as in

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/ompi-defaults.out
    :literal:

it will default to the default compiler, gcc/8.2.0.  Note however, that if
one does not specify version 3.1 of openmpi, it will still default to 4.0
and fail to load as there is no build of openmpi/4.0 for gcc/8.2.0.

The situation is similar for foo:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/foo-loads.out
    :literal:

Again, one can load a compiler without an MPI library to get the non-MPI version
of foo, or a compiler and MPI library to get the MPI version.  The dummy
intelmpi modulefile is used to allow one to indicate that the Intel MPI library
is desired.  The automatic module handling can again allow the switch 
functionality work properly, as in

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/foo-switch.out
    :literal:

Here we note a deficiency in the switch support as compared to ``Flavours``.  In the last example
after loading intel/2019 and foo, we have the non-MPI build of foo as expected.  However, upon
subsequently loading the openmpi module, we still have the non-MPI version of foo loaded, as evidenced
by the output of the fake foo command.  I.e., the foo package was *not* automatically reloaded, as 
there was no prereq in the foo modulefile on an MPI library (as in the non-MPI build there is no MPI
library to prereq).  Also note that module list does not really inform one of this fact.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/foo-defaults.out
    :literal:

Above, we see once more that the compiler can be defaulted, but that the 
defaulting mechanism is not smart enough to default the version of foo based
on the compiler loaded (or defaulted to).

The situation with bar is basically the same; with a compiler and simd
module loaded, the environment for the appropriate build of bar is loaded
when you module load bar.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-loads.out
    :literal:

And an error is generated if there is no build for that combination of 
compiler and simd.  The automatic handling of modules again allows the
switch command to work as expected:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-switch.out
    :literal:

and both the simd level and compiler can be defaulted, but one still has
to choose a version of bar which supports the defaults.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-defaults.out
    :literal:

Summary of homebrewed flavors strategy
--------------------------------------

* The automated module handling feature (introduced in Environmental Modules
  4.2.0) allows for the switching out of a dependency (e.g. a compiler) 
  to cause the reload of all modulefiles depending on it.  Without the
  automated module handling (as is default for 4.x, and the only option for
  3.x), the switching of a compiler only changes the compiler and leaves the
  modulefiles that depend on the compiler unchanged.
* The various Tcl procedures make
  it somewhat easy to determine which compiler, MPI, etc. modules have been
  loaded and set the paths appropriately.  Not as elegant or easy to use
  as ``Flavours``, but not difficult
* Like the Flavours package, the module avail output is concise, only e.g. 
  giving package name and version rather than listing a separate modulefile 
  for each combination of package, version, compiler+version,
  MPI library+version, etc.  
* Modules will fail with an error message if user tries to load a package 
  which was not built for the values of the depenency packages loaded.
* In general, a module will fail to load with an error message if any 
  dependent package is not already loaded.  However, it has a limited ability
  for defaulting the compiler, etc.
* It does not include any mechanism for more intelligent defaulting.  I.e., if 
  an user requests to load a package without specifying the version desired, 
  the version will be defaulted to the latest version (or whatever 
  the ``.modulerc`` file specifies) without regard for which versions
  support the versions of the compiler and other prereq-ed packages the user 
  has loaded.


-----------------------
Modulerc-based strategy
-----------------------

The previous two strategies used additional code in the modulefile to
determine which compiler, etc. was loaded and adjust the values for
PATH, etc. accordingly.  The ``modulerc-based`` strategy instead uses
``.modulerc`` files to direct the module command to the proper modulefile
depending on what compiler, etc. was previously loaded.  Because of
this, there are a number of differences in behavior and what is seen
by the user, most notably many more modulefiles.  Whether this is good
or bad is a matter of taste.

Implementation
--------------

Whereas the ``homebrewed flavors`` strategy had the modulefile invoke
a Tcl procedure to determine which, if any, version of a module like a compiler
was loaded and then adjust paths, the ``modulerc-based`` strategy instead
uses the same Tcl procedures to default the modulefile which will be loaded.
This implies that there is a distinct modulefile for every build of the package,
and an immediate consequence is that this strategy has many more modulefiles
than the others.  We make use of the techniques in the cookbook 
``Tips for Code Reuse`` to reduce the total amount of code; the actual modulefiles
for each build are typically small stubfiles defining a couple of Tcl variables
and then sourcing a ``common`` script (unique to each package) which does all
the real work.  The ``.modulerc`` files themselves are not trivial, but these
can generally be written in a generic fashion, usable by multiple packages,
and can just be symlinked to the appropriate locations.  

The modules will be named with components for the different dependencies,
so the one for openmpi version 4.0 built with gcc version 9.1.0 would
be ``openmpi/4.0/gcc/9.1.0``; similarly the module for foo version 1.1
built for pgi version 18.4 and mvapich 2.1 would be
``foo/1.1/pgi/18.4/mvapich/2.1``.  

We define five such files which can be linked as ``.modulerc``:

We define two such files which can be linked in the module tree
at various places at ``.modulerc`` for defaulting the compiler.  One to
default to the family portion of the compiler (e.g. gcc, intel, or pgi),
and one for the version.  For the family portion of the compiler, 
we have the file ``modulerc.select_compiler_family`` as below:

.. include:: ../../example/compiler-etc-dependencies/modrc_common/modulerc.select_compiler_family
    :literal:

The file starts by sourcing a set of useful Tcl procedures. For the purpose
of the example for this cookbook this is done based on the MOD_GIT_ROOTDIR 
environmental variable.  If you were to use this in production, it is 
recommended that the Tcl procedures be placed in a site configuration script
and exposed to modulefiles via the techniques described in the cookbook
``Exposing Procedures and Variables to Modulefiles``.  At the minimum, it is
recommended to hardcode the path to the ``common_utilities.tcl`` file.

The modulerc script then determines the directory it is in using the
Tcl variable ``ModulesCurrentModulefile``.  It then uses the
``GetLoadedCompiler`` Tcl procedure (as was discussed in the section
on the ``homebrewed`` strategy.  We then parse the resulting module
name into family and version pieces (we will discuss the procedure
``GetPackageFamilyVersion`` later; for now suffice to say it takes
a module name and returns a Tcl list with family and version).

We do some trickery to support either gcc or gnu as family names for
the GNU compiler suite, and then see if there is a directory or modulefile
underneath the directory containing the .modulerc file, and if so defaults
to it.  For this purpose, we use the Tcl procedure ``FirstChildModuleInList``
(defined in ``common_utilities.tcl``).  This and a related procedure are
defined as:

.. include:: ../../example/compiler-etc-dependencies/tcllib/ChildModules.tcl
    :literal:

and basically make use of the Tcl variable ``ModulesCurrentModulefile``.  They
are limited, however, in that they will not work properly if the module is 
split across multiple modulepaths.  That is, ``ChildModuleExists`` and
``FirstChildModuleInList`` will only detect children in the same directory
as the modulerc file they are called from; e.g., if two paths in the MODULEPATH
both have directories for openmpi, one with an intel subdirectory and one
with a pgi subdirectory and the modulerc invoking ``ChildModuleExists``, the
ChildModuleExists procedure will not see the intel directory.  

The ``modulerc.select_compiler_version`` file is similar,

.. include:: ../../example/compiler-etc-dependencies/modrc_common/modulerc.select_compiler_version
    :literal:

Again, we source the ``common_utitilies.tcl`` file and use 
``ModulesCurrentModulefile`` to get the directory in which the .modulerc 
script resides.  It thens uses ``GetLoadedCompiler`` to determine what
if any compiler was loaded.  If one was, we split into family and version,
and ensure that the directory containing the .modulerc file matches the
family name.  If so, it checks if there is a directory or modulefile in that
directory matching the version name, and if so defaults to it.

For both of the .modulerc scripts we examined, we note that in case of
errors, etc., the script just exits without defaulting.  One might be 
tempted to have the .modulerc script actually return an error in such
cases (perhaps using ``module-info mode`` to only have it output during
load operations).  This, however, runs into issues:

*  For Environmental Modules 3.x: for some reason, when modulecmd processes
   .modulerc scripts, ``module-info mode load`` always returns true.  Because
   of this, users would get spurious errors when doing a ``module avail``
   if the .modulerc scripts errored, because they all get processed regardless
   of what compiler is loaded.
*  For versions 4.x: the modulecmd process tends to process all .modulerc
   files underneath the package root during a load, which will similarly
   generate spurious errors if the .modulerc scripts throw errors.

Because of this, if an user explicitly requests a modulefile that conflicts
with the loaded compiler (e.g. the user does a ``module load pgi/19.4`` 
followed by a ``module load openmpi/4.0/intel/2019``), the modulefile needs
to detect this and error appropriately.  A similar situation can happen if
one of the .modulerc scripts fail to default, presumably because there is no
apropriate build for the requested package; the modulecmd will default to
something, but likely not what is wanted.  To facilitate this, we define
the Tcl procedure ``LoadedCompilerMatches``:

.. include:: ../../example/compiler-etc-dependencies/tcllib/LoadedCompMatches.tcl
    :literal:

The procedure takes a string for the family and version of the compiler
that the modulefile expects, and ensures that if a compiler is loaded, they
match.  If they match, the procedure just returns, and if not, it spits out
an error indicating a compiler mismatch.  It also takes optional boolean flags:
``requireIt`` to determine if the procedure should ``prereq`` the compiler 
before returning, and ``loadIt`` to determine if, when no compiler was
previously loaded, whether the procedure should load it (using
``RequireCompiler`` so it can properly handle the default compiler specially
if needed).  The ``requireIt`` flag should generally be set for Environmental
Modules 4.x (as that will allow the automatic handling of modules to 
properly recognize dependencies, even though as we will see that does not
work too well for this strategy as yet), and should not be set for versions
3.x (as the loading of modules with ``loadIt`` does not occur until *after*
the ``prereq``, causing module loads to fail).

The resulting modulefile for something depending only on the compiler,
using mvapich as an example, then would look like:

.. include:: ../../example/compiler-etc-dependencies/modulerc/mvapich/common
    :literal:

Basically, the modulefile knows what compiler it wants (in the above example,
that is set by the stubfile and passed as a Tcl variable into the common
script above), and then calls the ``LoadedCompilerMatches`` procedure
above to ensure the loaded compiler matches what the modulefile wants (and
to load it if no compiler is loaded).

So the mvapich directory in the MODULEPATH consists of subdirectories for
each version of mvapich supported (e.g. 2.1 and 2.3.1).  In each of the
version subdirectories, we symlink ``modulerc.select_compiler_family`` as
``.modulerc``, and create an additional layer of subdirectories, one for
each compiler family for which the version of mvapich is built (e.g.
gcc, intel, pgi).  In each compiler family directory under each mvapich 
version, we symlink ``modulerc.select_compiler_version`` as ``.modulerc``,
and create a stub modulefile named for the compiler version.  The stub
modulefile then defines some Tcl variables for the version of mvapich
and the compiler family/version, and sources the ``common`` file above.
E.g., for ``mvapich/2.3.1/intel/2019``, the stubfile would look like

.. include:: ../../example/compiler-etc-dependencies/modulerc/mvapich/2.3.1/intel/2019
    :literal:

So the mvapich directory in MODULEPATH would have a structure like

|  mvapich
|      \|- common (shared parts sourced by stub modulefiles)
|      \|- 2.1
|      |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|      |  \|- gcc
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 8.2.0 (stub modulefile)
|      |  |  \|- 9.1.0 (stub modulefile)
|      |  \|- intel
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 2018 (stub modulefile)
|      |  |  \|- 2019 (stub modulefile)
|      |  \|- pgi
|      |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |     \|- 18.4 (stub modulefile)
|      |     \|- 19.4 (stub modulefile)
|      \|- 2.3.1
|      |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|      |  \|- gcc
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 9.1.0 (stub modulefile)
|      |  \|- intel
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 2019 (stub modulefile)
|      |  \|- pgi
|      |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |     \|- 19.4 (stub modulefile)

With this directory structure, an user can load a compiler and then
module load a specific version of mvapich, and if a build of that version of
mvapich exists for that compiler, the environment will be set up properly,
and otherwise an error reported.  However, if the user module loads
mvapich without specifying a version, it will simply default the version
to the latest version of mvapich available, regardless of whether there
is a build of that version of mvapich for the loaded compiler.  Ideally,
if one issues a module load of a package without specifying a version, it
should load the latest version available that is compatible with any loaded
compilers or other modules.  

A simple change can enable that.  We add a symlink to 
``modulerc.select_compiler_family`` as ``.modulerc`` directly under the 
mvapich directory, and create an additional subdirectory under the mvapich
directory for each compiler family.  We symlink 
``modulerc.select_compiler_version`` as ``.modulerc`` under each compiler
family subdirectory, along with a subdirectory for each version of that
compiler family that a version of mvapich is built for.  We then symlink
the various stub modulefiles under the ``mvapich/VERSION``  into the 
corresponding ``mvapich/COMPILER_FAMILY/COMPILER_VERSION`` directory, with
the symlink's name being the mvapich version number.  So the mvapich
directory tree will now look like:

|  mvapich
|      \|- .modulerc (symlink to modulerc.select_compiler_family)
|      \|- common (shared parts sourced by stub modulefiles)
|      \|- 2.1
|      |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|      |  \|- gcc
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 8.2.0 (stub modulefile)
|      |  |  \|- 9.1.0 (stub modulefile)
|      |  \|- intel
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 2018 (stub modulefile)
|      |  |  \|- 2019 (stub modulefile)
|      |  \|- pgi
|      |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |     \|- 18.4 (stub modulefile)
|      |     \|- 19.4 (stub modulefile)
|      \|- 2.3.1
|      |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|      |  \|- gcc
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 9.1.0 (stub modulefile)
|      |  \|- intel
|      |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  |  \|- 2019 (stub modulefile)
|      |  \|- pgi
|      |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |     \|- 19.4 (stub modulefile)
|      \|- gcc
|      |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  \|- 8.2.0
|      |   | \|- 2.1 (symlink to ../../2.1/gcc/8.2.0 stub modulefile)
|      |  \|- 9.1.0
|      |     \|- 2.1 (symlink to ../../2.1/gcc/9.1.0 stub modulefile)
|      |     \|- 2.3.1 (symlink to ../../2.3.1/gcc/9.1.0 stub modulefile)
|      \|- intel
|      |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  \|- 2018
|      |   | \|- 2.1 (symlink to ../../2.1/intel/2018 stub modulefile)
|      |  \|- 2019
|      |     \|- 2.1 (symlink to ../../2.1/intel/2019 stub modulefile)
|      |     \|- 2.3.1 (symlink to ../../2.3.1/intel/2019 stub modulefile)
|      \|- pgi
|      |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|      |  \|- 18.4
|      |   | \|- 2.1 (symlink to ../../2.1/pgi/18.4 stub modulefile)
|      |  \|- 19.4
|            \|- 2.1 (symlink to ../../2.1/pgi/19.4 stub modulefile)
|            \|- 2.3.1 (symlink to ../../2.3.1/pgi/19.4 stub modulefile)
|      |   | \|- 2.1 (symlink to ../../2.1/intel/2019 stub modulefile)
|      |   | \|- 2.3.1 (symlink to ../../2.3.1/intel/2019 stub modulefile)


When one attempts to module load mvapich without specifying a version,
the .modulerc file will default to the family of the loaded compiler (or
the default compiler if none loaded).  It then descends into the corresponding
compiler family directory, where the .modulerc there will default to the
version of the loaded or defaulted compiler.  After descending into the
compiler version directory, there is no .modulerc, so the standard modulecmd
defaulting mechanism will select the latest version.

So PACKAGE/PKGVERSION/COMPILER_FAMILY/COMPILER_VERSION and
PACKAGE/COMPILER_FAMILY/COMPILER_VERSION/PKGVERSION refer to the same 
modulefile and the same build.  E.g.  ``mvapich/2.3.1/pgi/19.4`` and 
``mvapich/pgi/19.4/2.3.1`` both refer to version 2.3.1 of mvapich, built
for version 19.4 of the PGI compiler suite.  In general, we allow for 
modules to be named with multiple dependency packages and/or flags.
This is the reason for the procedure ``GetPackageFamilyVersion`` ---
it splits a module name into components and takes the first component
as the family name.  It then examines the second component, and if it
matches the name of a known package (like a compiler family), it uses
the last component as the version.  Otherwise, the second component is
assumed to be the version.  The code is as follows:

.. include:: ../../example/compiler-etc-dependencies/tcllib/GetFamVer.tcl
    :literal:

Similarly, there are two corresponding .modulerc scripts for defaulting 
the MPI library: one to default the family (e.g. openmpi, mvapich, intelmpi) 
and one to default the version.  The family version, shown below:

.. include:: ../../example/compiler-etc-dependencies/modrc_common/modulerc.select_mpi_family
    :literal:

is similar to the corresponding compiler version, but contains additional
logic to handle the intelmpi case.  We treat intelmpi specially, because in
our example here we assume the environment for Intel MPI is setup properly
when the user loads the intel module.  If no MPI library is explicitly loaded,
but the intel module is loaded, than we look for a subdirectory named
intelmpi (or one of its aliases) and default to it if it exists.  Otherwise,
if no MPI module is loaded, it looks for and will default to a directory
or modulefile named nompi if it exists.

The ``modulerc.select_mpi_version`` script is also similar to its compiler
counterpart,

.. include:: ../../example/compiler-etc-dependencies/modrc_common/modulerc.select_mpi_version
    :literal:

It checks if any MPI library was explicitly loaded, and if so it checks
if the family of the loaded MPI module matches the name of the parent directory
of this .modulerc file.  If so, it checks for the existence of a subdirectory
matching the version, and if found it defaults to it.  There is no special
handling needed for the ``nompi`` case, as since there is no version attached 
to the MPI library in the nompi case, this .modulerc is not present there.
Similarly, for the case of Intel MPI when the Intel compiler suite is loaded, we
expect the Intel MPI version to be that from the Intel compiler suite, so
no version or this .modulerc is needed.  

As the MPI modules depend themselves on the compiler, it is assumed that 
any package depending on the MPI libraries also depend on the compiler,
and so will have a structure like the one described below for foo

|  foo
|  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  \|- common (shared parts sourced by stub modulefiles)
|  \|- 1.1
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  |  \|- 8.2.0 
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |       \|- nompi (stub modulefile)
|  |  |       \|- mvapich
|  |  |       |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       |    \|- 2.1 (stub modulefile)
|  |  |       \|- openmpi
|  |  |            \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |            \|- 3.1 (stub modulefile)
|  |  \|- intel
|  |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  |  \|- 2018
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |       \|- nompi (stub modulefile)
|  |  |       \|- intelmpi (stub modulefile)
|  |  |       \|- mvapich
|  |  |       |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       |    \|- 2.1 (stub modulefile)
|  |  |       \|- openmpi
|  |  |            \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |            \|- 3.1 (stub modulefile)
|  |  \|- pgi
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 2018
|  |          \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |          \|- nompi (stub modulefile)
|  |          \|- mvapich
|  |          |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |          |    \|- 2.1 (stub modulefile)
|  |          \|- openmpi
|  |               \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |               \|- 3.1 (stub modulefile)
|  \|- 2.4
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  |  \|- 9.1.0 
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |       \|- nompi (stub modulefile)
|  |  |       \|- mvapich
|  |  |       |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       |    \|- 2.3.1 (stub modulefile)
|  |  |       \|- openmpi
|  |  |            \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |            \|- 4.0 (stub modulefile)
|  |  \|- intel
|  |  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  |  \|- 2019
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |       \|- nompi (stub modulefile)
|  |  |       \|- intelmpi (stub modulefile)
|  |  |       \|- mvapich
|  |  |       |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       |    \|- 2.3.1 (stub modulefile)
|  |  |       \|- openmpi
|  |  |            \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |            \|- 4.0 (stub modulefile)
|  |  \|- pgi
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 19.4
|  |          \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |          \|- nompi (stub modulefile)
|  |          \|- openmpi
|  |               \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |               \|- 3.1 (stub modulefile)
|  \|- gcc
|  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  \|- 8.2.0
|  |  |  \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |  \|- mvapich
|  |  |  |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |  |    \|- 2.1
|  |  |  |         \|- 1.1 (stub modulefile)
|  |  |  \|- nompi
|  |  |  |    \|- 1.1 (stub modulefile)
|  |  |  \|- openmpi
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       \|- 3.1
|  |  |            \|- 1.1 (stub modulefile)
|  |  \|- 9.1.0
|  |     \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |     \|- mvapich
|  |     |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |     |    \|- 2.3.1
|  |     |         \|- 2.4 (stub modulefile)
|  |     \|- nompi
|  |     |    \|- 2.4 (stub modulefile)
|  |     \|- openmpi
|  |          \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |          \|- 4.0
|  |               \|- 2.4 (stub modulefile)
|  \|- intel
|  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  \|- 2018
|  |  |  \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |  |  \|- nompi
|  |  |  |    \|- 1.1 (stub modulefile)
|  |  |  \|- intelmpi
|  |  |  |    \|- 1.1 (stub modulefile)
|  |  |  \|- mvapich
|  |  |  |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |  |    \|- 2.1
|  |  |  |         \|- 1.1 (stub modulefile)
|  |  |  \|- openmpi
|  |  |       \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |  |       \|- 3.1
|  |  |            \|- 1.1 (stub modulefile)
|  |  \|- 2019
|  |     \|- .modulerc (symlink to modulerc.select_mpi_family)
|  |     \|- nompi
|  |     |    \|- 2.4 (stub modulefile)
|  |     \|- intelmpi
|  |     |    \|- 2.4 (stub modulefile)
|  |     \|- mvapich
|  |     |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |     |    \|- 2.3.1
|  |     |         \|- 2.4 (stub modulefile)
|  |     \|- openmpi
|  |          \|- .modulerc (symlink to modulerc.select_mpi_version)
|  |          \|- 4.0
|  |               \|- 2.4 (stub modulefile)
|  \|- pgi
|     \|- .modulerc (symlink to modulerc.select_compiler_version)
|     \|- 18.4
|     |  \|- .modulerc (symlink to modulerc.select_mpi_family)
|     |  \|- mvapich
|     |  |    \|- .modulerc (symlink to modulerc.select_mpi_version)
|     |  |    \|- 2.1
|     |  |         \|- 1.1 (stub modulefile)
|     |  \|- nompi
|     |  |    \|- 1.1 (stub modulefile)
|     |  \|- openmpi
|     |       \|- .modulerc (symlink to modulerc.select_mpi_version)
|     |       \|- 3.1
|     |            \|- 1.1 (stub modulefile)
|     \|- 19.4
|        \|- .modulerc (symlink to modulerc.select_mpi_family)
|        \|- nompi
|        |    \|- 2.4 (stub modulefile)
|        \|- openmpi
|             \|- .modulerc (symlink to modulerc.select_mpi_version)
|             \|- 3.1
|                  \|- 2.4 (stub modulefile)

The common code of the modulefile is fairly standard, as shown below

.. include:: ../../example/compiler-etc-dependencies/modulerc/foo/common
    :literal:

The main difference from a standard modulefile is the inclusion of the
invocations of ``LoadedCompilerMatches`` and ``LoadedMpiMatches``.  This
is needed to ensure that the compiler and MPI for the modulefile being
processed are compatible with any which are loaded.  The ``LoadedMpiMatches``
procedure is defined by:

.. include:: ../../example/compiler-etc-dependencies/tcllib/LoadedMpiMatches.tcl
    :literal:

Basically, it determines what if any MPI library was previously module loaded.
If one was loaded, it ensures the family and version match what was expected,
and if not exit with an error.  The use of the ``GetPackageFamilyVersion``
procedure is important, because as discussed previously packages can be
represented by more than one name (e.g. the modulefile for version 4.0 of 
openmpi for gcc/9.1.0 could be named ``openmpi/4.0/gcc/9.1.0`` or
``openmpi/gcc/9.1.0/4.0``) and we need to ensure either is recognized.

Although we only showed cases for compilers and MPI libraries, the techniques
above can be adapted to other cases as well.  For simple cases, where everything
falls under a single package name, one can use ``GetTagOfModuleLoaded`` to
determine the version of the package loaded in the .modulerc and in the 
modulefile to ensure the version matches.  

For bar, we added variants on CPU vectorization support.  Rather than add
a simd modulefile, we just add variants to the bar modules.  So the bar
modulefile tree would look like:

|  bar
|  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  \|- common (shared parts sourced by stub modulefiles)
|  \|- 4.7
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 8.2.0 
|  |          \|- .modulerc (symlink to modulerc.default_lowest_simd)
|  |          \|- avx (stub modulefile)
|  |          \|- sse4.1 (stub modulefile)
|  \|- 5.4
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 9.1.0 
|  |          \|- .modulerc (symlink to modulerc.default_lowest_simd)
|  |          \|- avx (stub modulefile)
|  |          \|- avx2 (stub modulefile)
|  \|- gcc
|  |  \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |  \|- 8.2.0
|  |  |  \|- .modulerc (symlink to modulerc.default_lowest_simd)
|  |  |  \|- avx
|  |  |  |    \|- 4.7 (stub modulefile)
|  |  |  \|- sse4.1
|  |  |       \|- 4.7 (stub modulefile)
|  |  \|- 9.1.0
|  |     \|- .modulerc (symlink to modulerc.default_lowest_simd)
|  |     \|- avx
|  |     |    \|- 5.4 (stub modulefile)
|  |     \|- avx2
|  |          \|- 5.4 (stub modulefile)
|  \|- avx
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 8.2.0
|  |     |    \|- 4.7 (stub modulefile)
|  |     \|- 9.1.0 
|  |          \|- 5.4 (stub modulefile)
|  \|- avx2
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 9.1.0 
|  |          \|- 5.4 (stub modulefile)
|  \|- sse4.1
|  |  \|- .modulerc (symlink to modulerc.select_compiler_family)
|  |  \|- gcc
|  |     \|- .modulerc (symlink to modulerc.select_compiler_version)
|  |     \|- 8.2.0 
|  |          \|- 4.7 (stub modulefile)

Here we added yet another alternate set of module names.  So the module
for bar version 5.4 built with gcc version 9.1.0 and avx2 support can be
called:

*  bar/5.4/gcc/9.1.0/avx2
*  bar/gcc/9.1.0/avx2/5.4
*  bar/avx2/gcc/9.1.0/5.4

Due to this multiplicity of names, if an user does a module load bar, the
.modulerc immediately under bar will cause modulecmd to default along the
path for the loaded (or defaulted) compiler, and then the 
``modulerc.default_lowest_simd`` will default to the lowest simd level.
If the user module loads bar/VERSION, it will find the build for that version
of bar with the appropriate compiler (and again, default to the lowest simd
level).  And if the user module loads bar/avx or another simd level, then
it will load the latest version of bar built for the loaded compiler and 
simd specified.

The ``modulerc.default_lowest_simd`` script looks like:

.. include:: ../../example/compiler-etc-dependencies/modrc_common/modulerc.default_lowest_simd
    :literal:

It will default to the lowest SIMD level, but could easily be adapted to
do something else.

Examples
--------

As with the previous cases, we start with a ``module avail`` command, and here 
we see the first big difference:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/modulerc/modules4.3.1/modavail.out
    :literal:

Unlike the previous cases wherein only package names and versions were shown
(because a single modulefile handled all the builds for that package and
version), here we see a listing for every build of a package and version.
Indeed, we not only see one such listing, but multiple listings per
build in many cases (e.g. ``openmpi/3.1/intel/2018`` and
``openmpi/intel/2018/3.1``).  

While admittedly the output of a  ``module avail`` command which does not 
specify any package is rather overwhelming, when a package is specified
the output tends to be more reasonable, informing one of which builds
of the package are available.  This strategy deliberately opts for the 
presentation of more rather than less information.

The standard functionality of selecting the correct build of a package
based on the loaded compiler, e.g.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/modulerc/modules4.3.1/ompi-loads1.out
    :literal:

works as expected.  The only significant difference between the previously
examined strategies is that the module list command provides information
about what variant of each package is loaded.

The ``module switch`` command, however, does not work as well as one would
like.  While it indeeds switches the specified module, it does not 
successfully reload the modules which depend on the replaced module, even
with the automatic module handling feature enabled, as that feature attempts
to reload the fully qualified module name, and will fail as the fully 
qualified modulename includes the information about the dependencies.  It
is hoped a future version of modulecmd will allow for reloading based on the
name specified when the module was loaded.  But as things currently stand,
the automatic module handling will throw an error attempting to reload the
depend module, resulting in the the dependent modules being unloaded.  Without
automatic module handling (i.e. for older Environmental Modules or without
the --auto flag), the dependent modules remain loaded and there is inconsistency
in the loaded modules.  But at least module list clearly shows such.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/modulerc/modules4.3.1/ompi-switch.out
    :literal:

The defaulting of modules is more successful, however, as seen below:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/modulerc/modules4.3.1/ompi-defaults.out
    :literal:

Here it not only defaults to the default compiler, but if one tries to load
openmpi without specifying a version, it will find and load the latest version
compatible with the loaded compiler.

The situation is similar for foo:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/modulerc/modules4.3.1/foo-loads.out
    :literal:

LEFT OFF HERE

Again, one can load a compiler without an MPI library to get the non-MPI version
of foo, or a compiler and MPI library to get the MPI version.  The dummy
intelmpi modulefile is used to allow one to indicate that the Intel MPI library
is desired.  The automatic module handling can again allow the switch 
functionality work properly, as in

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/foo-switch.out
    :literal:

Here we note a deficiency in the switch support as compared to ``Flavours``.  In the last example
after loading intel/2019 and foo, we have the non-MPI build of foo as expected.  However, upon
subsequently loading the openmpi module, we still have the non-MPI version of foo loaded, as evidenced
by the output of the fake foo command.  I.e., the foo package was *not* automatically reloaded, as 
there was no prereq in the foo modulefile on an MPI library (as in the non-MPI build there is no MPI
library to prereq).  Also note that module list does not really inform one of this fact.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/foo-defaults.out
    :literal:

Above, we see once more that the compiler can be defaulted, but that the 
defaulting mechanism is not smart enough to default the version of foo based
on the compiler loaded (or defaulted to).

The situation with bar is basically the same; with a compiler and simd
module loaded, the environment for the appropriate build of bar is loaded
when you module load bar.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-loads.out
    :literal:

And an error is generated if there is no build for that combination of 
compiler and simd.  The automatic handling of modules again allows the
switch command to work as expected:

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-switch.out
    :literal:

and both the simd level and compiler can be defaulted, but one still has
to choose a version of bar which supports the defaults.

.. include:: ../../example/compiler-etc-dependencies/example-sessions/homebrewed/modules4.3.1/bar-defaults.out
    :literal:

Summary of homebrewed flavors strategy
--------------------------------------

* The automated module handling feature (introduced in Environmental Modules
  4.2.0) allows for the switching out of a dependency (e.g. a compiler) 
  to cause the reload of all modulefiles depending on it.  Without the
  automated module handling (as is default for 4.x, and the only option for
  3.x), the switching of a compiler only changes the compiler and leaves the
  modulefiles that depend on the compiler unchanged.
* The various Tcl procedures make
  it somewhat easy to determine which compiler, MPI, etc. modules have been
  loaded and set the paths appropriately.  Not as elegant or easy to use
  as ``Flavours``, but not difficult
* Like the Flavours package, the module avail output is concise, only e.g. 
  giving package name and version rather than listing a separate modulefile 
  for each combination of package, version, compiler+version,
  MPI library+version, etc.  
* Modules will fail with an error message if user tries to load a package 
  which was not built for the values of the depenency packages loaded.
* In general, a module will fail to load with an error message if any 
  dependent package is not already loaded.  However, it has a limited ability
  for defaulting the compiler, etc.
* It does not include any mechanism for more intelligent defaulting.  I.e., if 
  an user requests to load a package without specifying the version desired, 
  the version will be defaulted to the latest version (or whatever 
  the ``.modulerc`` file specifies) without regard for which versions
  support the versions of the compiler and other prereq-ed packages the user 
  has loaded.


