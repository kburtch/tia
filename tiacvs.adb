------------------------------------------------------------------------------
-- TIA CVS - CVS interface for TIA                                          --
--                                                                          --
-- Developed by Ken O. Burtch                                               --
------------------------------------------------------------------------------
--                                                                          --
--                Copyright (C) 1999-2007 PegaSoft Canada                   --
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

with ada.text_io, -- for printing results in non-interactive modes
     ada.command_line.environment, -- for return result code, etc.
     common,    -- texttools' root package
     os,        -- clock and O/S stuff for Ken's windows
     strings,   -- Ken's string functions
     userio,    -- Ken's ASCII drawing stuff
     controls,  -- controls for Ken's windows
     windows,   -- Ken's windows
     english,   -- common English words
     tiacommon; -- tia common definitions
use  common, os, strings, userio, controls, windows, english,
     tiacommon;

Pragma Optimize( Space );
-- make program as small as possible


package body tiacvs is ---------------------------------------------

LastCVSCommLine : str255 := To255( "Comment Here" );

function shell_escape( s : str255 ) return str255 is
  -- escape special Bourne shell characters in string
  newstr : str255;
  ch : character;
begin
  for i in 1..length( s ) loop
      ch := element( s, i );
      case ch is
      when ''' => newstr := newstr & '\' & ch;
      when '"' => newstr := newstr & '\' & ch;
      when '\' => newstr := newstr & '\' & ch;
      when '`' => newstr := newstr & '\' & ch;
      when '$' => newstr := newstr & '\' & ch;
      when '(' => newstr := newstr & '\' & ch;
      when ')' => newstr := newstr & '\' & ch;
      when ' ' => newstr := newstr & '\' & ch;
      when others => newstr := newstr & ch;
      end case;
  end loop;
  return newstr; 
end shell_escape;

-------------------------------------------------------
-- CVS Import                                        --
--                                                   --
-- Save a new project in the CVS repository using    --
-- "cvs import".  The user is prompted for an import --
-- name.                                             --
-------------------------------------------------------

procedure CVSImport is

  procedure SuccessAlert( ProjectName : Str255 ) is
     Desc1Line : aliased AStaticLine;
     Desc2LIne : aliased AStaticLine;
     Desc3LIne : aliased AStaticLine;
     Desc4LIne : aliased AStaticLine;
     Desc5LIne : aliased AStaticLine;
     OKButton  : aliased ASimpleButton;

     DT : aDialogTaskRecord;
  begin

   OpenWindow( To255( "Project Shared" ), 1, 1, 78, 12 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "The project has been saved in the CVS repository.  In order to work on the" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "project. you must stop TIA, delete your copy of the project and check out" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "the project using the cvs co command:" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 6, 76, 6 );
   SetText( Desc4Line, "  cvs co " & ProjectName );
   AddControl( Desc4Line'unchecked_access, false );

   Init( Desc5Line, 1, 8, 76, 8 );
   SetText( Desc5Line, "After checking out the project, restart TIA." );
   AddControl( Desc5Line'unchecked_access, false );

   Init( OKButton, 35, 10, 45, 10, 'o' );
   SetText( OKButton, To255( "OK" ) );
   AddControl( OKButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

  end SuccessAlert;

  Desc1Line : aliased AStaticLine;
  Desc2Line : aliased AStaticLine;
  Desc3Line : aliased AStaticLine;
  Desc4Line : aliased AStaticLine;
  Desc5Line : aliased AStaticLine;
  PathLine  : aliased AnEditLine;
  --LocalBox  : aliased ACheckBox;
  OKButton  : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;
  DT : ADialogTaskRecord;

  CVScmd   : Str255;
  TempStr  : Str255;
  TempFile : Str255;           -- file holding results of CVS command
  TempList : Str255List.List;  -- for reading CVS results
  ThisPath : Str255;           -- the project path
  ImportPath : Str255;         -- default path for cvs import
begin
   MakeTempFileName( TempFile );
   ThisPath := GetPath;
   SetPath( To255( "$HOME" ) );
   ImportPath := Tail( ThisPath, length( ThisPath ) - length( GetPath ) -1 );
   SetPath( ThisPath );

   OpenWindow( To255( "Share Project by Importing to CVS Repository" ),
     1, 1, 78, 15 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "Projects may be shared with other team members using CVS.  If you are not on" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "a team, CVS can still be used to track and rollback the changes in your" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "project.  CVS requires a pathname by which this project will be known." );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 5, 76, 5 );
   SetText( Desc4Line, "For simple projects, a one word pathname is adequate." );
   AddControl( Desc4Line'unchecked_access, false );

   Init( Desc5Line, 1, 7, 76, 7 );
   SetText( Desc5Line, "If you don't want to save this project with CVS, select Cancel." );
   AddControl( Desc5Line'unchecked_access, false );

   --Init( LocalBox, 1, 9, 76, 9, 'I' );
   --SetText( LocalBox, To255( "Include files in subdirectories" ) );
   --AddControl( CheckBox, LocalBox'unchecked_access, false );
   --SetCheck( LocalBox, true );

   Init( PathLine, 1, 11, 76, 11 );
   SetText( PathLine, ImportPath );
   AddControl( PathLine'unchecked_access, false );

   Init( OKButton, 15, 13, 35, 13, 'n' );
   SetText( OKButton, To255( "New CVS Project" ) );
   AddControl( OKButton'unchecked_access, false );

   Init( CancelButton, 50, 13, 65, 13, 'l' );
   SetText( CancelButton, To255( "Cancel" ) );
   AddControl( CancelButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   if DT.control = 8 then -- cancel?
      return;             -- give up
   end if;

   ImportPath := GetText( PathLine );

   -- To import the current directory, use
   -- cvs import -m message archive-path name tag
   CVScmd := To255( "cvs import " );
   CVSCmd := CVScmd & " -m " & '"' & "imported by TIA" & '"' & " " &
      ImportPath & " " & shell_escape( UNIX( "echo $LOGNAME" ) ) &
      " initial-release";

   UNIX( "echo '" & CVScmd & "' > " & TempFile );
   SessionLog( "CVSImport: " & CVSCmd );
   UNIX( CVScmd & " >>" & TempFile & " 2>&1");

   -- Load the results into TempList.  The last line of the CVS
   -- output should begin with "No conflicts" if successful.

   LoadList( TempFile, TempList );
   Erase( TempFile );
   Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
   SessionLog( TempStr );
   if Head( TempStr, 12 ) = "No conflicts" then
      SuccessAlert( ImportPath );
      Str255List.Clear( TempList );
      return;
   else
      ShowListInfo( "Problems Importing Project with CVS", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
      Str255List.Clear( TempList );
   end if;
   Str255List.Clear( TempList );
end CVSImport;


-------------------------------------------------------
-- CVS Commit                                        --
--                                                   --
-- Save changes to an existing project in the CVS    --
-- repository using "cvs commit".  The user is       --
-- prompted for submission comment.                  --
-------------------------------------------------------

procedure CVSCommit is
  CVScmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
  Comment  : Str255;

  Desc1Line : aliased AStaticLine;
  Desc2Line : aliased AStaticLine;
  Desc3Line : aliased AStaticLine;
  Desc4Line : aliased AStaticLine;
  Desc5Line : aliased AStaticLine;
  CommLine  : aliased AnEditLine;
  OKButton  : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;
  DT : ADialogTaskRecord;
begin
  MakeTempFileName( TempFile );

  -- The CVS Commit dialog.  Prompt for a comment

   OpenWindow( To255( "Share Changes in Project with CVS Repository" ), 1, 1, 78, 13 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "To save this project using CVS, you need to give a description of the" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "changes.  CVS will assign a new version number to the project and record" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "all the changes since the last time this project was saved.  The comment" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 5, 76, 5 );
   SetText( Desc4Line, "should indicate features you've added or problems you've fixed." );
   AddControl( Desc4Line'unchecked_access, false );

   Init( Desc5Line, 1, 7, 76, 7 );
   SetText( Desc5Line, "If you don't want to save this project with CVS, select Cancel." );
   AddControl( Desc5Line'unchecked_access, false );

   Init( CommLine, 1, 9, 76, 9 );
   SetText( CommLine, LastCVSCommLine );
   AddControl( CommLine'unchecked_access, false );

   Init( OKButton, 20, 11, 35, 11, 's' );
   SetText( OKButton, To255( "New Version" ) );
   AddControl( OKButton'unchecked_access, false );

   Init( CancelButton, 50, 11, 65, 11, 'l' );
   SetText( CancelButton, To255( "Cancel" ) );
   AddControl( CancelButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   if DT.control = 8 then -- cancel?
      return;             -- give up
   end if;
   LastCVSCommLine := GetText( CommLine );

   Comment := GetText( CommLine );  -- get the comment

  -- changes are commited using the CVS command
  -- "cvs commit -m comment ."

  CVScmd := "cvs commit -m " & shell_escape( Comment ) & " .";
  UNIX( "echo -e '" & CVScmd & "\n' > " & TempFile );
  SessionLog( "CVScommit: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );
  ShowListInfo( "Committed Project to CVS Repository", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList, last => true );
  Str255List.Clear( TempList );
end CVSCommit;


-------------------------------------------------------
-- CVS Update                                        --
--                                                   --
-- Merge changes with the project with the copy in   --
-- the CVS repository.  Changes are not committed.   --
-------------------------------------------------------

procedure CVSUpdate is
  CVSCmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
  TempStr  : Str255;
  Comment  : Str255;

  Desc1Line : aliased AStaticLine;
  Desc2Line : aliased AStaticLine;
  Desc3Line : aliased AStaticLine;
  Desc4Line : aliased AStaticLine;
  Desc5Line : aliased AStaticLine;
  Desc6Line : aliased AStaticLine;
  LocalBox  : aliased ACheckBox;
  CommLine  : aliased AnEditLine;
  OKButton  : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;
  DT : ADialogTaskRecord;
begin
   MakeTempFileName( TempFile );

  -- The CVS Commit dialog.  Prompt for a comment

   OpenWindow( To255( "Update Project with Differences in CVS Repository" ), 1, 1, 78, 14 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "If this is a team project, TIA can use CVS to apply the latest changes" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "in the project to your files.  Updating sometimes results in a 'collision'" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "between your changes and the changes made by another team member.  If" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 5, 76, 5 );
   SetText( Desc4Line, "you have a collision, you'll have to edit the file in which the conflict" );
   AddControl( Desc4Line'unchecked_access, false );

   Init( Desc5Line, 1, 6, 76, 6 );
   SetText( Desc5Line, "occurred and rectify it manually." );
   AddControl( Desc5Line'unchecked_access, false );

   Init( Desc6Line, 1, 8, 76, 8 );
   SetText( Desc6Line, "To skip updating, select Cancel." );
   AddControl( Desc6Line'unchecked_access, false );

   Init( LocalBox, 1, 10, 76, 10, 'I' );
   SetText( LocalBox, To255( "Include files in subdirectories" ) );
   AddControl( LocalBox'unchecked_access, false );
   SetCheck( LocalBox, true );

   Init( OKButton, 15, 12, 30, 12, 'u' );
   SetText( OKButton, To255( "Update" ) );
   AddControl( OKButton'unchecked_access, false );

   Init( CancelButton, 50, 12, 65, 12, 'l' );
   SetText( CancelButton, To255( "Cancel" ) );
   AddControl( CancelButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   if DT.control = 9 then -- cancel?
      return;             -- give up
   end if;

  -- changes are updated using the CVS command
  -- "cvs update"

  Proj_UpdateTime := GetTimeStamp;

  if GetCheck( LocalBox ) then
     CVScmd := To255( "cvs update" );
  else
     CVScmd := To255( "cvs update -l" );
  end if;
  UNIX( "echo -e '" & CVScmd & "\n' > " & TempFile );
  SessionLog( "CVSupdate: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  -- isn't obvious from cvs output if it's complete or not
  Str255List.Queue( TempList, To255( "Update complete." ) );
  Erase( TempFile );

  -- conflicts testing

  for i in 1..str255list.length( TempList ) loop
      Str255List.Find( TempList, i, TempStr );
      if length( TempStr ) > 2 then
         if Slice( TempStr, 1, 2 ) = "C " then
	    CautionAlert( "There are conflicts in the source code" );
	    goto done;
	 end if;
      end if;
  end loop;
<<done>>

  ShowListInfo( "Updated Project with Latest Changes", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList, last => true );
  Str255List.Clear( TempList );
end CVSUpdate;

-------------------------------------------------------
-- CVS Add                                           --
--                                                   --
-- Add the current source file to the project using  --
-- "cvs add".                                        --
-------------------------------------------------------

procedure CVSAdd is
  CVScmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
  TempStr  : Str255;
begin
   MakeTempFileName( TempFile );

  CVScmd := "cvs add -m " & '"' & "Added by TIA" & '"' & ' ' & SourcePath;
  UNIX( "echo -e '" & CVScmd & "\n' > " & TempFile );
  SessionLog( "CVSAdd: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );

  Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
  SessionLog( TempStr );
  if Index( TempStr, "cvs commit" ) < 1 then
     ShowListInfo( "Problem Adding Your File To CVS Project", 0, 1, DisplayInfo.H_Res-2, 23, TempList );
     Str255List.Clear( TempList );
  end if;
end CVSAdd;

-------------------------------------------------------
-- CVS Log                                           --
--                                                   --
-- Show the CVS log for the current source file      --
-------------------------------------------------------

procedure CVSLog is
  CVScmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
begin
  MakeTempFileName( TempFile );
  CVScmd := "cvs log " & SourcePath;
  SessionLog( "CVSLog: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  if NotEmpty( TempFile ) then
     LoadList( TempFile, TempList );
  else
     Str255List.Queue( TempList, To255( "No changes" ) );
  end if;
  Str255List.Push( TempList, CVScmd );
  Erase( TempFile );
  ShowListInfo( "Change Log", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
  Str255List.Clear( TempList );
end CVSLog;

-------------------------------------------------------
-- CVS Diff                                          --
--                                                   --
-- Perform a CVS diff on the current source file     --
-------------------------------------------------------

procedure CVSDiff is
  CVScmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
begin
  MakeTempFileName( TempFile );
  CVScmd := "cvs diff -c " & SourcePath;
  SessionLog( "CVSDiff: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  if NotEmpty( TempFile ) then
     LoadList( TempFile, TempList );
  else
     Str255List.Queue( TempList, To255( "No differences" ) );
  end if;
  Str255List.Push( TempList, NullStr255 );
  Str255List.Push( TempList, CVScmd );
  Erase( TempFile );
  ShowListInfo( "Differences Since Last Project Commit", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
  Str255List.Clear( TempList );
end CVSDiff;

-------------------------------------------------------
-- CVS Remove                                        --
--                                                   --
-- Remove a file from the repository.                --
-------------------------------------------------------

procedure CVSRemove( RemovePath : Str255 ) is
  CVScmd   : Str255;
  TempFile : Str255;            -- file holding results of CVS command
  TempList : Str255List.List;   -- results of CVS command
  TempStr  : Str255;
begin
  MakeTempFileName( TempFile );
  CVScmd := "cvs remove " & RemovePath;
  SessionLog( "CVSRemove: " & CVSCmd );
  UNIX( CVScmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );
  Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
  if Index( TempStr, " removed `" ) = 0 then
     Str255List.Push( TempList, NullStr255 );
     Str255List.Push( TempList, CVScmd );
     ShowListInfo( "Problem Removing File from CVS Repository", 0, 1, DisplayInfo.H_Res-2, 23, TempList );
  end if;
  Str255List.Clear( TempList );
end CVSRemove;

end tiacvs;

