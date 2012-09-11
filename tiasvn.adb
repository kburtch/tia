------------------------------------------------------------------------------
-- TIA SVN - Subversion interface for TIA                                   --
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


package body tiasvn is ---------------------------------------------

LastSVNCommLine : str255 := To255( "Comment Here" );

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
-- SVN Import                                        --
--                                                   --
-- Save a new project in the SVN repository using    --
-- "svn import".  The user is prompted for an import --
-- name.                                             --
-------------------------------------------------------

procedure SVNImport is

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
   SetText( Desc1Line, "The project has been saved in the SVN repository.  In order to work on the" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "project. you must stop TIA, delete your copy of the project and check out" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "the project using the svn co command:" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 6, 76, 6 );
   SetText( Desc4Line, "  svn co " & Proj_Repository );
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
  --Desc4Line : aliased AStaticLine;
  Desc5Line : aliased AStaticLine;
  PathLine  : aliased AnEditLine;
  --LocalBox  : aliased ACheckBox;
  OKButton  : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;
  DT : ADialogTaskRecord;

  SVNcmd   : Str255;
  TempStr  : Str255;
  TempFile : Str255;           -- file holding results of SVN command
  TempList : Str255List.List;  -- for reading SVN results
  ThisPath : Str255;           -- the project path
  ImportPath : Str255;         -- default path for svn import
