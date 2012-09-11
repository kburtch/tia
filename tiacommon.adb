------------------------------------------------------------------------------
-- TIA COMMON (package body)                                                --
--                                                                          --
-- Developed by Ken O. Burtch                                               --
------------------------------------------------------------------------------
--                                                                          --
--              Copyright (C) 1999-2007 PegaSoft Canada                     --
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

with System;

with ada.text_io, ada.strings.unbounded.text_io;
use  ada.text_io,
     ada.strings.unbounded,
     ada.strings.unbounded.text_io;

package body tiacommon is


------------------------------------------------------------------------------
-- O/S BINDINGS
------------------------------------------------------------------------------


---> Pipe Stuff -------------------------------------

type AStdioFileID is new System.Address;
-- a C standard IO (stdio) file id

function popen( command, mode : string ) return AStdioFileID;
pragma import( C, popen, "popen" );
-- opens a pipe to command

procedure pclose( result : out integer; fid : AStdioFileID );
pragma import( C, pclose, "pclose" );
pragma import_valued_procedure( pclose );
-- closes a pipe

function fgetc( fid : AStdioFileID ) return integer;
pragma import( C, fgetc, "fgetc" );
-- part of standard C library.  Reads one character from a file.

-- File Stuff

-- GCC 3.x / GNAT 5.x doesn't like this.  We'll use Texttools'
-- function as a workaround.
--errno : integer;
--pragma import( C, errno );
-- standard kernel error number
function C_errno return integer;
pragma import( C, C_errno, "C_errno" );
procedure C_reset_errno;
pragma import( C, C_reset_errno, "C_reset_errno" );

type aFileID is new integer;

function Open( path : string; flags, mode : integer ) return aFileID;
pragma import( C, open );
-- kernel call to open a file

procedure Close( f : aFileID );
pragma import( C, close );
-- kernel call to close a file

type writeLock_lockStruct is record
  l_type   : short_integer := 1;   -- write lock
  l_whence : short_integer := 0;
  l_start  : integer := 0;
  l_len    : integer := 0;
  l_pid    : integer := 0;
end record;

myLock : writeLock_lockStruct;

procedure fcntl( result : out integer; f : aFileID;
  operation : integer; lock : in out writeLock_lockStruct );
pragma import( C, fcntl );
pragma import_valued_procedure( fcntl );


------------------------------------------------------------------------------
-- DECLARATIONS
------------------------------------------------------------------------------

ProjectLockFile : aFileID := 0;                   -- 0 if project is unlocked

PipeID : AStdioFileID;                            -- File ID for lpr pipe
EndOfPipe : boolean;                              -- true of EOF on input pipe


------------------------------------------------------------------------------
-- BACKGROUND PROCESSING
--
-- TIA compiles recently edited files in the background each time the user
-- loads another file.  Although parallel compiling isn't supported yet, I've
-- defined the data structures for up to 4 machines, which are cycled through.
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- INIT BACKGROUND
--
-- Setup the background processing system.
------------------------------------------------------------------------------

procedure InitBackground is
  ID : str255;
