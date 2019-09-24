.. _modulerc-versions-tricks:

Various tricks for versioning using .modulerc files
===================================================

Overview
--------

This cookbook discusses various tricks one can use in .modulerc files.
One powerful feature of Tcl Environmental Modules is that the .modulerc
files are parsed in a complete language like Tcl, and this allows for 
some useful decision making when processing modules.

When an user types ``module load foo`` without specifying anything
more than ``foo`` (i.e. no version, etc), and ``foo`` is a directory
under MODULEPATH and not a file, the module command will attempt to
locate the appropriate variant under ``foo`` to load.  It will start
by looking for a ``.modulerc`` or ``.version`` file in the ``foo``
directory, and see if that defines a default.  If not, it will attempt
to find the latest version itself (unless this implicit versioning
feature is disabled; see e.g. MODULES_IMPLICIT_DEFAULT in module).  
The implicit versioning feature will use Tcl's lsort --dictionary
sorting, so case is mostly ignored and strings of digits sort numerically.

Normally, when the user does not specify a version, one wants to load
for them the latest version available.  So ``module load foo`` should
load the latest version of the ``foo`` package available on the system.
The implicit versioning feature described above does a good job at that,
and so usually (when implicit versioning is enabled, which is the default)
one does not need to use .modulerc files for that.

But there are a few cases where either the implicit versioning does not
choose correctly (packages can have some really bizarre versioning schemes,
and sometimes a package makes big changes to their versioning), and sometimes
you might wish to do something a bit different.  

We discuss some example cases to give a taste for what can be done.

Modulefiles are available in the ``doc/example/modulerc-versioning-tricks`` directory
beneath the root of this install.  You can ``module use`` this directory
to get access to it for the examples.


Simple Aliasing
---------------

There are cases where one might wish to alias module names.  A common case
is where a package has a rather long version number which you wish to
retain, but also wish to allow users to enter a shorter version.  For this
example, we use the fictitious ``aliastest`` package, with a version
``1.0-really-long-version-number``, and we want to allow user to simply
type ``module load aliastest/1.0`` instead of typing the full, long, version
number.

In Environmental Modules versions 4.x, this can be done simply with the
``module-alias`` command.  It takes two arguments, the first being the
name of the alias we wish to define, and the fully qualified module name
we wish to alias it to.  The latter can also be another alias.

So our ``aliastest`` directory in the module tree simply contains the
modulefile ``1.0-really-long-version-number`` defining what to do
when the module is loaded (which for this dummy module is minimal),
and a ``.modulerc`` file defining the alias, as shown below:

.. include:: ../../example/modulerc-versioning-tricks/aliastest/.modulerc
    :literal:

Note that while Environmental Modules 3.x has a ``module-alias`` command,
it does not appear to work (at least I never managed to get it working
correctly).  So the above will not work with versions below 4.  However,
there is a workaround, as we show with the ``aliastest2`` module, with
only significant differences in the ``.modulerc`` file as shown below

.. include:: ../../example/modulerc-versioning-tricks/aliastest2/.modulerc
    :literal:

Here we make use of the ``module-version`` command to effectively again
alias ``1.0`` to the long version number.  There are complications because
if we just use the ``module-version`` command, the ``module alias`` command
will report "Duplicate version symbol" errors.  To avoid that, we check for
a dummy variable (I typically name after the package and version), and if it
does not exist issue the ``module-version`` command and set the dummy variable.
Although this ``.modulerc`` file will work with both 3.x and 4.x versions of
Environmental Modules, I would recommend the ``module-alias`` procedure if you
are using 4.x as it is much clearer to understand what is going on.


Simple Defaulting (e.g. versions)
---------------------------------

There are cases where one might wish to override the implicit version
selection from the module command.  E.g.

* The package authors rebooted the versioning system, so e.g. version 7.0 of the 
  package from last year was followed by version 1.1 this year. Obviously, 
  Environmental Modules cannot be blamed for thinking version 7.0 was newer, so
  if you want 1.1 to be the default you will need to help it with a .modulerc
  file.
* Maybe you installed installed a release canditate 1.2rc1 for one user, but do not
  want it to be the default (despite being newer than version 1.1).

For this example, ``defver-test1``, we assume the first case --- the package authors
released version 7.0, then rebooted the version numbering and came out with a 
newer release numbered 1.1.  We want users who do not specify a version number
to get the latest release, so we add a ``.modulerc`` file underneath ``defver-test1``
as follows:

.. include:: ../../example/modulerc-versioning-tricks/defver-test1/.modulerc
    :literal:

The ``module-version`` command in the ``.modulerc`` file simple tells Environmental
Modules that is no version is specified (e.g. the user just does something 
like ``module load defver-test1``), that the system should default the version
to ``1.1``.

More Advanced Defaulting (e.g. latest version except)
-----------------------------------------------------