begin
   MakeTempFileName( TempFile );
   -- in CVS, you have to move to the directory.  Not required for SVN, but
   -- since I copied this from the CVS package, I'll leave it this way.
   ThisPath := GetPath;
   SetPath( To255( "$HOME" ) );
   ImportPath := ThisPath;
   --ImportPath := Tail( ThisPath, length( ThisPath ) - length( GetPath ) -1 );
   SetPath( ThisPath );

   if length( Proj_Repository ) = 0 then
      StopAlert( "Please add the repository URL to the project params" );
      return;
   end if;

   OpenWindow( To255( "Share Project by Importing to Subversion Repository" ),
     1, 1, 78, 15 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "Projects may be shared with other team members using SVN.  If you are not on" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "a team, SVN can still be used to track and rollback the changes in your" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "project.  What is the directory containing this project?" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc5Line, 1, 7, 76, 7 );
   SetText( Desc5Line, "If you don't want to save this project with SVN, select Cancel." );
   AddControl( Desc5Line'unchecked_access, false );

   --Init( LocalBox, 1, 9, 76, 9, 'I' );
   --SetText( LocalBox, To255( "Include files in subdirectories" ) );
   --AddControl( CheckBox, LocalBox'unchecked_access, false );
   --SetCheck( LocalBox, true );

   Init( PathLine, 1, 11, 76, 11 );
   SetText( PathLine, ImportPath );
   AddControl( PathLine'unchecked_access, false );

   Init( OKButton, 15, 13, 35, 13, 'n' );
   SetText( OKButton, To255( "New SVN Project" ) );
   AddControl( OKButton'unchecked_access, false );

   Init( CancelButton, 50, 13, 65, 13, 'l' );
   SetText( CancelButton, To255( "Cancel" ) );
   AddControl( CancelButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   if DT.control = 7 then -- cancel?
      return;             -- give up
   end if;

   ImportPath := GetText( PathLine );

   -- First create the project directory

   SVNcmd := To255( "svn mkdir " ) & Proj_Repository &
             " --message=" & '"' & "imported by TIA" & '"';
   UNIX( "echo '" & SVNcmd & "' > " & TempFile );
   SessionLog( "SVNImport: " & SVNCmd );
   UNIX( SVNcmd & " >>" & TempFile & " 2>&1");

   -- To import the current directory, use
   -- svn import path repository-url --message="message"
   SVNcmd := To255( "svn import " );
   SVNCmd := SVNcmd & " " & shell_escape( ImportPath ) & " " &
             shell_escape( Proj_Repository ) &
             " --message=" & '"' & "imported by TIA" & '"';

   UNIX( "echo '" & SVNcmd & "' >> " & TempFile );
   SessionLog( "SVNImport: " & SVNCmd );
   UNIX( SVNcmd & " >>" & TempFile & " 2>&1");

   -- Load the results into TempList.  The last line of the SVN
   -- output should begin with "No conflicts" if successful.

   LoadList( TempFile, TempList );
   Erase( TempFile );
   Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
   SessionLog( TempStr );
   if Head( TempStr, 18 ) = "Committed revision" then
      SuccessAlert( ImportPath );
      Str255List.Clear( TempList );
      return;
   else
      ShowListInfo( "Problems Importing Project with SVN", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
      Str255List.Clear( TempList );
   end if;
   Str255List.Clear( TempList );
end SVNImport;


-------------------------------------------------------
-- SVN Commit                                        --
--                                                   --
-- Save changes to an existing project in the SVN    --
-- repository using "svn commit".  The user is       --
-- prompted for submission comment.                  --
-------------------------------------------------------

procedure SVNCommit is
  SVNcmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
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

  -- The SVN Commit dialog.  Prompt for a comment

   OpenWindow( To255( "Share Changes in Project with Subversion Repository" ), 1, 1, 78, 13 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "To save this project using SVN, you need to give a description of the" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "changes.  SVN will assign a new version number to the project and record" );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 4, 76, 4 );
   SetText( Desc3Line, "all the changes since the last time this project was saved.  The comment" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( Desc4Line, 1, 5, 76, 5 );
   SetText( Desc4Line, "should indicate features you've added or problems you've fixed." );
   AddControl( Desc4Line'unchecked_access, false );

   Init( Desc5Line, 1, 7, 76, 7 );
   SetText( Desc5Line, "If you don't want to save this project with SVN, select Cancel." );
   AddControl( Desc5Line'unchecked_access, false );

   Init( CommLine, 1, 9, 76, 9 );
   SetText( CommLine, LastSVNCommLine );
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
   LastSVNCommLine := GetText( CommLine );

   Comment := GetText( CommLine );  -- get the comment

  -- changes are commited using the SVN command
  -- "svn commit --message="comment"

  SVNcmd := "svn commit --message=" & shell_escape( Comment );
  UNIX( "echo -e '" & SVNcmd & "\n' > " & TempFile );
  SessionLog( "SVNcommit: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );
  ShowListInfo( "Committed Project to SVN Repository", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList, last => true );
  Str255List.Clear( TempList );
end SVNCommit;


-------------------------------------------------------
-- SVN Update                                        --
--                                                   --
-- Merge changes with the project with the copy in   --
-- the SVN repository.  Changes are not committed.   --
-------------------------------------------------------

procedure SVNUpdate is
  SVNCmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
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

  -- The SVN Commit dialog.  Prompt for a comment

   OpenWindow( To255( "Update Project with Differences in Subversion Repository" ), 1, 1, 78, 14 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "If this is a team project, TIA can use SVN to apply the latest changes" );
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

  -- changes are updated using the SVN command
  -- "svn update"

  Proj_UpdateTime := GetTimeStamp;

  if GetCheck( LocalBox ) then
     SVNcmd := To255( "svn update" );
  else
     SVNcmd := To255( "svn update -N" );
  end if;
  UNIX( "echo -e '" & SVNcmd & "\n' > " & TempFile );
  SessionLog( "SVNupdate: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  -- isn't obvious from svn output if it's complete or not
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
end SVNUpdate;

-------------------------------------------------------
-- SVN Add                                           --
--                                                   --
-- Add the current source file to the project using  --
-- "svn add".                                        --
-------------------------------------------------------

procedure SVNAdd is
  SVNcmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
  TempStr  : Str255;
begin
   MakeTempFileName( TempFile );

  SVNcmd := "svn add --message=" & '"' & "Added by TIA" & '"' & ' ' & SourcePath;
  UNIX( "echo -e '" & SVNcmd & "\n' > " & TempFile );
  SessionLog( "SVNAdd: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );

  Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
  SessionLog( TempStr );
  if Index( TempStr, "svn commit" ) < 1 then
     ShowListInfo( "Problem Adding Your File To Subversion Project", 0, 1, DisplayInfo.H_Res-2, 23, TempList );
     Str255List.Clear( TempList );
  end if;
end SVNAdd;

-------------------------------------------------------
-- SVN Log                                           --
--                                                   --
-- Show the SVN log for the current source file      --
-------------------------------------------------------

procedure SVNLog is
  SVNcmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
begin
  MakeTempFileName( TempFile );
  SVNcmd := "svn log " & SourcePath;
  SessionLog( "SVNLog: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  if NotEmpty( TempFile ) then
     LoadList( TempFile, TempList );
  else
     Str255List.Queue( TempList, To255( "No changes" ) );
  end if;
  Str255List.Push( TempList, SVNcmd );
  Erase( TempFile );
  ShowListInfo( "Change Log", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
  Str255List.Clear( TempList );
end SVNLog;

-------------------------------------------------------
-- SVN Diff                                          --
--                                                   --
-- Perform a SVN diff on the current source file     --
-------------------------------------------------------

procedure SVNDiff is
  SVNcmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
begin
  MakeTempFileName( TempFile );
  SVNcmd := "svn diff " & SourcePath;
  SessionLog( "SVNDiff: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  if NotEmpty( TempFile ) then
     LoadList( TempFile, TempList );
  else
     Str255List.Queue( TempList, To255( "No differences" ) );
  end if;
  Str255List.Push( TempList, NullStr255 );
  Str255List.Push( TempList, SVNcmd );
  Erase( TempFile );
  ShowListInfo( "Differences Since Last Project Commit", 1, 1, DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, TempList );
  Str255List.Clear( TempList );
end SVNDiff;

-------------------------------------------------------
-- SVN Remove                                        --
--                                                   --
-- Remove a file from the repository.                --
-------------------------------------------------------

procedure SVNRemove( RemovePath : Str255 ) is
  SVNcmd   : Str255;
  TempFile : Str255;            -- file holding results of SVN command
  TempList : Str255List.List;   -- results of SVN command
  TempStr  : Str255;
begin
  MakeTempFileName( TempFile );
  SVNcmd := "svn remove " & RemovePath;
  SessionLog( "SVNRemove: " & SVNCmd );
  UNIX( SVNcmd & " >>" & TempFile & " 2>&1" );
  LoadList( TempFile, TempList );
  Erase( TempFile );
  Str255List.Find( TempList, Str255List.Length( TempList ), TempStr );
  if Index( TempStr, " removed `" ) = 0 then
     Str255List.Push( TempList, NullStr255 );
     Str255List.Push( TempList, SVNcmd );
     ShowListInfo( "Problem Removing File from Subversion Repository", 0, 1, DisplayInfo.H_Res-2, 23, TempList );
  end if;
  Str255List.Clear( TempList );
end SVNRemove;

end tiasvn;
