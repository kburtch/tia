#!/bin/sh
#
# Program to automate Ada compiling (and backing up files)
# Note: this is set to create static bindings.
#
# Name of zip backup file and list of files to backup
#
BACKUPFILE=backup
BUILDFILE=.build
BACKUPLIST="go *.adb *.ads *.txt *.html *.doc *.sh README C_code/*"
#
# gnatmake flags (examples):
#
# -mno-486 - compiles for 386, supposedly runs faster on Pentium than 486
# -m486  - (slackware default) compiles for 486
#        - compiles for Pentium, but the optimizer has bugs
#          FAQ suggests "-m486 -malign-loops=2 -malign-jumps=2
#          -malign-functions=2 -fno-strngth-reduce"
OPT586="-O3 -m486 -malign-loops=2 -malign-jumps=2 -malign-functions=2 -fno-strength-reduce -fomit-frame-pointer -ffast-math -ffloat-store"
# -gnatp - suppresses checks (add at end of gnatmake line)
# -gnata - enable debug and assert pragmas
# -O     - optimize (needed for pragma optimize), faster if left off
#
#GMFLAGS="-O -i486 -gnata -gnatf"                        # gnatmake flags
#GMFLAGS="$OPT586 -gnatf -gnatp -i -I../texttools/"      # gnatmake flags
GMFLAGS="$OPT586 -gnatf -i -I../texttools/"      # gnatmake flags
#
# Gnat Bind options
#
GBFLAGS="-I../texttools/"
#
# C libraries to link in to make it compile
#
#LIBRARIES=" C_code/*.o -lm -lncurses" # -lgpm, -lvgagl -lvga -ljpeg
#LIBRARIES="../texttools/C_code/*.o tiac.o -lm -lncurses"
LIBRARIES="../texttools/C_code/*.o -lm -lncurses"
#
# Shell script name
#
ME=`basename "$0"`
#
# ---> Determine ending of file, and if we need to link
#
ISADS=`echo $1 | grep \.ads`                  # does file name have an .ads?
if [ -z "$ISADS" ] ; then
   if [ -f "$1"".ads" ] ; then                # if not, does .ads exist?
      ISPACKAGE=yes                           #    then it's a package
      NAME="$1"                               #    and name is .adb file
   else
      NAME="$1".adb                           # name of .adb file
   fi
else
   NAME="$1"
fi
#
# ---> Help if no file specified
#
if [ -z "$1" ] ; then
   echo "$ME: Compile and link an Ada main program, by Ken Burtch"
   echo "     You have to specify a file without an extension."
   echo
   echo "Examples:"
   echo "       $ME program     -- compile a program"
   echo "       $ME package     -- rebuild a package"
   echo "       $ME package.ads -- check the package spec"
   exit
elif [ ! -z "$2" ] ; then
   echo "$ME: This only works with one file as a parameter."
   exit 5
fi
#
# ---> Sanity Checks
#
if [ "$ISPACKAGE" = "" ] ; then
  if ! test -f $NAME ; then
    echo "$ME: I can't find a file $NAME"
    exit 1
  fi
  if ! test -r $NAME ; then
    echo "$ME: I can't read the file $NAME"
    exit 1
  fi
  if ! test -w $NAME ; then
    echo "$ME: Warning--file $NAME isn't writeable"
  fi
  if test -f $1 ; then
     if ! test -w $1 ; then
        echo "$ME: The executable isn't writable.  If you're logged in"
        echo "$ME: under the right name, try chmod and/or chown to fix it."
        exit 1
     fi
  fi
fi
#
# ---> If it's time for a backup, backup!
#
#if test -f $BACKUPFILE.zip ; then
#   TIMETOBACKUP=`find $BACKUPFILE.zip -mtime +0`
#else
#   TIMETOBACKUP=First-Time
#fi
#if [ ! -z "$TIMETOBACKUP" ] ; then
#   echo "$ME: 24 hour backup ..."
#   zip -9q $BACKUPFILE $BACKUPLIST
#   if [ $? -ne 0 ] ; then
#      echo "$ME: Backup failed."
#      exit 2
#   fi
#fi
#
# GNATMAKE compiles the program and any related files
#
# Compile a package
#
if [ "$ISPACKAGE" != "" ] ; then
  if test -f "$NAME"".adb" ; then
    echo "$ME: Compiling package $NAME ..."
    gnatmake $GMFLAGS -c "$NAME"".adb"
    if [ $? -ne 0 ] ; then
       exit 3
    fi
    echo "$ME: OK"
    exit 0                  # done -- can't link a package
  else                      # no .ads and is package?
    ISADS=true              # then must only have a .ads 
    NAME="$NAME"".ads"      # fake user typing "go name.ads"
  fi
fi
#
# Compile just a package spec
#
if [ ! -z "$ISADS" ] ; then
  echo "$ME: Compiling package spec $NAME ..."
  gnatmake $GMFLAGS -c $NAME
  if [ $? -ne 0 ] ; then
     exit 3
  fi
  echo "$ME: OK"
  exit 0                  # done -- can't link a package
fi
#
# Compile program
#
echo "$ME: Compiling $NAME ..."
gnatmake $GMFLAGS -c $NAME
if [ $? -ne 0 ] ; then
   exit 3
fi
#
# GNATBIND determines the order that files must be linked
#
gnatbind $GBFLAGS -x $1.ali
if [ $? -ne 0 ] ; then
   exit 4
fi
#
# GNATLINK does the actual linking to create an executable
#
echo "$ME: Linking..."
gnatlink $1.ali $LIBRARIES #-static
if [ $? -ne 0 ] ; then
   exit 4
fi
echo "$ME: OK"