begin
  NextBackgroundLock := 1;
  ID := To255( MyID'img );
  FixSpacing( ID );
  for i in ABackgroundProcessNumber'range loop
      RemoteHosts( i ) := NullStr255;
      BackgroundLock( i ) := BackgroundLockPrefix & ID;
  end loop;
  RemoteHosts( 1 ) := To255( "unused" ); -- always this host
end InitBackground;


------------------------------------------------------------------------------
-- BACKGROUND UPDATE
--
-- Perform a background update.  Attempt to compile a file as a separate
-- process, ignoring compiling errors if any.
------------------------------------------------------------------------------

procedure BackgroundUpdate( source : str255 ) is
  -- attempt to update object file of source in the background
  Cmd : str255;
begin
  -- for now, NextBackgroundLock is always '1' for a single machine
  if not Opt_Quiet then
     return; -- don't bother if quiet updates turned off
  end if;
  if SourceLanguage = Bush or SourceLanguage = Shell or SourceLanguage = Perl or SourceLanguage = PHP then
     return;
  end if;
  if IsFile( BackgroundLock( 1 ) ) then 
     SessionLog( "BackgroundUpdate: last update hasn't finished it--skipping" );
  else
     SessionLog( "BackgroundUpdate: quietly compiling " & source );
     Cmd := "touch " & BackgroundLock( 1 );
     SessionLog( cmd );
     UNIX( cmd );
     -- (nice gcc -c opts source > /dev/null 2>/dev/null ; rm -f lock) &
     if SourceLanguage = Java then
        if Proj_GCJ then
           Cmd := To255( "(nice gcj -c -C " );
        else
           Cmd := To255( "(nice javac " );
        end if;
     else
        if Proj_Alt then
           Cmd := To255( "(nice gnatgcc -c " );
        else
           Cmd := To255( "(nice gcc -c " );
        end if;
        if Proj_Opt = 1 then
           null; -- nothing special for no optimize
        elsif Proj_Opt = 2 then
           Cmd := Cmd & "-O ";
        elsif Proj_Opt = 3 then
           Cmd := Cmd & "-O2 ";
        else
           Cmd := Cmd & "-O3 ";
        end if;
        if Proj_CPU = 1 then
           Cmd := Cmd & "-mno-486 ";
        elsif Proj_CPU = 2 then
           Cmd := Cmd & "-m486 ";
        else -- Pentium or P2
           Cmd := Cmd & "-m486 -malign-loops=2 -malign-jumps=2"
             & " -malign-functions=2 -fno-strength-reduce ";
        end if;
        -- debug
        -- gnat 3.11 -gnatwu omitted for rebuild
        if Proj_Debug = 1 then
           Cmd := Cmd & "-gnatp ";
        elsif Proj_Debug = 2 then
           Cmd := Cmd & "-gnata ";
        elsif Proj_Debug = 3 then
           Cmd := Cmd & "-gnata -gnato -gnatE ";
        end if;
        if Proj_Kind = 4 then -- shared library
           Cmd := Cmd & "-fPIC -shared ";
        end if;
        Cmd := Cmd & ToString( Proj_GCCOptions );
     end if;
     Cmd := Cmd & " " & ToString( source ) &
           " > /dev/null 2> /dev/null ; rm -f " &
           ToString( BackgroundLock( 1 ) ) & " ) &";
     SessionLog( cmd );
     UNIX( cmd );
  end if;
end BackgroundUpdate;


------------------------------------------------------------------------------
-- IS BACKGROUND UPDATE
--
-- True if a background update is underway.
------------------------------------------------------------------------------

function IsBackgroundUpdate return boolean is
  -- is there a background update running on this machine?
begin
  return IsFile( BackgroundLock( 1 ) );
end IsBackgroundUpdate;


------------------------------------------------------------------------------
-- UPDATE QUICK OPEN
--
-- Update the quick open list for a new file.
------------------------------------------------------------------------------

procedure UpdateQuickOpen( quickpath : str255; line : Str255List.AListIndex;
  posn : integer ) is
  base, file : str255;
begin
  -- if current directory, discard absolute path if there is one
  SplitPath( quickpath, base, file );
  if length( base ) > 0 then
     if Element( base, length( base ) ) = '/' then
        Delete( base, length(base), length(base) );
     end if;
  end if;
  if base /= GetPath then -- not current directory?
     file := QuickPath;   -- use path as given
  end if;
  if QuickOpen1.path = file then
     QuickOpen1.line := line;
     QuickOpen1.posn := posn;
  elsif QuickOpen2.path = file then
     QuickOpen2.line := line;
     QuickOpen2.posn := posn;
  elsif QuickOpen3.path = file then
     QuickOpen3.line := line;
     QuickOpen3.posn := posn;
  elsif QuickOpen4.path = file then
     QuickOpen4.line := line;
     QuickOpen4.posn := posn;
  elsif QuickOpen5.path = file then
     QuickOpen5.line := line;
     QuickOpen5.posn := posn;
  else
     QuickOpen5 := QuickOpen4;
     QuickOpen4 := QuickOpen3;
     QuickOpen3 := QuickOpen2;
     QuickOpen2 := QuickOpen1;
     QuickOpen1 := ASourceReference'( file, line, posn );
  end if;  
end UpdateQuickOpen;


------------------------------------------------------------------------------
-- NEW SOURCE
--
-- Show the new source dialog box and create a new source file based on the
-- type of source chosen.
------------------------------------------------------------------------------

procedure NewSource is
   AdaProcButton : aliased ARadioButton;
   AdaSpecButton : aliased ARadioButton;
   AdaBodyButton : aliased ARadioButton;
   ShellButton   : aliased ARadioButton;
   CHeaderButton : aliased ARadioButton;
   CSourceButton : aliased ARadioButton;
   CPPHdrButton  : aliased ARadioButton;
   CPPSrcButton  : aliased ARadioButton;
   JavaSrcButton : aliased ARadioButton;
   BushSrcButton : aliased ARadioButton;
   PerlSrcButton : aliased ARadioButton;
   PerlModButton : aliased ARadioButton;
   PHPSrcButton  : aliased ARadioButton;
   PHPButton     : aliased ARadioButton;
   WebPageButton : aliased ARadioButton;
   OKButton      : aliased ASimpleButton;

   DT : aDialogTaskRecord;
begin
   OpenWindow( To255( "New Source" ), 1, 1, 60, 20 );

   Init( AdaProcButton, 1, 2, 58, 2, 1, 'a' );
   SetText( AdaProcButton, To255( "Ada Procedure (.adb)" ) );
   AddControl( AdaProcButton'unchecked_access, false );
   SetCheck( AdaProcButton, True );

   Init( AdaSpecButton, 1, 3, 58, 3, 1, 's' );
   SetText( AdaSpecButton, To255( "Ada Package Specification (.ads)" ) );
   AddControl( AdaSpecButton'unchecked_access, false );
   SetCheck( AdaSpecButton, False );

   Init( AdaBodyButton, 1, 4, 58, 4, 1, 'b' );
   SetText( AdaBodyButton, To255( "Ada Package Body (.adb)" ) );
   AddControl( AdaBodyButton'unchecked_access, false );
   SetCheck( AdaBodyButton, False );

   Init( ShellButton, 1, 5, 58, 5, 1, 'l' );
   SetText( ShellButton, To255( "Shell Script (.sh)" ) );
   AddControl( ShellButton'unchecked_access, false );
   SetCheck( ShellButton, False );

   Init( CHeaderButton, 1, 6, 58, 6, 1, 'h' );
   SetText( CHeaderButton, To255( "C Header (.h)" ) );
   AddControl( CHeaderButton'unchecked_access, false );
   SetCheck( CHeaderButton, False );

   Init( CSourceButton, 1, 7, 58, 7, 1, 'c' );
   SetText( CSourceButton, To255( "C Source (.c)" ) );
   AddControl( CSourceButton'unchecked_access, false );
   SetCheck( CSourceButton, False );

   Init( CPPHdrButton, 1, 8, 58, 8, 1, '+' );
   SetText( CPPHdrButton, To255( "C++ Header (.h)" ) );
   AddControl( CPPHdrButton'unchecked_access, false );
   SetCheck( CPPHdrButton, False );

   Init( CPPSrcButton, 1, 9, 58, 9, 1, 'r' );
   SetText( CPPSrcButton, To255( "C++ Source (.cc)" ) );
   AddControl( CPPSrcButton'unchecked_access, false );
   SetCheck( CPPSrcButton, False );

   Init( JavaSrcButton, 1, 10, 58, 10, 1, 'j' );
   SetText( JavaSrcButton, To255( "Java Source (.java)" ) );
   AddControl( JavaSrcButton'unchecked_access, false );
   SetCheck( JavaSrcButton, False );

   Init( BushSrcButton, 1, 11, 58, 11, 1, 'u' );
   SetText( BushSrcButton, To255( "BUSH Source (.bush)" ) );
   AddControl( BushSrcButton'unchecked_access, false );
   SetCheck( BushSrcButton, False );

   Init( PerlSrcButton, 1, 12, 58, 12, 1, 'p' );
   SetText( PerlSrcButton, To255( "Perl Source (.pl)" ) );
   AddControl( PerlSrcButton'unchecked_access, false );
   SetCheck( PerlSrcButton, False );

   Init( PerlModButton, 1, 13, 58, 13, 1, 'm' );
   SetText( PerlModButton, To255( "Perl Module (.pm)" ) );
   AddControl( PerlModButton'unchecked_access, false );
   SetCheck( PerlModButton, False );

   Init( WebPageButton, 1, 14, 58, 14, 1, 'w' );
   SetText( WebPageButton, To255( "Web Page (.html)" ) );
   AddControl( WebPageButton'unchecked_access, false );
   SetCheck( WebPageButton, False );

   Init( PHPSrcButton, 1, 15, 58, 15, 1, 'e' );
   SetText( PHPSrcButton, To255( "PHP Source (.php)" ) );
   AddControl( PHPSrcButton'unchecked_access, false );
   SetCheck( PHPSrcButton, False );

   Init( OKButton, 27, 17, 32, 17, 'o' );
   SetText( OKButton, To255( "OK" ) );
   AddControl( OKButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   -- No source path.  Clear source text

   SourcePath := NullStr255;
   Str255List.Clear( SourceText );

   -- Record the source type

   if GetCheck( AdaProcButton ) then
      sourceType := AdaBody;
   elsif GetCheck( AdaSpecButton ) then
      sourceType := AdaSpec;
   elsif GetCheck( AdaBodyButton ) then
      sourceType := AdaBody;
   elsif GetCheck( ShellButton ) then
      sourceType := ShellScript;
   elsif GetCheck( CHeaderButton ) then
      sourceType := CHeader;
   elsif GetCheck( CSourceButton ) then
      sourceType := CSource;
   elsif GetCheck( CPPHdrButton ) then
      sourceType := CPPHeader;
   elsif GetCheck( CPPSrcButton ) then
      sourceType := CPPSource;
   elsif GetCheck( JavaSrcButton ) then
      sourceType := JavaSource;
   elsif GetCheck( BushSrcButton ) then
      sourceType := BushSource;
   elsif GetCheck( PerlSrcButton ) then
      sourceType := PerlSource;
   elsif GetCheck( PerlModButton ) then
      sourceType := PerlModule;
   elsif GetCheck( PHPSrcButton ) then
      sourceType := PHPSource;
   elsif GetCheck( WebPageButton ) then
      sourceType := WebPage;
   else
      sourceType := unknownType;
   end if;

   -- Create a blank source and record language

   if GetCheck( AdaProcButton ) or GetCheck( AdaSpecButton ) or
      GetCheck( AdaBodyButton ) then
      Str255List.Queue( SourceText,
        To255( "-------------------------------------------------" ) );
      Str255List.Queue( SourceText,
        To255( "-- UNTITLED                                    --" ) );
      Str255List.Queue( SourceText,
        To255( "--                                             --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Descripton:                                 --" ) );
      Str255List.Queue( SourceText,
        To255( "--                                             --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Written by                                  --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Copyright (c) Company.  All rights reserved --" ) );
      Str255List.Queue( SourceText,
        To255( "-------------------------------------------------" ) );
     if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "-- $Id$" ) );
     end if;
     Str255List.Queue( SourceText, NullStr255 );
     Str255List.Queue( SourceText, To255( "pragma Optimize( Space );" ) );
     if GetCheck( AdaProcButton ) then
        Str255List.Queue( SourceText, To255( "procedure untitled is" ) );
     elsif GetCheck( AdaSpecButton ) then
        Str255List.Queue( SourceText, To255( "package untitled is" ) );
     else
        Str255List.Queue( SourceText, To255( "package body untitled is" ) );
     end if;
     Str255List.Queue( SourceText, To255( "" ) );
     if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "-- $Log$" ) );
     end if;
     Str255List.Queue( SourceText, To255( "end untitled;" ) );
     SourceLanguage := Ada_Language;
  elsif GetCheck( ShellButton ) then
      Str255List.Queue( SourceText, To255( "#!/bin/bash" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# UNTITLED" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# Descripton:" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# Written by" ) );
      Str255List.Queue( SourceText,
        To255( "# Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "# $Id$" ) );
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "# $Log$" ) );
     end if;
     Str255List.Queue( SourceText, To255( "shopt -s -o nounset" ) );
     SourceLanguage := Shell;
  elsif GetCheck( CHeaderButton ) or GetCheck( CPPHdrButton ) then
      Str255List.Queue( SourceText, To255( "/*" ) );
      Str255List.Queue( SourceText, To255( " * UNTITLED" ) );
      Str255List.Queue( SourceText, To255( " *" ) );
      Str255List.Queue( SourceText, To255( " * Descripton:" ) );
      Str255List.Queue( SourceText, To255( " *" ) );
      Str255List.Queue( SourceText, To255( " * Written by" ) );
      Str255List.Queue( SourceText,
        To255( " * Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( " */" ) );
      if HasCVS and Opt_CVS then
        Str255List.Queue( SourceText, To255( "/* $Id$ */" ) );
      end if;
      Str255List.Queue( SourceText, NullStr255 );
      Str255List.Queue( SourceText, To255( "#ifdef UNTITLED_H" ) );
      Str255List.Queue( SourceText, To255( "#define UNTITLED_H" ) );
      Str255List.Queue( SourceText, NullStr255 );
      Str255List.Queue( SourceText, To255( "#endif" ) );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "/*" ) );
       Str255List.Queue( SourceText, To255( " * $Log$" ) );
       Str255List.Queue( SourceText, To255( " */" ) );
     end if;
     SourceLanguage := C;
  elsif GetCheck( CSourceButton ) then
      Str255List.Queue( SourceText, To255( "/*" ) );
      Str255List.Queue( SourceText, To255( " * UNTITLED" ) );
      Str255List.Queue( SourceText, To255( " *" ) );
      Str255List.Queue( SourceText, To255( " * Descripton:" ) );
      Str255List.Queue( SourceText, To255( " *" ) );
      Str255List.Queue( SourceText, To255( " * Written by" ) );
      Str255List.Queue( SourceText,
        To255( " * Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( " */" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
        Str255List.Queue( SourceText, To255( "/* $Id$ */" ) );
        Str255List.Queue( SourceText, NullStr255 );
        Str255List.Queue( SourceText, To255( "/*" ) );
        Str255List.Queue( SourceText, To255( " * $Log$" ) );
        Str255List.Queue( SourceText, To255( " */" ) );
      end if;
     SourceLanguage := C;
  elsif GetCheck( BushSrcButton ) then
      Str255List.Queue( SourceText, To255( "#!bush_path_here" ) );
      Str255List.Queue( SourceText, NullStr255 );
      Str255List.Queue( SourceText,
        To255( "-------------------------------------------------" ) );
      Str255List.Queue( SourceText,
        To255( "-- UNTITLED                                    --" ) );
      Str255List.Queue( SourceText,
        To255( "--                                             --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Descripton:                                 --" ) );
      Str255List.Queue( SourceText,
        To255( "--                                             --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Written by                                  --" ) );
      Str255List.Queue( SourceText,
        To255( "-- Copyright (c) Company.  All rights reserved --" ) );
      Str255List.Queue( SourceText,
        To255( "-------------------------------------------------" ) );
     if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "-- $Id$" ) );
     end if;
     Str255List.Queue( SourceText, To255( "pragma ada_95;" ) );
     Str255List.Queue( SourceText, NullStr255 );
     Str255List.Queue( SourceText, To255( "procedure untitled is" ) );
     Str255List.Queue( SourceText, To255( "begin" ) );
     if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "-- $Log$" ) );
     end if;
     Str255List.Queue( SourceText, To255( "end untitled;" ) );
     SourceLanguage := Bush;
  elsif GetCheck( PerlSrcButton ) or GetCheck( PerlModButton ) then
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# UNTITLED" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# Descripton:" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, To255( "# Written by" ) );
      Str255List.Queue( SourceText,
        To255( "# Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( "#" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "# $Id$" ) );
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "# $Log$" ) );
     end if;
     SourceLanguage := Perl;
  elsif GetCheck( PHPSrcButton ) then
      Str255List.Queue( SourceText, To255( "<?php" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// UNTITLED" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// Descripton:" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// Written by" ) );
      Str255List.Queue( SourceText,
        To255( "// Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "// $Id$" ) );
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "// $Log$" ) );
     end if;
     Str255List.Queue( SourceText, To255( "?>" ) );
     SourceLanguage := PHP;
  elsif GetCheck( WebPageButton ) then
      Str255List.Queue( SourceText, To255( "<!-- UNTITLED -->" ) );
      Str255List.Queue( SourceText, To255( "<!-- -->" ) );
      Str255List.Queue( SourceText, To255( "<!-- Descripton: -->" ) );
      Str255List.Queue( SourceText, To255( "<!-- -->" ) );
      Str255List.Queue( SourceText, To255( "<!-- Written by -->" ) );
      Str255List.Queue( SourceText,
        To255( "<!-- Copyright (c) Company.  All rights reserved -->" ) );
      Str255List.Queue( SourceText, To255( "<!-- -->" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "<!-- $Id$ -->" ) );
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "<!-- $Log$ -->" ) );
     end if;
     SourceLanguage := HTML;
  else
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// UNTITLED" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// Descripton:" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, To255( "// Written by" ) );
      Str255List.Queue( SourceText,
        To255( "// Copyright (c) Company.  All rights reserved" ) );
      Str255List.Queue( SourceText, To255( "//" ) );
      Str255List.Queue( SourceText, NullStr255 );
      if HasCVS and Opt_CVS then
       Str255List.Queue( SourceText, To255( "// $Id$" ) );
       Str255List.Queue( SourceText, NullStr255 );
       Str255List.Queue( SourceText, To255( "// $Log$" ) );
     end if;
     if GetCheck( CPPSrcButton ) then
        SourceLanguage := CPP;
     else
        SourceLanguage := Java;
     end if;
  end if;
end NewSource;


------------------------------------------------------------------------------
-- CLEAR GNAT ERRORS
--
-- Clear the error list returned by the compiler.
------------------------------------------------------------------------------

procedure ClearGnatErrors is
begin
  Str255List.Clear( GnatErrors );
  NextGnatError := 1;
end ClearGnatErrors;


------------------------------------------------------------------------------
-- NORMALIZE GNAT ERRORS
--
-- Check for non-standard error formats (ie. Perl's "...line x") and convert
-- to GCC format so Next Error operation works properly.
------------------------------------------------------------------------------

procedure NormalizeGnatErrors is
-- Handle non-standard Perl errors
  p : integer;
  p2 : integer;
  blankCnt : integer;
  error : str255;
  errorLocation : str255;
  errorLine : str255;
  errorFile : str255;
  errorMessage : str255;
  temp : Str255;
begin
  if SourceLanguage = Perl then
  for i in 1..Str255List.Length( GnatErrors ) loop
      Str255List.Find( GnatErrors, i, Error );
      ErrorMessage := Error;
<<retry>>
      p := length( Error );
      blankCnt := 0;
      errorLocation := nullStr255;
      while p  > 1 loop
            p := p - 1;
            if element( Error, p ) = ' ' then
               blankCnt := blankCnt + 1;
               if blankCnt = 2 then
                  if Slice( Error, p+1, p+4 ) = "near" then -- should really length check
                     -- some perl errors end in "line xyz, near token"  Move the "near"
                     -- part to the front of the error and retry
                     Temp := To255( Slice( Error, p+1, length( Error ) ) );
                     p := p - 2;                              -- skip ", near"
                     Error := Temp & ", " & To255( Slice( Error, 1, p ) );
                     goto retry;
                  else
                     errorLocation := To255( Slice( Error, p+1, length( Error ) ) );
                     -- some perl errors have trailing period.  But not all. Go fig.
                     if element( errorLocation, length( errorLocation ) ) = '.' then
                        Delete( errorLocation, length( errorLocation ), length( errorLocation ) );
                     end if;
                     exit;
                  end if;
               end if;
            end if;
      end loop;
      if length( errorLocation ) > 4 then
         if Slice( errorLocation, 1, 5 ) = "line " then
            errorLine := To255( Slice( errorLocation, 5, length( errorLocation ) ) );

            ErrorFile := SourcePath;
            p2 := p;
            while p > 1 loop
               p := p - 1;
               if element( Error, p ) = ' ' then
                  blankCnt := blankCnt + 1;
                  if blankCnt = 3 then
                     errorFile := To255( Slice( Error, p+1, p2-1 ) );
                     if Slice( Error, p-4, p-1 ) = " at" then
                        errorMessage := To255( Slice( Error, 1, p-4 ) );
                     else
                        errorMessage := To255( Slice( Error, 1, p-4 ) );
                     end if;
                     exit;
                  end if;
               end if;
            end loop;

            Error := ErrorFile & ":" & errorLine & ": " & ErrorMessage;
            Str255List.Replace( GnatErrors, i, Error );
         end if;
      end if;
  end loop;
  elsif SourceLanguage = HTML then
      -- Apache will do this
      if Str255List.Length( GnatErrors ) > 0 then
         Str255List.Find( GnatErrors, Str255List.length( GnatErrors ), Error );
         if Error = "Syntax OK" then
            Str255List.Clear( GnatErrors, Str255List.length( GnatErrors ) );
         end if;
      end if;
  elsif SourceLanguage = Java then
      -- SUN Java: "1. ERROR in untitled.java (at line 10)"
      for i in 1..Str255List.Length( GnatErrors ) loop
          Str255List.Find( GnatErrors, i, Error );
          p := index( Error, "ERROR in" );
          if p > 0 then
             p := p + 9;
             p2 := index( Error, "(at line" );
             if p2 > 0 then
                errorFile := To255( slice( Error, p, p2-2 ) );
                p2 := p2 + 9;
                errorLine := NullStr255;
                while element( Error, p2 ) /= ')' loop
                      errorLine := errorLine & element( Error, p2 );
                      p2 := p2 + 1;
                      exit when p2 = length( Error );
                end loop;
                Error := ErrorFile & ":" & errorLine & ": error in this line";
                Str255List.Replace( GnatErrors, i, Error );
             end if;
          end if;
      end loop;
end if;

end NormalizeGnatErrors;


------------------------------------------------------------------------------
-- CLEAR LOAD EXCEPTIONS
--
-- Erase the load exceptions list
------------------------------------------------------------------------------

procedure ClearLoadExceptions is
begin
  Str255List.Clear( LoadExceptions );
end ClearLoadExceptions;

------------------------------------------------------------------------------
-- CLEAR LOAD EXCEPTIONS
--
-- Add a filename to the list of files that won't be loaded
-- when mentioned in an erro rmessage
------------------------------------------------------------------------------

procedure AddLoadException( current, newfile : str255 ) is
  Key : Str255;
begin
  Key := current & "~" & newfile;
  Str255List.Push( LoadExceptions, Key );
end AddLoadException;

------------------------------------------------------------------------------
-- CLEAR LOAD EXCEPTIONS
--
-- true if in load exception list
------------------------------------------------------------------------------

function IsLoadException( current, newfile : str255 ) return boolean is
  Key : Str255;
  Location : Str255List.AListIndex;
begin
  Key := current & "~" & newfile;
  Str255List.Find( LoadExceptions, Key, foundAt => Location );
  return location /= 0;
end IsLoadException;


------------------------------------------------------------------------------
-- GET WINDOW TITLE FROM PATH
--
-- Determine an appropriate window title from the source file path.  If there
-- is no path, create an "untitled" name based on the sourceType.
------------------------------------------------------------------------------

function GetWindowTitleFromPath( path : Str255 ) return Str255 is
  Base, File : Str255;
  WindowTitle : str255;
begin
  if length( path ) = 0 then
     if sourceType = AdaBody then
        windowTitle := To255( "untitled.adb" );
     elsif sourceType = AdaSpec then
        windowTitle := To255( "untitled.ads" );
     elsif sourceType = CHeader or sourceType = CPPHeader then
        windowTitle := To255( "untitled.h" );
     elsif sourceType = CSource then
        windowTitle := To255( "untitled.c" );
     elsif sourceType = CPPSource then
        windowTitle := To255( "untitled.cc" );
     elsif sourceType = JavaSource then
        windowTitle := To255( "untitled.java" );
     elsif sourceType = BushSource then
        windowTitle := To255( "untitled.bush" );
     elsif sourceType = PerlSource then
        windowTitle := To255( "untitled.pl" );
     elsif sourceType = PerlModule then
        windowTitle := To255( "untitled.pm" );
     elsif sourceType = WebPage then
        windowTitle := To255( "untitled.html" );
     elsif sourceType = ShellScript then
        windowTitle := To255( "untitled.sh" );
     elsif sourceType = PHPSource then
        windowTitle := To255( "untitled.php" );
     else
        windowTitle := To255( "untitled" );
     end if;
  else
     SplitPath( path, base, file );
     if length( base ) > 0 then
        if Element( base, length( base ) ) = '/' then
           Delete( base, length(base), length(base) );
        end if;
     end if;
     if base = GetPath then
        WindowTitle := file;
     else
        WindowTitle := path;
     end if;
  end if;
  return WindowTitle;
end GetWindowTitleFromPath;


------------------------------------------------------------------------------
-- UPDATE MARGIN STATS
--
-- Update the stats display in the right-hand margin in wide displays.  If the
-- display is narrow, nothing is updated.
------------------------------------------------------------------------------

procedure UpdateMarginStats is
  X   : integer;
  Y,L : long_integer;
begin
  if ShowingMarginStats then                                   -- wide display?
     X := GetPosition( SourceBox );                            -- cursor x
     if X /= LastCursorPosX then                               -- change?
        SetText( CursorPosX, "Column:" & integer'image( X ) );     -- update X=
        Draw( CursorPosX );
	LastCursorPosX := X;
     end if;
     Y := GetCurrent( SourceBox );                             -- cursor y
     if Y /= LastCursorPosY then                               -- change?
        SetText( CursorPosY, "   Row:" & long_integer'image( Y ) );-- update Y=
        Draw( CursorPosY );
	LastCursorPosY := Y;
     end if;
     L := GetLength( SourceBox );                              -- file len
     if L /= LastDocLength then                                -- change?
	LastDocLength := L;
        SetText( DocLength, "  Size:" & long_integer'image( L ) ); -- update L=
        Draw( DocLength );
     end if;
  end if;
end UpdateMarginStats;

function GetLastWord return str255 is
   ch : character;
   posn  : positive;
   i     : natural;
   first : natural;
   last  : natural;
   text  : str255;

   function isIdentChar( ch : character ) return boolean is
   begin
     return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
       (ch = '_' ) or (ch = '.' );
   end isIdentChar;

begin
    posn := GetPosition( SourceBox );
    if posn = 1 then
       return nullstr255;
    end if;
    posn := posn - 1;
    CopyLine( SourceBox, text );
    ch := element( text, posn );
    if not isIdentChar( ch ) then
       return nullstr255;
    end if;
    i := natural( posn );
    while i > 1 loop
       ch := element( text, i-1 );
       if isIdentChar( ch ) then
           i := i - 1;
       else
           exit;
       end if;
    end loop;
    first := i;
    i := i + 1;
    if i > length( text ) then
       i := i - 1;
    else
       while i < length( text ) loop
          ch := element( text, i );
          if isIdentChar( ch ) then
             i := i + 1;
          else
             i := i - 1;
             exit;
          end if;
       end loop;
    end if;
    last := i;
    return to255( Slice( text, first, last ) );
end GetLastWord;

procedure ShowAutoHelp is
  text : str255;
  word : str255;
  fp   : functionDataPtr;
begin
  if AutoHelpStyle = none then
     return;
  end if;
  word := GetLastWord;
  if length( word ) = 0 then
     return;
  end if;
  fp := findFunctionData( languageData, sourceLanguage, word );
  if fp /= null then
     if AutoHelpStyle = Info or AutoHelpStyle = both then
        text := text & unpack( fp.functionInfo.all );
     end if;
     if fp.functionProto'length > 0 then
        if AutoHelpStyle = both and fp.FunctionInfo.all'length > 0 then
           text := text & " / ";
        end if;
        if AutoHelpStyle = proto or AutoHelpStyle = both then
           declare
              unpacked : string := unpack( fp.functionProto.all );
           begin
              if length( text ) + unpacked'length < 255 then
                 text := text & unpacked;
              end if;
           end;
        end if;
     end if;
     if length( text ) = 0 then
        text := to255( "No help" );
     end if;
     text := fp.functionName.all & ": " & text;
     SetInfoText( text );
  end if;
end ShowAutoHelp;


------------------------------------------------------------------------------
-- DIALOG CALLBACKS
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- OUTPUT FILTER
--
-- This callback is executed after the Window Manager has allowed a window
-- control to act on an input event.  In this case, check to see if the
-- cursor position has changed in the source edit box and update the
-- location information in the right margin.
------------------------------------------------------------------------------

procedure OutputFilter( DT : in out ADialogTaskRecord ) is
begin
  if ShowingMarginStats then
     if DT.InputRec.InputType = KeyInput or DT.InputRec.InputType = ButtonUpInput then
        UpdateMarginStats;
     end if;
  end if;
end OutputFilter;


------------------------------------------------------------------------------
-- INPUT FILTER
--
-- This callback is executed before the Window Manager has allowed a window
-- control to act on an input event.  In this case, intercept alt keys
-- giving them new meanings...to access the items in the drop-down menus.
------------------------------------------------------------------------------

procedure InputFilter( DT : in out ADialogTaskRecord ) is

  procedure PullDownMenu( MenuKey, ItemKey : character ) is
    fakeInput : AnInputPtr;
  begin
    fakeInput := new AnInputRecord( KeyInput );
    fakeInput.Timestamp := DT.InputRec.TimeStamp-1;
    fakeInput.key := character'val( character'pos( ItemKey ) + 128 );
    -- option "b" (queue this up)
    SetInput( fakeInput.all, useTime => true );
    DT.InputRec.Key := character'val( character'pos( MenuKey ) + 128 );
    -- in Misc menu
    Free( fakeInput );
     -- alt-k to check?
  end PullDownMenu;

  key : character;
begin
  if DT.InputRec.InputType /= KeyInput then
     return;
  end if;
  if character'pos( DT.InputRec.Key ) > 128 then
     key := character'val( character'pos( DT.InputRec.Key ) - 128 );
     case key is
     when '$' => PullDownMenu( 'f', '$' ); -- alt-$ = File / Print
     when '!' => PullDownMenu( 'f', '!' ); -- alt-! = File / Save As
     when 'a' => PullDownMenu( 'e', 'a' ); -- alt-a = Edit / Append
     when 'b' => PullDownMenu( 'p', 'b' ); -- alt-b = Misc / Build
     when 'g' => PullDownMenu( 'i', 'g' ); -- alt-g = Find / Goto
     when 'k' => PullDownMenu( 'f', 'k' ); -- alt-k = File / Check
     when 'n' => PullDownMenu( 'i', 'n' ); -- alt-n = Find / Next
     when 'o' => if DisplayInfo.H_Res <= 90 then
           -- only applies if open button isn't visible
           PullDownMenu( 'f', 'o' ); -- alt-n = File / Open
         end if;
     when 's' => PullDownMenu( 'f', 's' ); -- alt-s = File / Save
     when 't' => PullDownMenu( 'm', 't' ); -- alt-t = Misc / Stats
     when 'q' => PullDownMenu( 'f', 'q' ); -- alt-q = File / Quit
     when 'u' => PullDownMenu( 'm', 'u' ); -- alt-u = Misc / GUI Builder
     when 'x' => PullDownMenu( 'i', 'x' ); -- alt-x = Edit / Next Error
     when 'y' => PullDownMenu( 'i', 'y' ); -- alt-e = Find / Find
     when others => null;
     end case;
  elsif character'pos( DT.InputRec.Key ) = 13 then
     Proj_LineCount := Proj_LineCount + 1;
     Opt_KeyCount := Opt_KeyCount + 1;
     Proj_KeyCount := Proj_KeyCount + 1;
  elsif DT.Inputrec.Key = '(' or DT.Inputrec.Key = ' ' or DT.Inputrec.Key = ';' then
     ShowAutoHelp;
  end if;
  if DT.InputRec.Key >= ' ' and character'pos( DT.InputRec.Key ) < 127 then
     -- don't count control keys or delete key
     Opt_KeyCount := Opt_KeyCount + 1;
     Proj_KeyCount := Proj_KeyCount + 1;
  end if;
  MoveToGlobal( 1, 1 );
end InputFilter;


------------------------------------------------------------------------------
-- MENU INPUT FILTER
--
-- This callback is executed while in the drop-down menus.  It intercepts
-- mouse clicks outside of the menu and translates them to "Cancel".
------------------------------------------------------------------------------

procedure MenuInputFilter( DT : in out ADialogTaskRecord ) is

  procedure CancelMenu is
    fakeInput : AnInputPtr;
  begin
    fakeInput := new AnInputRecord( KeyInput );
    fakeInput.Timestamp := DT.InputRec.TimeStamp;
    fakeInput.key := character'val( character'pos( 'l' ) + 128 ); -- l=cancel
    SetInput( fakeInput.all, useTime => true );
    Free( fakeInput );
    -- leave the click on the queue for now -- does nothing
  end CancelMenu;

begin
  if DT.InputRec.InputType = ButtonUpInput then
     if not InRect( DT.InputRec.UpLocationX,
                    DT.InputRec.UpLocationY, 
                    GetWindowFrame( CurrentWindow ) ) then
        CancelMenu;
     end if;
  end if;
end MenuInputFilter;


------------------------------------------------------------------------------
-- PIPES
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- PIPE
--
-- Create an input pipe.  For use by the building window to show the output
-- of the building program while it is running.
------------------------------------------------------------------------------

procedure Pipe( s : str255 ) is
-- open a pipe to read, typically for building
begin
  SessionLog( "Pipe: Opening pipe to " & s & " ..." );
  PipeID := popen( ToString( s ) & " 2>&1" & ASCII.NUL, "r"  & ASCII.NUL);
  EndOfPipe := false;
end Pipe;


------------------------------------------------------------------------------
-- PIPE FINISHED
--
-- Close a pipe opened with pipe procedure.
------------------------------------------------------------------------------

function PipeFinished return boolean is
  Result : integer;
begin
  if EndOfPipe then
    pclose( Result, PipeID );
    return true;
  else
    return false;
  end if;
end PipeFinished;


------------------------------------------------------------------------------
-- NEXT PIPE LINE
--
-- Read a string from the pipe.  Mark the pipe closed when input is complete.
------------------------------------------------------------------------------

procedure NextPipeLine( s : out str255 ) is
  -- read a string from the pipe
    Result : integer;
begin
  s := NullStr255;
  loop
    Result := fgetc( PipeID );
    exit when Result = 10;
    exit when Result = -1;
    s := s & character'val( Result );
  end loop;
  If Result = -1 then
     EndOfPipe := true;
  end if;
end NextPipeLine;


------------------------------------------------------------------------------
-- GET PLATFORM SIG
--
-- Get a string uniquely identifying the development environment.  This string
-- is the platform signature, or platform sig.  It consists of the uname info
-- + version of gnat + libc version,  separated by caret characters.
-- e.g. Linux 2.2.8 i586 ^ gnat-3.11p-1-9...
------------------------------------------------------------------------------

procedure GetPlatformSig is
  draftsig: str255 := NullStr255;
  result  : str255;
begin
  -- a platform sig is uname info + version of gnat separated by
  -- a caret character, e.g. Linux 2.2.8 i586 ^ gnat-3.11p-1-9...
  -- first, hardware and machine name from kernel
  draftsig := UNIX( "uname -srm" ) & " ^ ";

  -- and add gnat version info

  if IsFile( To255( "/usr/bin/gnatgcc" ) ) and then
     IsFile( To255( "/bin/rpm" ) ) then
     pragma Debug( SessionLog( "GetPlatformSig: using rpm" ) );
     -- ALT? then use owner of gnatgcc file
     result := UNIX( "rpm -q -f /usr/bin/gnatgcc" );
     if LastError /= 0 then
        draftsig := draftsig & "unknown";
     else
        draftsig := draftsig & result;
     end if;
  elsif UNIX( "gnatmake -v >/dev/null 2>/dev/null" ) then
     pragma Debug( SessionLog( "GetPlatformSig: using gnatmake" ) );
     result := UNIX( "gnatmake -v 2>&1 | head -2 | tail -1 | cut -c1-40" );
     if LastError /= 0 then
        draftsig := draftsig & "unknown";
     else
        draftsig := draftsig & result;
     end if;
  else
     pragma Debug( SessionLog( "GetPlatformSig: using gcc" ) );
     result := UNIX( "gcc --version 2>&1 | head -1 | cut -c1-40" );
     if LastError /= 0 then
        draftsig := draftsig & "unknown";
     else
        draftsig := draftsig & result;
     end if;
  end if;

  -- add ls info about libc library

  draftsig := draftsig & " ^ ";
  draftsig := draftsig & UNIX(
    "ls -l /lib/libc.so.* 2>&1 | head -1 | cut -c40-" );
  if LastError /= 0 then
     draftsig := draftsig & UNIX(
       "ls -l /usr/lib/libc.so.* 2>&1 | head -1 | cut -c40-" ); -- cygwin
  end if;
  if LastError /= 0 then
     draftsig := draftsig & "unknown libc";
  end if;
  SessionLog( "GetPlatformSig: sig is " & draftsig );
  PlatformSig := draftsig;
end GetPlatformSig;


------------------------------------------------------------------------------
-- LOADING AND SAVING
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- LOCK PROJECT
--
-- Lock the project file.  Record success in ProjectLocked variable so we can
-- determine if the project is already locked and this is a read-only session.
-- If there is any error, assume that it is already locked
------------------------------------------------------------------------------

procedure LockProject is
  EAGAIN : constant integer := 11;
  EACCES : constant integer := 13;
  F_SETLK : constant integer := 6;
  Result  : integer;
begin
  C_reset_errno; -- GCC 3.x workaround for errno := 0;
  ProjectLockFile := open( ToString( ProjectPath ) & ASCII.NUL,
     8#2001#, 8#640# );
  -- write only, append, usual mode
  if ProjectLockFile = -1 then
     SessionLog( "LockProject: Open " & ProjectPath & " failed; errno " &
       C_errno'img );
     return;
  elsif ProjectLockFile < 3 then
     SessionLog( "LockProject: Open " & ProjectPath & " returned unexpected file number " & ProjectLockFile'img );
     ProjectLockFile := -1;
     return;
  end if;
  fcntl( Result, ProjectLockFile,               -- with the project file
         operation => F_SETLK,                  -- lock it
         lock => myLock );                      -- with a write lock
  ProjectLocked := Result /= -1;                -- no error, then it's locked
  if not ProjectLocked and then (C_errno /= EACCES and C_errno /= EAGAIN) then
     SessionLog( "LockProject: " & ProjectPath & " lock failed; errno " & C_errno'img );
  elsif ProjectLocked then
     SessionLog( "LockProject: Project " & ProjectPath & " locked" );
  else
     SessionLog( "LockProject: Project " & ProjectPath & " not locked -- read-only" );
  end if;
  -- if lock failed, make sure file is closed
  if not ProjectLocked and ProjectLockFile > 2 then
     Close( ProjectLockFile );
  end if;
end LockProject;


------------------------------------------------------------------------------
-- LOCK PROJECT
--
-- unlock a locked project by closing the file, discarding locks Note: a new
-- project is "locked" even though no project file exists yet, so make sure
-- lock file number is not 0 to be safe
------------------------------------------------------------------------------

procedure UnlockProject is
begin
  if ProjectLocked and ProjectLockFile > 2 then
     Close( ProjectLockFile );
  end if;
end UnlockProject;


------------------------------------------------------------------------------
-- GET PATH SUFFIX
--
-- Return the suffix of a pathname (e.g. ".c", ".adb", ".java", etc.                       --
------------------------------------------------------------------------------

function getPathSuffix( SourcePath : Str255 ) return Str255 is
   Suffix : Str255;
begin
   Suffix := NullStr255;
   for i in reverse 1..length( SourcePath ) loop
       if Element( SourcePath, i ) = '.' then
          Suffix := To255( Slice( SourcePath, i, length( SourcePath )));
          exit;
       end if;
   end loop;
   return Suffix;
end getPathSuffix;


------------------------------------------------------------------------------
-- SET SOURCE LANGUAGE
--
-- Set the SourceLanguage variable based on the source file suffix.
------------------------------------------------------------------------------

procedure SetSourceLanguage( path : str255 := NullStr255 ) is
  FilePath : str255;
  Suffix : Str255;
begin
  if length( path ) = 0 then
     FilePath := SourcePath;
  else
     FilePath := path;
  end if;
  if length( FilePath ) = 0 then
     SourceLanguage := unknownLanguage;
     return;
  end if;
  Suffix := GetPathSuffix( FilePath );
  if Suffix = To255( ".adb" ) then
     sourceLanguage := Ada_Language;
  elsif Suffix = To255( ".ads" ) then
     sourceLanguage := Ada_Language;
  elsif Suffix = To255( ".ada" ) then
     SourceLanguage := Ada_Language;
  elsif Suffix = To255( ".h" ) or
     Suffix = To255( ".c" ) then
     SourceLanguage := C;
  elsif Suffix = To255( ".cpp" ) then
     SourceLanguage := CPP;
  elsif Suffix = To255( ".java" ) then -- GCC Java? How to detect?
     SourceLanguage := Java;
  elsif Suffix = To255( ".bush" ) then
     SourceLanguage := Bush;
  elsif Suffix = To255( ".pl" ) then
     SourceLanguage := Perl;
  elsif Suffix = To255( ".pm" ) then
     SourceLanguage := Perl;
  elsif Suffix = To255( ".html" ) then
     SourceLanguage := HTML;
  elsif Suffix = To255( ".tmpl" ) then
     SourceLanguage := HTML;
  elsif Suffix = To255( ".sh" ) then
     SourceLanguage := Shell;
  elsif Suffix = To255( ".bash" ) then
     SourceLanguage := Shell;
  elsif Suffix = To255( ".php" ) then
     SourceLanguage := PHP;
  else
     SessionLog( "SetSourceLanguage: can't identifing " & suffix );
     SourceLanguage := unknownLanguage;
  end if;

end SetSourceLanguage;


------------------------------------------------------------------------------
-- LOAD SOURCE FILE
--
-- Load a source file as a string list.  Handle loading errors.  Converted
-- tabs (used for keyboard navigation in tia) to spaces.  Convert DOS files
-- to UNIX.
------------------------------------------------------------------------------

procedure LoadSourceFile( Path : str255; Text : out Str255List.List ) is
  TempStr : str255;
  TabPos  : natural;
begin

  -- Load the text

  LoadList( Path, Text );
  if LastError /= TT_OK then
     case LastError is
     when TT_FileLocking =>
        CautionAlert( "File is locked" );
     when TT_FileExistance =>
        StopAlert( "File does not exist" );
     when TT_LowMemory =>
        StopAlert( "Out of memory" );
     when others =>
        StopAlert( "An unexpected error occurred while loading the file" );
     end case;
     Str255List.Clear( Text );
     return;
  end if;


  for i in 1..Str255List.Length( Text ) loop
      -- DOS CR check
      Str255List.Find(  Text, i, TempStr );
      if length( TempStr ) > 0 then
         if element( TempStr, length( TempStr ) ) = ASCII.CR then
            delete( TempStr, length( TempStr ), length( TempStr ) );
         end if;
      end if;
      -- Convert tabs to spaces and remove DOS CR's
      loop
         tabpos := Index( TempStr, "" & ASCII.HT );
         exit when tabpos = 0;
         delete( TempStr, tabPos, tabPos );
         loop
            insert( TempStr, tabPos, " " );
	    tabPos := tabPos + 1;
	    exit when ((tabPos-1) mod 8 = 0);
         end loop;
      end loop;
      Str255List.Replace( Text, i, TempStr );
  end loop;
exception when name_error =>
  CautionAlert( "File not found" );
when status_error =>
  CautionAlert( "File cannot be read" );
when end_error =>
  StopAlert( "Internal error: read past EOF" );
when mode_error =>
  StopAlert( "Internal error: mode_error raised" );
when constraint_error =>
  StopAlert( "Internal error: constraint_error raised" );
when ada.strings.length_error =>
  CautionAlert( "Lines in the file are too long" );
when others =>
  StopAlert( "There was a problem loading the file" );
end LoadSourceFile;


------------------------------------------------------------------------------
-- SAVE SOURCE FILE
--
-- Save a list of strings to a text file.  Strip trailing spaces off of lines.
-- Handle saving errors.
------------------------------------------------------------------------------

procedure SaveSourceFile( Path : str255; Text : out Str255List.List ) is
  TempStr : str255;
  ch      : character;
  changed : boolean;
begin

  -- Strip trailing spaces on lines

  for i in 1..Str255List.Length( Text ) loop
      Str255List.Find( Text, i, TempStr );
      changed := false;
      while length( TempStr ) > 0 loop
	 exit when Element( TempStr, length( TempStr ) ) /= ' ';
         Delete( TempStr, length( TempStr ), length( TempStr ) );
	 changed := true;
      end loop;
      if changed then
         Str255List.Replace( Text, i, TempStr );
      end if;
  end loop;

  -- Save the text

  begin
    SaveList( Path, Text );
    if LastError /= TT_OK then
       case LastError is
       when TT_FileLocking =>
          CautionAlert( "File is locked" );
       when TT_FileExistance =>
          StopAlert( "File does not exist" );
       when TT_LowMemory =>
          StopAlert( "Out of memory" );
       when others =>
          StopAlert( "An unexpected error occurred while saving the file" );
       end case;
    end if;
  exception when Constraint_Error =>
    StopAlert( "An unexpected constraint error occurred" );
  end;

end SaveSourceFile;


------------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- BASENAME
--
-- Return the file name from a pathname.
------------------------------------------------------------------------------

function basename( s : str255 ) return string is
  -- extract a filename from a path
begin
  for i in reverse 1..length( s )-1 loop
      if element( s, i ) = '/' then
         return slice( s, i+1, length( s ) );
      end if;
  end loop;
  -- root directory
  if length( s ) > 0 then
     if element( s, length( s ) ) = '/' then
        return ".";
     end if;
  end if;
  -- no directory
  return ToString(s);
end basename;


function stringField( s : str255; delimiter : character; f : natural )
return str255 is
-- return the fth field delimited by delimiter
  firstPos    : natural := 1;
  currentPos  : natural := 1;
  delimCnt    : natural := 0;
  returnStr   : str255;
begin
  if f = 0 or length( s ) = 0 then
     return nullstr255;
  end if;
  for i in 1..length( s ) loop
      if Element( s, i ) = delimiter then
         delimCnt := delimCnt + 1;
         if delimCnt = f then
            begin
              returnStr := to255( Slice( s, firstPos, i-1 ) );
            exception when others =>
              returnStr := nullstr255;
            end;
            return returnStr;
         end if;
         firstPos := i+1;
      end if;
  end loop;
  if delimCnt+1 < f then
     return nullstr255;
  else
     return to255( Slice( s, firstPos, length( s ) ) );
  end if;
end stringField;

--  STRING FIELD
--
-- Extra the fth field as separated by delimiter in the string s.  If nothing,
-- return a null string.
------------------------------------------------------------------------------

function stringField( s : unbounded_string; delimiter : character; f : natural )
return unbounded_string is
-- return the fth field delimited by delimiter
  firstPos    : natural := 1;
  currentPos  : natural := 1;
  delimCnt    : natural := 0;
  returnStr   : unbounded_string;
begin
  if f = 0 or length( s ) = 0 then
     return null_unbounded_string;
  end if;
  for i in 1..length( s ) loop
      if Element( s, i ) = delimiter then
         delimCnt := delimCnt + 1;
         if delimCnt = f then
            begin
              returnStr := to_unbounded_string( Slice( s, firstPos, i-1 ) );
            exception when others =>
              returnStr := null_unbounded_string;
            end;
            return returnStr;
         end if;
         firstPos := i+1;
      end if;
  end loop;
  if delimCnt+1 < f then
     return null_unbounded_string;
  else
     return to_unbounded_string( Slice( s, firstPos, length( s ) ) );
  end if;
end stringField;

function ToLower( s : unbounded_string ) return unbounded_string is
  ch : character;
  newstr : unbounded_string;
begin
  newstr := s;
  for i in 1..length( s ) loop
      ch := Element( s, i );
      if ch >= 'A' and ch <= 'Z' then
         ch := character'val( character'pos( ch ) + 32 );
         Replace_Element( newstr, i, ch );
      end if;
  end loop;
  return newstr;
end ToLower;


------------------------------------------------------------------------------
-- KEYWORD HILIGHTING
------------------------------------------------------------------------------


--  ADD KEYWORD
--
-- Add a language's keyword to the language data record.
------------------------------------------------------------------------------

  procedure addKeyword( keyLang : aSourceLanguage; keyName, keyInfo, keyProto : unbounded_string ) is
    kp : keywordDataPtr := new keywordData;
    fp : functionDataPtr := null;
  begin
    if languageData( keyLang ).caseSensitive then
       kp.keywordName  := new string'( to_string( keyName ) );
    else
       kp.keywordName  := new string'( to_string( ToLower( keyName ) ) );
    end if;
    kp.keywordInfo  := new packed_string'( basic_pack( to_string( keyInfo ) ) );
    kp.keywordProto := new packed_string'( basic_pack( to_string( keyProto ) ) );
    kp.next := languageData( keyLang ).keywordBin( in_bin( to_string( keyName ) ) );

    fp := languageData( keyLang ).functionBin( in_bin( to_string( keyName ) ) );

    languageData( keyLang ).keywordBin( in_bin( to_string( keyName ) ) ) := kp;
    languageData( keyLang ).keywordCount := languageData( keyLang ).keywordCount + 1;

    if fp /= languageData( PHP ).functionBin( in_bin( to_string( keyName ) ) ) then
       put_line( standard_error, "integrity error on " & keyLang'img & '/' & keyName );
    end if;
  end addKeyword;

--  ADD FUNCTION
--
-- Add a language's function to the language data record.
------------------------------------------------------------------------------

  procedure addFunction( funcLang : aSourceLanguage; funcName, funcInfo, funcProto : unbounded_string ) is
    fp : functionDataPtr := new functionData;
  begin
    if languageData( funcLang ).caseSensitive then
       fp.functionName  := new string'( to_string( funcName ) );
    else
       fp.functionName  := new string'( to_string( ToLower( funcName ) ) );
    end if;
    fp.functionInfo  := new packed_string'( basic_pack( to_string( funcInfo ) ) );
    fp.functionProto := new packed_string'( basic_pack( to_string( funcProto ) ) );
    fp.next := languageData( funcLang ).functionBin( in_bin( to_string( funcName ) ) );
    languageData( funcLang ).functionBin( in_bin( to_string( funcName ) ) ) := fp;
    languageData( funcLang ).functionCount := languageData( funcLang ).functionCount + 1;
  end addFunction;

--  LOAD LANGUAGE DATA
--
-- Load the language data file for TIA.  Can raise I/O errors or format_error
-- if there's a problem with the format of the data file.
------------------------------------------------------------------------------

  procedure loadLanguageData is
    f : File_Type;
    textFileLine      : unbounded_string;
    textFileItemType  : unbounded_string;
    textFileLanguage  : unbounded_string;
    textFileFuncName  : unbounded_string;
    textFileFuncInfo  : unbounded_string;
    textFileFuncProto : unbounded_string;
    textFileExtra     : unbounded_string;
    ch : character;
  begin

    init( languageData => languageData );

    -- Open tia language definition file
    begin
      open( f, in_file, toString( ExpandPath( to255( "$HOME/." & languageFileName ) ) ) );
    exception when name_error =>
      open( f, in_file, "/usr/share/tia/" & languageFileName );
    when others => raise;
    end;

    while not end_of_file( f ) loop
       textFileLine := get_line( f );

       -- Check character values

       for i in 1..length( textFileLine ) loop
           ch := element( textFileLine, i );
           if character'pos( ch ) >= 128 then
              close( f );
              SessionLog( to_string( textFileLine ) );
              SessionLog( "loadLanguageData: upper ascii character detected" );
              raise format_error;
           end if;
       end loop;

       if length( textFileLine ) = 0 then
          goto next;
       elsif element( textFileLine, 1 ) = '#' then
          goto next;
       end if;

       -- Extract the fields

       textFileItemType  := stringField( textFileLine, '|', 1 );
       textFileLanguage  := stringField( textFileLine, '|', 2 );
       textFileFuncName  := stringField( textFileLine, '|', 3 );
       textFileFuncInfo  := stringField( textFileLine, '|', 4 );
       textFileFuncProto := stringField( textFileLine, '|', 5 );
       textFileExtra     := stringField( textFileLine, '|', 6 );
       if length( textFileItemType ) /= 1 then
          close( f );
          SessionLog( to_string( textFileLine ) );
          SessionLog( "loadLanguageData: The item type is not one character" );
          raise format_error;
       elsif length( textFileExtra ) > 0 then
          close( f );
          SessionLog( to_string( textFileLine ) );
          SessionLog( "loadLanguageData: unexpected stuff: perhaps an embedded vertical bar?" );
          raise format_error;
       end if;

       -- Add the data in the linked lists

       declare
          lang : aSourceLanguage;
       begin
          lang := aSourceLanguage'value( to_string( textFileLanguage ) );
          if to_string( textFileItemType ) = "F" then
             addFunction( lang, textFileFuncName, textFileFuncInfo, textFileFuncProto );
          elsif to_string( textFileItemType ) = "K" then
             addKeyword( lang, textFileFuncName, textFileFuncInfo, textFileFuncProto );
          else
             close( f );
             SessionLog( to_string( textFileLine ) );
             SessionLog( "loadLanguageData: item type not F or K" );
             raise format_error;
          end if;
       exception when constraint_error =>
          SessionLog( to_string( textFileLine ) );
          SessionLog( "loadLanguageData: No such language: '" & to_string( textFileLanguage ) & "'");
          close( f );
          raise format_error;
       end;
       <<next>> null;
    end loop;

    -- Finalize

    close( f );
    if languageData( unknownlanguage ).functionCount > 0 then
       SessionLog( "loadLanguageData: unknownlanguage function count unexpectedly non-zero" );
       raise format_error;
    end if;
    if languageData( unknownlanguage ).keywordCount > 0 then
       SessionLog( "loadLanguageData: unknownlanguage keyword count unexpectedly non-zero" );
       raise format_error;
    end if;
    declare
       fp : functionDataPtr;
       kp : keywordDataPtr;
    begin
    for lang in aSourceLanguage'range loop
        for bin in aBinIndex'range loop
            kp := languageData( lang ).keywordBin( bin );
            while kp /= null loop
               fp := findFunctionData( languageData, lang, kp.keywordName.all );
               if fp /= null then
                  SessionLog( "loadLanguageData: " & lang'img & '/' & kp.keywordName.all & " is both a keyword and a function" );
                  raise format_error;
               end if;
               kp := kp.next;
            end loop;
        end loop;
    end loop;
    end;
  end loadLanguageData;

end tiacommon;