Continuing with the example above, wherein the version numbering was 
rebooted so version 7.0 is older than version 1.1, we note a potential
problem with the above solution.  The solution outlined above always
defaults to version 1.1.  Which means if in the course of time, you
install version 1.2 and add a module file for it, Environmental Modules
will still default to version 1.1 unless you remember to update the 
``.modulerc`` file as well.

One can leverage the power of Tcl in the ``.modulerc`` file to handle the
defaulting in a more advanced manner, as shown in the ``defver-test2``
example.  This time, instead of simply setting the default to version 1.1,
we set the default to the "latest" version available excluding version 7.0.
The ``.modulerc`` looks like

.. include:: ../../example/modulerc-versioning-tricks/defver-test2/.modulerc
    :literal:

Here we first define a Tcl procedure ``GetLatestVersionExcept`` which takes
as an argument a Tcl list of version numbers/strings to exclude.  We use
a procedure to better show the division of labor but also because in practice 
you will likely wish to move that procedure outside of the modulefile to
allow reuse.  For Environmental Modules versions 4.2 and higher, this can
be done in the ``siteconfig.tcl`` script as outlined in the cookbook
``Expose procedures and variables to modulefiles``; for older versions you
would need to explicitly source the file containing the procedure definition
in every script wherein you wished to use it, which is much less efficient.

The ``GetLatestVersion`` procedure uses the ``ModulesCurrentModulefile`` variable
to find the location of the ``.modulerc`` file which invoked it, and then
uses the Tcl ``glob`` function to find all of the files/subdirectories in
that directory.  It then uses the ``file tail`` routine to strip out the
directory component, and uses ``lsort -dictionary`` to sort the contents
as the default versioning in modules would.  It then iterates through the
sorted list to find the "newest" version not in the excludeList.  If no
such "newest" version is found (i.e. there are no modulefiles found for
versions not in the exclude list), it returns the empty string.

**NOTE**: The ``GetLatestVersionExcept`` procedure will only work properly
if the modulefiles are all in the same directory as the ``.modulerc`` file
from which it was invoked.  I.e., if your ``MODULEPATH``
consists of two directories, the first one containing the ``defver-test2``
directory where the ``.modulerc`` listed above is, and the second one
containing a ``defver-test2`` directory containing the modulefile for
version 1.3, the procedure will not see the 1.3 modulefile and will instead
return the latest modulefile found in the directory containing the ``.modulerc``
file (1.2).

The rest of the ``.modulerc`` file is actually rather simple; it invokes
the ``GetLatestVersionExcept`` procedure, requesting that version 7.0 be
excluded, and stores the value in the tcl variable ``latest``.  If something
is actually returned, it defaults to that.  Otherwise, it does nothing,
and the standard modules defaulting will occur.

The ``GetLatestVersionExcept`` procedure can readily be adapted to other
situations, e.g.

* defaulting to the latest version 
  not matching a regular expression
* defaulting to the latest version 
  matching a regular expression
* defaulting to a standard version (e.g. ``current``) 
  if and only it exists
* defaulting to the first child in a Tcl list 
  that exists

As a final example, we consider a rather contrived case ``defver-test3`` 
wherein you have a collection of packages and corresponding modulefiles, 
and for some packages you indicate the preferred version by either defining
a modulefile ``current`` (or symlinking the preferred version to ``current``).
But due to various inconsistencies in the organization, sometimes you use
``current``, sometimes the name ``latest``, and sometimes the name ``newest``.
And sometimes none of the above are used. 

For ``defver-test3``, we want:

#. If a version ``current`` is defined, default to that.
#. Otherwise, if a version ``latest`` is defined, default to that.
#. Otherwise, if a version ``newest`` is defined, default to that.
#. Otherwise, default to the latest version other than 7.0

The ``.modulerc`` file to do that could look like:

.. include:: ../../example/modulerc-versioning-tricks/defver-test3/.modulerc
    :literal:

Here, we define two Tcl procedures, the ``GetLatestVersionExcept`` procedure
we saw previously, and ``GetFirstChildInList``.  Again, normally these
would be defined in the ``siteconfig.tcl`` script as outlined in the cookbook
``Expose procedures and variables to modulefiles``.

The ``GetFirstChildInList`` procedure takes a list of child names, and again
uses the ``ModulesCurrentModuleFile`` to find the directory in which the
invoking ``.modulerc`` file is.  It then loops through the list of child names
and returns the first one found in that directory.  If none are found, it
returns the empty string.

The ``.modulerc`` then just invokes ``GetFirstChildInList`` to see if any
of ``current``, ``latest``, or ``newest`` exist, and if so defaults to the
first found.  Otherwise, it behaves like ``defver-test2``, returning the latest
version found excluding 7.0.

Again, this last example was quite contrived, but it serves as an example
of the power of ``.modulerc`` files and what can be done.
