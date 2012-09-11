------------------------------------------------------------------------------
-- TIA GCC - General GNAT and GCC Stuff                                     --
--                                                                          --
-- Developed by Ken O. Burtch                                               --
------------------------------------------------------------------------------
--                                                                          --
--                Copyright (C) 1999-2003 PegaSoft Canada                   --
--                                                                          --
-- This is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  This is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with this;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
-- This is maintained at http://www.vaxxine.com/pegasoft                    --
--                                                                          --
------------------------------------------------------------------------------

with common,
     os,        -- clock and O/S stuff for Ken's windows
     strings,   -- Ken's string functions
     userio,    -- Ken's ASCII drawing stuff
     controls,  -- controls for Ken's windows
     windows,   -- Ken's windows
     english;
use  common, os, strings, userio, controls, windows, english;

package tiagcc is --------------------------------------------------

-- switchInfo is an array containing information on the various
-- GNAT and GCC switches


type compileSwitches is (
    gnata, gnatb, gnat_D, gnat_E, gnatf, gnatg, gnat_G,
    gnatl, gnat_L, gnatn, gnat_N, gnato, gnatp, gnatq,
    gnatr, gnatt, gnatu, gnatx, gnaty, gnat83, O0, O1,
    O2, O3, fstackcheck, ffastmath, ffloatstore, mno486,
    m486, mpentium, wuninitialized, fomitframepointer
);
pragma Discard_Names( compileSwitches );

subtype gccSwitches is compileSwitches range O2..wuninitialized;
subtype gnatSwitches is compileSwitches range gnata..gnat83;

type switchInfoRec is record
     switch : str255;
     info   : str255;
end record;
pragma pack( switchInfoRec );

type switchInfoArray is array ( compileSwitches ) of switchInfoRec;
pragma pack( switchInfoArray );

switchInfo : switchInfoArray := (

    gnata => ( To255( "-gnata" ), To255( "turn on debugging pragmas" ) ),
    gnatb => ( To255( "-gnatb" ), To255( "keep messages brief" ) ),
    gnat_D => ( To255( "-gnatD" ),
      To255( "with -gnatG, save debuggin info to a file ending in .dx" ) ),
    gnat_E => ( To255( "-gnatE" ),
      To255( "turn on dynamic elaboration checks" ) ),
    gnatf => ( To255( "-gnatF" ), To255( "give full error messages" ) ),
    gnatg => ( To255( "-gnatg" ), To255( "turn on gnat style checks" ) ),
    gnat_G => ( To255( "-gnatG" ),
      To255( "show psuedo-code of how GNAT interprets your source code" ) ),
    gnatl => ( To255( "-gnatl" ),
      To255( "include source code with error messages" ) ),
    gnat_L => ( To255( "-gnatL" ), To255( "C++ setjmp/longjmp exceptions" ) ),
    gnatn => ( To255( "-gnatn" ),
      To255( "allow inlining across different files" ) ),
    gnat_N => ( To255( "-gnatN" ),
      To255( "allow automatic inlining across different files") ) ,
    gnato => ( To255( "-gnato" ), To255( "turn on overflow/numeric checks" ) ),
    gnatp => ( To255( "-gnatp" ), To255( "turn off all checks" ) ),
    gnatq => ( To255( "-gnatq" ),
      To255( "compile entire source file even with errors" ) ),
    gnatr => ( To255( "-gnatr" ),
      To255( "check for reference manual source code layout" ) ),
    gnatt => ( To255( "-gnatt" ),
      To255( "create tree file for use with GNAT utilities" ) ),
    gnatu => ( To255( "-gnatu" ), To255( "list units being compiled" ) ),
    gnatx => ( To255( "-gnatx" ), To255( "suppress cross-reference info" ) ),
    gnaty => ( To255( "-gnaty" ), To255( "impose line length limit" ) ),
    gnat83 => ( To255( "-gnat83" ), To255( "impose Ada 83 conventions" ) ),
    O0 => ( To255( "-O0" ), To255( "No optimization" ) ),
    O1 => ( To255( "-O1" ), To255( "Basic optimization" ) ),
    O2 => ( To255( "-O2" ), To255( "Full optimization" ) ),
    O3 => ( To255( "-O2" ),
       To255( "Full optimization with automatic inlining" ) ),
    fstackcheck => ( To255( "-fstack-check" ),
       To255( "Check for stack overflows" ) ),
    ffastmath => ( To255( "-ffast-math" ),
       To255( "Check for stack overflows" ) ),
    ffloatstore => ( To255( "-ffloat-store" ),
       To255( "Better floating point accuracy" ) ),
    mno486 => ( To255( "-mno-486" ),
       To255( "Compile for Intel 386" ) ),
    m486 => ( To255( "-m486" ),
       To255( "Compile for Intel 486" ) ),
    mpentium => ( To255( "-m486 -malign-loops=2 -malign-jumps=2 -malign-functions=2 -fno-strength-reduce" ), To255( "Pentium optimizations" ) ),
    wuninitialized => ( To255( "-Wuninitialized" ),
      To255( "Check for uninitialized variables" ) ),
    fomitframepointer => ( To255( "-fomit-frame-pointer" ),
      To255( "Discard frame pointer (used by some compiler utilities)" ) )
);

end tiagcc;
