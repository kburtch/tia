------------------------------------------------------------------------------
-- TIACOMMON - common definitions for TIA                                   --
--                                                                          --
-- Developed by Ken O. Burtch                                               --
------------------------------------------------------------------------------
--                                                                          --
--               Copyright (C) 1999-2007 PegaSoft Canada                    --
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
-- This is maintained at http://www.pegasoft.ca/tia.html                    --
--                                                                          --
------------------------------------------------------------------------------

with ada.text_io, -- for printing results in non-interactive modes
     ada.command_line, -- for return result code
     common,
     os,        -- clock and O/S stuff for Ken's windows
     strings,   -- Ken's string functions
     userio,    -- Ken's ASCII drawing stuff
     controls,  -- controls for Ken's windows
     windows,   -- Ken's windows
     english;
use  common, os, strings, userio, controls, windows, english;

Pragma Optimize( Space ); -- make program as small as possible

package tiacommon is -------------------------------------------

-- Current Source Files ----------------------------------------

-- This is now in texttools
--type aSourceLanguage is ( unknownLanguage, Ada_Language, C, CPP, Java, Bush,
--    Perl, PHP, HTML, Shell );
type aSourceType is ( unknownType, AdaBody, AdaSpec, CHeader, CSource,
     CPPHeader, CPPSource, JavaSource, BushSource, PerlSource, PerlModule,
     WebPage, ShellScript, PHPSource );
-- only used if source path is null (ie unsaved, new source)

type anAutoHelpStyle is ( None, Info, Proto, Both );
languageData  : aliased languageDataArray; -- TIA language definitions
format_error  : exception;
languageFileName : constant string := "tiadefs.txt";
KeywordHilight : aPenColourName;
FunctionHilight : aPenColourName;
AutoHelpStyle : anAutoHelpStyle;

ProjectPath   : Str255  := NullStr255; -- path of current project
SourcePath    : Str255  := NullStr255; -- path of current source file
SourceText    : Str255List.List;       -- empty unless loading and
                                       -- saving text being edited
                                       -- (this should be changed!)
sourceLanguage: aSourceLanguage := unknownLanguage;
sourceType    : aSourceType := unknownType;
NeedsFullRecompile : boolean := false; -- set when project params are
-- changed to force a compile rebuild of the project
PlatformSig   : Str255  := NullStr255; -- current platform signature
ProjectLocked : boolean := true;       -- true if read-only project
HasCVS        : boolean := false;      -- true if CVS found at startup
IsCVSProject  : boolean := false;      -- true if "CVS" directory in proj
IsSVNProject  : boolean := false;      -- true if "svn" directory in proj
HasSVN        : boolean := false;      -- true if Subversion found at startup

-- Program Options ---------------------------------------------
--
-- These are saved by default to $HOME/.tiarc

OptionsPath      : str255 := To255( "$HOME/.tiarc" );
Opt_Quiet        : boolean := true;      -- background updates
Opt_Blue         : boolean := true;      -- blue background
Opt_Backup       : Str255 := NullStr255; -- command to backup project
Opt_TipNumber    : integer := 1;         -- tip number stored in .tiarc
Opt_KeyCount     : long_integer := 0;    -- key stats for .rc lifetime
Opt_CVS          : boolean := false;     -- use CVS for project management
Opt_SVN          : boolean := false;     -- use SVN for project management

-- Current Project Settings ------------------------------------
--
-- This are saved to the project's .adp file

Proj_GCCOptions  : str255  := NullStr255; -- additional gcc switches
Proj_LinkOptions : str255  := NullStr255; -- additional link switches
Proj_Main        : str255  := NullStr255; -- name of main program
Proj_GUI         : str255  := To255( "rapid" ); -- name of GUI builder
Proj_Opt         : short_short_integer := 2; -- optimization level
Proj_CPU         : short_short_integer := 3; -- CPU type
Proj_Debug       : short_short_integer := 2; -- debugging level
Proj_Kind        : short_short_integer := 1; -- project type
Proj_Builder     : short_short_integer := 1; -- project builder
Proj_Static      : boolean := true;          -- static build
Proj_Egcs        : boolean := false;         -- egcs compiler
Proj_Alt         : boolean := false;         -- ALT version of GNAT
Proj_GCJ         : boolean := false;    -- GCC version of Java
Proj_PlatSig     : str255  := To255( "unknown" );
Proj_Repository  : str255  := To255( "" ); -- Subversion URL
  -- data to deterime if new compiler/system is being used
Proj_KeyCount    : long_integer := 0;   -- key stats for project
Proj_BuildCount  : long_integer := 0;   -- build stats for project
Proj_BuildTime   : ATimeStamp;          -- last succesful build
Proj_LineCount   : long_integer := 0;   -- CR stats for project
Proj_BuildTimeStr: Str255 := To255( "none" ); -- BuildTime as string
Proj_UpdateTime  : ATimeStamp := 0;     -- CVS Update Time as str

-- also SourcePath is saved in the .adp file

Proj_BackupTime  : ATimeStamp := 0;


-- Background Processing ---------------------------------------
--
-- TIA compiles recently edited files in the background each
-- time the user loads another file.  Although parallel compiling
-- isn't supported yet, I've defined the data structures for
-- up to 4 machines, which are cycled through.

MaxBackgroundProcesses : positive := 4;
subtype ABackgroundProcessNumber is positive range 1..MaxBackgroundProcesses;
type BackgroundLockArray is array( ABackgroundProcessNumber ) of
   Str255;
