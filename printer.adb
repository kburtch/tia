------------------------------------------------------------------------------
-- PRINTER - Printer support for TIA                                        --
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
-- This is maintained at http://www.pegasoft.ca/tia                         --
--                                                                          --
------------------------------------------------------------------------------
with Ada.Text_IO, System, tiacommon, os;
use Ada.Text_IO, tiacommon, os;

pragma optimize( space );

package body printer is
  -- a program for simple printing

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

  function fputc( c : integer; fid : AStdioFileID ) return integer;
  pragma import( C, fputc, "fputc" );
  -- part of standard C library.  Writes one charctera to a file.

  function fputs( s : string; fid : AStdioFileID ) return integer;
  pragma import( C, fputs, "fputs" );
  -- part of standard C library.  Writes a string to a file.

  PipeID : AStdioFileID; -- File ID for lpr pipe

  procedure BeginPrinting is
  -- open a pipe to lpr
  begin
    SessionLog( "Opening pipe to lpr ..." );
    PipeID := popen( "lpr" & ASCII.NUL, "w"  & ASCII.NUL);
  end BeginPrinting;

  procedure EndPrinting is
  -- close the pipe.  Result doesn't matter.
  -- Linux normally will not eject a page when
  -- printing is done, so we'll use a form feed.
    Result : integer;
  begin
    SessionLog( "PrintList: Closing pipe to lpr ..." );
    Result := fputc( character'pos( ASCII.FF ), PipeID );        
    pclose( Result, PipeID );
  end EndPrinting;


  --> Input/Output Stuff --------------------------------

  procedure Print( c : character ) is
  -- print a character to the pipe.
    Result : integer;
  begin
    Result := fputc( character'pos( c ), PipeID );        
  end Print;

  procedure Print( s : string ) is
  -- print a string to the pipe, with a carriage
  -- return and line feed.
    Result : integer;
  begin
    Result := fputs( s & ASCII.CR & ASCII.LF & ASCII.NUL, PipeID );
  end Print;


  procedure PrintList( l : in out Str255List.List ) is
    TempStr : Str255;
  begin

  -- Open the pipe to the lpr command

  BeginPrinting;

  -- print header

  Print( "TIA" );
  Print( "   File: " & ToString( SourcePath ) );
  Print( "Project: " & ToString( ProjectPath ) );
  Print( "  Login: " & ToString( UNIX( "echo $LOGNAME" ) ) );
  Print( "   Date: " & ToString( GetLongDate ) & " " &
    ToString( GetTime ) );
  Print( "-----------------------------------------------------------------------------" );
  New_Line;
 
  for i in 1..Str255List.Length( l ) loop
      Str255List.Find( l, i, TempStr );
      Print( ToString( TempStr ) );
  end loop;

  -- Now, close the pipe.

  EndPrinting;
  SessionLog( "PrintList: Printing spooled." );
  exception when others =>
     SessionLog( "PrintList: Unexpected exception when printing" );
     EndPrinting;
  end PrintList;

end printer;
 