BackgroundLockPrefix : string := "/tmp/tiablock";
RemoteHosts : BackgroundLockArray;             -- avail. background hosts
BackgroundLock : BackgroundLockArray;          -- list of lock files
NextBackgroundLock : ABackgroundProcessNumber; -- next process to use

procedure InitBackground;
-- setup background update variables

procedure BackgroundUpdate( source : str255 );
-- start a background update: compile given source file

function IsBackgroundUpdate return boolean;
-- are there any background updates running?


-- Global Controls ---------------------------------------------
--
-- This is the statistics shown on the right-hand side of the
-- main window if the window is wide enough.  Also the main source
-- control since we need access to this to show the x,y position.

SourceBox  : aliased ASourceEditList;  -- the source code edit area
SourceBar  : aliased AScrollBar;       -- and it's scroll bar

ShowingMarginStats : boolean := false;
CursorPosX         : aliased aStaticLine;
CursorPosY         : aliased aStaticLine;
DocLength          : aliased aStaticLine;
--LastStatsDoc       : str255 := NullStr255;
LastCursorPosX     : integer := -1;
LastCursorPosY     : long_integer := -1;
LastDocLength      : long_integer := -1;

-- Source History ----------------------------------------------

type ASourceReference is record
  path : Str255 := NullStr255;
  line : Str255List.AListIndex := 0;
  posn : integer := 0;
end record;

QuickOpen1 : ASourceReference;
QuickOpen2 : ASourceReference;
QuickOpen3 : ASourceReference;
QuickOpen4 : ASourceReference;
QuickOpen5 : ASourceReference;

procedure UpdateQuickOpen( quickpath : str255; line : Str255List.AListIndex;
  posn : integer );
-- add a source file to the quick open list, long with the position
-- where the cursor was

procedure NewSource;
-- create an empty package spec

function getPathSuffix( SourcePath : Str255 ) return Str255;
-- Return the suffix of a pathname (e.g. ".c",
-- ".adb", ".java", etc.

procedure SetSourceLanguage( path : str255 := NullStr255 );
-- Set the SourceLanguage variable based on
-- the source file suffix.

procedure LoadSourceFile( path : str255; text : out Str255List.List );
-- Load a source file into the string list, converting tabs to spaces
-- Doesn't check the file type or change the keyword hilighting

procedure SaveSourceFile( path : str255; text : out Str255List.List );
-- Save a source file into the string list, removing trailing spaces
-- Doesn't check the file type or change the keyword hilighting

function basename( s : str255 ) return string;
-- return a filename from a pathname


-- Last Errors Reported by Gnat --------------------------------

LastSuccessfulBuildTime  : long_integer := 0;
LastSuccessfulBuildCount : long_integer := 0;

GnatErrors       : Str255List.List;
NextGnatError    : long_integer := 1;
LoadExceptions   : Str255List.List;

procedure ClearGnatErrors;
-- clear the list of errors

procedure NormalizeGnatErrors;
-- fix errors for non-GCC languages (ie. Perl)

procedure ClearLoadExceptions;
-- erase the load exceptions list

procedure AddLoadException( current, newfile : str255 );
-- add a filename to the list of files that won't be loaded
-- when mentioned in an erro rmessage

function IsLoadException( current, newfile : str255 ) return boolean;
-- true if in load exception list


-- Misc. Globals -----------------------------------------------

NullList : Str255List.List; -- empty gen list header
-- this is assigned one node because Copy, used by SetList,
-- doesn't work properly on empty lists...I'll have to fix that
-- sometime.

DisplayInfo : ADisplayInfoRec;
-- info about the display as returned by Window Manager's
-- GetDisplayInfo.

ItemHelpList : Str255List.List;
-- List of words for item help

procedure loadLanguageData;
-- Load the language data file for TIA.  Can raise I/O errors or format_error
-- if there's a problem with the format of the data file.

function GetWindowTitleFromPath( path : Str255 ) return Str255;
-- create a window title from the given path.  eg. "untitled.adb"
-- if no path, or strip off directories to leave filename

procedure UpdateMarginStats;
-- show statistics in right-hand margin

procedure OutputFilter( DT : in out ADialogTaskRecord );
-- for processing statistics in right-hand margin

procedure InputFilter( DT : in out ADialogTaskRecord );
-- for processing alt keys in main menu

OutputCB : ADialogTaskCallback := OutputFilter'access;
-- ptr to output filter as required for DoDialog

InputCB : ADialogTaskCallback := InputFilter'access;
-- ptr to input filter as required for DoDialog

procedure MenuInputFilter( DT : in out ADialogTaskRecord );
-- for processing clicks outside of a menu

MenuInputCB : ADialogTaskCallback := MenuInputFilter'access;
-- ptr to input filter as required for DoDialog


---> Output Pipes (for running builder)

procedure Pipe( s : str255 );
-- open a pipe for reading using command s.  Captures both
-- stderr and stdout, using shell "2>&1" notation.

function PipeFinished return boolean;
-- check to see if a pipe is finished.  Closes pipe if it is.

procedure NextPipeLine( s : out str255 );
-- read next line from the pipe


---> Platform Signature

procedure GetPlatformSig;
-- return a string describing current hardware/os/gnat-version
-- to determine if project has been moved to new system and
-- needs to be fully rebuilt


---> Multiple People

procedure LockProject;
-- open the project and put a file system lock on it.  Success
-- if global variable ProjectLocked is true

procedure UnlockProject;
-- unlock a locked project

---> Strings

function stringField( s : str255; delimiter : character; f : natural )
return str255;
-- extra a field from a string based on a delimiter

end tiacommon;

