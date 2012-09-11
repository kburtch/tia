------------------------------------------------------------------------------
-- TIA (Tiny IDE for Ada/Anything)                                          --
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
-- This is maintained at http://www.pegasoft.ca/tia.html                    --
--                                                                          --
------------------------------------------------------------------------------

pragma warnings(off);  -- don't care that it's non-portable unit
with ada.command_line.environment; -- for return result code, etc.
pragma warnings(on);

with ada.text_io, -- for printing results in non-interactive modes
     common,    -- texttools' root package
     os,        -- clock and O/S stuff for Ken's windows
     strings,   -- Ken's string functions
     userio,    -- Ken's ASCII drawing stuff
     controls,  -- controls/widgets for Ken's windows
     windows,   -- Ken's windows
     english,   -- common English words
     tiacommon, -- tia common definitions
     tiatips,   -- tia startup help tips
     printer,   -- line printer support
     tiadebug,  -- TIA debugger
     tiacvs,    -- TIA CVS support
     tiasvn,    -- TIA SVN support
     tiagcc,    -- TIA GNAT/GCC definitions
     gen_list;  -- texttools' generic linked list package
use  common, os, strings, userio, controls, windows, english,
     tiacommon, tiatips, printer, tiadebug, tiacvs, tiasvn;

Pragma Optimize( Space );
-- make program as small as possible


procedure tia is ---------------------------------------------------


-------------------------------------------------------------------------------
-- O/S BINDINGS
-------------------------------------------------------------------------------


procedure sync;
pragma import( C, sync );
-- sync syscall: flush disks

function getuid return integer;
pragma import( C, getuid );
-- determine who we are


-------------------------------------------------------------------------------
-- STR255 INDEX LIST
--
-- A list of indexes into a linked list of 255 character strings.
-------------------------------------------------------------------------------


package Str255IndexList is new gen_list( Str255List.AListIndex,
  ">", "=" );
-- list of Str255List indexes


-------------------------------------------------------------------------------
-- DECLARATIONS
-------------------------------------------------------------------------------

Done          : boolean := false;      -- quitting program
Text2Find     : str255  := NullStr255; -- last find dialog string
Text2Replace  : str255  := NullStr255; -- last find dialog replace string
FindBackwards : boolean := false;      -- true if find backwards selected
FindRegExp    : boolean := false;      -- true if find regexp selected
Replacing     : boolean := false;      -- true if replacing text



-------------------------------------------------------------------------------
-- UTILITIES
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- UPDATE SOURCE DISPLAY
--
-- Update scroll bar and screen statistics after a major change to the
-- source box (i.e. a Edit/Goto or File/Open)
-------------------------------------------------------------------------------

procedure UpdateSourceDisplay is
begin
  SetThumb( SourceBar, GetCurrent( SourceBox ) );
  UpdateMarginStats;
end UpdateSourceDisplay;


-------------------------------------------------------------------------------
-- LOADING / SAVING
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--  LOAD PROJECT
--
-- Load a project file and set our global vars accordinly.  If the path isn't
-- known, this is a new project and initialize global vars to defaults.                                --
-------------------------------------------------------------------------------

procedure LoadProject is

  function RebuildAlert return boolean is
     Desc1Line : aliased AStaticLine;
     Desc2LIne : aliased AStaticLine;
     Desc3LIne : aliased AStaticLine;
     YesButton : aliased ASimpleButton;
     NoButton  : aliased ASimpleButton;

     DT : aDialogTaskRecord;
  begin

   OpenWindow( To255( "Platform Change" ), 1, 1, 78, 9 );

   Init( Desc1Line, 1, 2, 76, 2 );
   SetText( Desc1Line, "The development environment of the project has changed.  A full rebuild" );
   AddControl( Desc1Line'unchecked_access, false );

   Init( Desc2Line, 1, 3, 76, 3 );
   SetText( Desc2Line, "will ensure that all files are consistent with the new platform." );
   AddControl( Desc2Line'unchecked_access, false );

   Init( Desc3Line, 1, 5, 76, 5 );
   SetText( Desc3Line, "Do you want to fully rebuild the project on the next build?" );
   AddControl( Desc3Line'unchecked_access, false );

   Init( YesButton, 15, 7, 35, 7, 'r' );
   SetText( YesButton, To255( "Rebuild" ) );
   AddControl( YesButton'unchecked_access, false );

   Init( NoButton, 50, 7, 65, 7, 'n' );
   SetText( NoButton, To255( "No" ) );
   AddControl( NoButton'unchecked_access, false );

   DoDialog( DT );
   CloseWindow;

   return DT.control /= 4;

  end RebuildAlert;

  TempList : Str255List.List;
  TempStr  : Str255;
  i        : integer;
begin
  SourcePath := NullStr255;
  NeedsFullRecompile := false;
  ClearLoadExceptions;
  if not IsFile( ProjectPath ) then
     NoteAlert( "Starting new project" );
     return;
  end if;
  LoadList( ProjectPath, TempList );
  if LastError /= 0 then
     StopAlert( "Couldn't load " & ToString( ProjectPath ) );
     return;
  end if;
  Str255List.Pull( TempList, Proj_GCCOptions );
  Str255List.Pull( TempList, Proj_LinkOptions );
  Str255List.Pull( TempList, Proj_Main );
  Str255List.Pull( TempList, Proj_GUI );
  Str255List.Pull( TempList, TempStr );
  Proj_Opt := Short_Short_Integer( ToInteger( TempStr ) );
  Str255List.Pull( TempList, TempStr );
  Proj_CPU := Short_Short_Integer( ToInteger( TempStr ) );
  Str255List.Pull( TempList, TempStr );
  Proj_Debug := Short_Short_Integer( ToInteger( TempStr ) );
  Str255List.Pull( TempList, TempStr );
  Proj_Kind := Short_Short_Integer( ToInteger( TempStr ) );
  Str255List.Pull( TempList, TempStr );
  Proj_Builder := Short_Short_Integer( ToInteger( TempStr ) );
  Str255List.Pull( TempList, TempStr );
  i := ToInteger( TempStr );
  Proj_Static := i = 1;
  Str255List.Pull( TempList, TempStr );
  i := ToInteger( TempStr );
  Proj_Egcs := i = 1;
  Str255List.Pull( TempList, TempStr );
  i := ToInteger( TempStr );
  Proj_Alt := i = 1;
  Str255List.Pull( TempList, SourcePath );
  if Str255List.Length( TempList ) > 0 then -- not in version 0.6
     SessionLog( "LoadProject: version 0.6.1 project file" );
     Str255List.Pull( TempList, TempStr );
     Proj_BackupTime := ATimeStamp'value( ToString( TempStr ) );
     if Str255List.Length( TempList ) > 0 then -- not in version 0.6.1
        Str255List.Pull( TempList, Proj_PlatSig );
        if Str255List.Length( TempList ) > 0 then -- not in version 0.7.0
           Str255List.Pull( TempList, TempStr );
           Proj_KeyCount := long_integer'value( ToString( TempStr ) );
           Str255List.Pull( TempList, TempStr );
           Proj_BuildCount := long_integer'value( ToString( TempStr ) );
           Str255List.Pull( TempList, TempStr );
           Proj_BuildTime := ATimeStamp'value( ToString( TempStr ) );
           Str255List.Pull( TempList, TempStr );
           Proj_LineCount := long_integer'value( ToString( TempStr ) );
           if Str255List.Length( TempList ) > 0 then -- 0.7.3
              Str255List.Pull( TempList, Proj_BuildTimeStr );
              if Str255List.Length( TempList ) > 0 then -- 1.0.0
                 Str255List.Pull( TempList, TempStr );
                 Proj_UpdateTime := ATimeStamp'value( ToString( TempStr ) );
                 if Str255List.Length( TempList ) > 0 then -- 1.0.3
                    Str255List.Pull( TempList, TempStr );
                    i := ToInteger( TempStr );
                    Proj_GCJ := i = 1;
                    Str255List.Pull( TempList, Proj_Repository );
                 end if;
              end if;
	   end if;
        end if;
     end if;
  else
     SessionLog( "LoadProject: version 0.6 project file" );
  end if;
  Str255List.Clear( TempList );
  IsCVSProject := IsDirectory( To255( "./CVS" ) );
  IsSVNProject := IsDirectory( To255( "./.svn" ) );
  if IsFile( SourcePath ) then
     UpdateQuickOpen( SourcePath, 1, 1 );
  else
     SourcePath := NullStr255;
  end if;

  -- project signature check

  SessionLog( "LoadProject: Old Platform Signature: " & Proj_PlatSig );
  SessionLog( "LoadProject: New Platform Signature: " & PlatformSig );
  if Proj_PlatSig /= PlatformSig then
     NeedsFullRecompile := RebuildAlert;
  end if;

  -- Lock the Project

  if length( SourcePath ) > 0 then
     LockProject;
  else
     ProjectLocked := true;
     -- new project?  Pretend it's locked.
  end if;
  if not ProjectLocked then
     NoteAlert( "Project in use: read-only session" );
  end if;
  if Proj_Builder = 1 then       -- gnatmake?
     if not UNIX( "gnatmake 2>/dev/null ; [ $? -eq 4 ] && exit 0" ) then
        CautionAlert( "I can't find gnatmake with your PATH variable" );
     end if;
  elsif Proj_Builder = 4 then    -- jgnatmake?
     if not UNIX( "jgnatmake 2>/dev/null ; [ $? -eq 4 ] && exit 0" ) then
        CautionAlert( "I can't find jgnatmake with your PATH variable" );
     end if;
  end if;
  UpdateSourceDisplay;
end LoadProject;


-------------------------------------------------------------------------------
--  SAVE PROJECT
--
-- Save the current project.  If the project has no pathname, assume it is a
-- new project and prompt for a pathname.
-------------------------------------------------------------------------------

procedure SaveProject is
  TempList : Str255List.List;
  TempStr  : Str255;
  ThisPath : Str255;
  ImportPath : Str255;
  TempFile : Str255;
  ssf      : ASelectSaveFileRec;
  WasNew   : boolean := length( ProjectPath ) = 0;
begin
  UnlockProject;
  if WasNew then
     ssf.Prompt := To255( "Save project as ..." );
     ssf.Default := To255( "untitled.adp" );
     SelectSaveFile( ssf );
     if ssf.replied then
        ProjectPath := ssf.path & "/" & ssf.fname;
     else
        NoteAlert( "User Cancelled: project not saved" );
        SessionLog( "User Cancelled: project not saved" );
     end if;
  end if;
  if length( ProjectPath ) > 0 then
     Str255List.Queue( TempList, Proj_GCCOptions );
     Str255List.Queue( TempList, Proj_LinkOptions );
     Str255List.Queue( TempList, Proj_Main );
     Str255List.Queue( TempList, Proj_GUI );
     TempStr := To255( short_short_integer'image( Proj_Opt ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( short_short_integer'image( Proj_CPU ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( short_short_integer'image( Proj_Debug ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( short_short_integer'image( Proj_Kind ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( short_short_integer'image( Proj_Builder ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( integer'image( boolean'pos( Proj_Static ) ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( integer'image( boolean'pos( Proj_Egcs ) ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( integer'image( boolean'pos( Proj_Alt ) ) );
     Str255List.Queue( TempList, TempStr );
     Str255List.Queue( TempList, SourcePath );
     TempStr := To255( ATimeStamp'image( Proj_BackupTime ) );
     Str255List.Queue( TempList, TempStr );
     Str255List.Queue( TempList, Proj_PlatSig );
     TempStr := To255( long_integer'image( Proj_KeyCount ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( long_integer'image( Proj_BuildCount ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( ATimeStamp'image( Proj_BuildTime ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( long_integer'image( Proj_LineCount ) );
     Str255List.Queue( TempList, TempStr );
     Str255List.Queue( TempList, Proj_BuildTimeStr );
     TempStr := To255( ATimeStamp'image( Proj_UpdateTime ) );
     Str255List.Queue( TempList, TempStr );
     TempStr := To255( integer'image( boolean'pos( Proj_GCJ ) ) );
     Str255List.Queue( TempList, TempStr );
     Str255List.Queue( TempList, Proj_Repository );
     SaveList( ProjectPath, TempList );
     if LastError = TT_OK then
        SessionLog( "Project saved as " & ProjectPath );
        if HasCVS and Opt_CVS and WasNew then
           CVSImport;
        end if;
        if HasSVN and Opt_SVN and WasNew then
           SVNImport;
        end if;
     else
        SessionLog( "SaveProject: Error saving file", LastError );
        StopAlert( "Error saving file: # " & AnErrorCode'image(
          LastError ) );
     end if;
  end if;
  Str255List.Clear( TempList );
end SaveProject;


-------------------------------------------------------------------------------
--  LOAD OPTIONS
--
-- Load the global options from the options file (usually at startup).
-------------------------------------------------------------------------------

procedure LoadOptions is
  TempList : Str255List.List;
  TempStr  : Str255;
  i        : integer;
begin
  if not IsFile( OptionsPath ) then
     return; -- no file, use defaults
  end if;
  LoadList( OptionsPath, TempList );
  Str255List.Pull( TempList, TempStr );
  i := ToInteger( TempStr );
  Opt_Quiet := i = 1;
  Str255List.Pull( TempList, TempStr );
  i := ToInteger( TempStr );
  Opt_Blue := i = 1;
  if Str255List.length( TempList ) > 0 then -- TIA 0.6 file won't have this
     Str255List.Pull( TempList, Opt_Backup );
  end if;
  if Str255List.length( TempList ) > 0 then -- TIA 0.6.1 file won't have this
     Str255List.Pull( TempList, TempStr );
     Opt_TipNumber := ToInteger( TempStr );
  end if;
  if Str255List.length( TempList ) > 0 then -- TIA 0.7.0 file won't have this
     Str255List.Pull( TempList, TempStr );
     Opt_KeyCount := long_integer'value( ToString( TempStr ) );
  end if;
  if Str255List.length( TempList ) > 0 then -- old TIA won't have this
     Str255List.Pull( TempList, TempStr );
     i := ToInteger( TempStr );
     Opt_CVS := i = 1;
  end if;
  if Str255List.length( TempList ) > 0 then -- old TIA won't have this
     Str255List.Pull( TempList, TempStr );
     i := ToInteger( TempStr );
     Opt_SVN := i = 1;
  end if;
  if Str255List.length( TempList ) > 0 then -- old TIA won't have this
     Str255List.Pull( TempList, TempStr );
     i := ToInteger( TempStr );
     KeywordHilight := aPenColourName'val( i );
     Str255List.Pull( TempList, TempStr );
     i := ToInteger( TempStr );
     FunctionHilight := aPenColourName'val( i );
     Str255List.Pull( TempList, TempStr );
     i := ToInteger( TempStr );
     AutoHelpStyle := anAutoHelpStyle'val( i );
  else
     KeywordHilight := yellow;
     FunctionHilight := purple;
     AutoHelpStyle := both;
  end if;
  Str255List.Clear( TempList );
  BlueBackground( Opt_Blue );
end LoadOptions;


-------------------------------------------------------------------------------
--  SAVE OPTIONS
--
-- Save the global options to the options file (usually at shutdown).
-------------------------------------------------------------------------------

procedure SaveOptions is
  TempList : Str255List.List;
  TempStr  : Str255;
begin
  TempStr := To255( integer'image( boolean'pos( Opt_Quiet ) ) );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( boolean'pos( Opt_Blue ) ) );
  Str255List.Queue( TempList, TempStr );
  Str255List.Queue( TempList, Opt_Backup );
  TempStr := To255( Opt_TipNumber'img );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( Opt_KeyCount'img );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( boolean'pos( Opt_CVS ) ) );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( boolean'pos( Opt_SVN ) ) );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( aPenColourName'pos( KeywordHilight ) ) );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( aPenColourName'pos( FunctionHilight ) ) );
  Str255List.Queue( TempList, TempStr );
  TempStr := To255( integer'image( anAutoHelpStyle'pos( AutoHelpStyle ) ) );
  Str255List.Queue( TempList, TempStr );
  SaveList( OptionsPath, TempList );
  if LastError /= TT_OK then
     SessionLog( "SaveOptions: Error saving file", LastError );
     StopAlert( "Error saving options: # " & AnErrorCode'image(
       LastError ) );
  end if;
  Str255List.Clear( TempList );
end SaveOptions;


-------------------------------------------------------------------------------
--  SET KEYWORDS
--
-- Set the appropriate keyword hilighting based on the specified pathname
-- (usually the global variable SourcePath).
-------------------------------------------------------------------------------

procedure SetKeywords( SourcePath : str255 ) is
begin

   -- Set main window's SourceEditBox to the appropriate
   -- language.

   SetSourceLanguage( SourceBox, SourceLanguage );
   SetHTMLTagsStyle( SourceBox, hilight => false ); -- default
   if SourceLanguage = PHP then
      SetHTMLTagsStyle( SourceBox, hilight => true );
   elsif SourceLanguage = HTML then
      SetHTMLTagsStyle( SourceBox, hilight => true );
   end if;
   if SourceLanguage = UnknownLanguage then
      NoteAlert( "I'm treating this unknown file as plain text" );
      --ClearKeywords( SourceBox );
   end if; 

   Invalid( SourceBox ); -- force redraw
end SetKeywords;


-------------------------------------------------------------------------------
-- REFERSH SOURCE
--
-- Reload the source file because an outside program (e.g. CVS) has updated it.
-------------------------------------------------------------------------------

procedure RefreshSource is
  CursorX    : integer;
  CursorY    : Str255List.AListIndex;
begin
   CursorX := GetPosition( SourceBox );
   CursorY := GetCurrent( SourceBox );
   Str255List.Clear( SourceText );           -- discard old source
   LoadSourceFile( SourcePath, SourceText ); -- load new source
   SetList( SourceBox, SourceText );         -- put in window
   Str255List.Clear( SourceText );    -- no longer used
   SetCursor( SourceBox, CursorX, CursorY ); -- restore cursor
   UpdateSourceDisplay;
end RefreshSource;


-------------------------------------------------------------------------------
-- DIALOGS
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--  EDIT MACROS
--
-- Open a window and allow the user to edit the contents of the TextTools
-- keyboard macro file.
-------------------------------------------------------------------------------

procedure EditMacros is
  MacroList : Str255List.List;
  MacrosToSave : Str255List.List;
  WasChanges : boolean;
  s : str255;
begin
  if NotEmpty( To255( "$SYS/macro_file" ) ) then
     LoadList( To255( "$SYS/macro_file" ), MacroList );
  end if;
  Str255List.Queue( MacroList, NullStr255 );
  EditListInfo( "Macro List", 0, 0, 79, 24, MacroList, WasChanges );
  if WasChanges then
     while Str255List.length( MacroList ) > 0 loop
           Str255List.Pull( MacroList, s );
           if length( s ) > 0 then
              Str255List.Push( MacrosToSave, s );
           end if;
     end loop;
     SaveList( To255( "$SYS/macro_file" ), MacrosToSave );
     if LastError = TT_OK then
        NoteAlert( "Restart the program to see changes." );
     else
        SessionLog( "EditMacros: Error saving file", LastError );
        StopAlert( "Error saving file: # " & AnErrorCode'image(
          LastError ) );
     end if;
     Str255List.Clear( MacrosToSave );
  end if;
  Str255List.Clear( MacroList );
end EditMacros;


-------------------------------------------------------------------------------
--  DO GDB
--
-- Run the gdb (or gnatgdb for ALT version) debugger.                                   --
-------------------------------------------------------------------------------

procedure DoGDB is
begin
  if Proj_Debug /= 3 then
     NoteAlert( "Project Debug must be set to Prerelease" );
     return;
  end if;
  if Proj_ALT then
     UNIX( "gnatgdb " & Proj_Main );
  else
     UNIX( "gdb " & Proj_Main );
  end if;
end DoGDB;


-------------------------------------------------------------------------------
--  DO GUI
--
-- Run the user's GUI builder as selected in proect/parameters.
-------------------------------------------------------------------------------

procedure DoGUI is
begin
  UNIX( Proj_GUI );
end DoGUI;


-------------------------------------------------------------------------------
--  FIND SUBPROGRAM
--
-- Create a list of all the subprogram headers in the current source file.
-- Allow the user to chose one and move to that line.
-------------------------------------------------------------------------------

procedure FindSubprogram is
    SubBox       : aliased ARadioList;
    SubBar       : aliased AScrollBar;
    GotoButton   : aliased ASimpleButton;
    CancelButton : aliased ASimpleButton;
    TheList      : Str255List.List;
    TheButtons   : BooleanList.List;
    ThePositions : Str255IndexList.List;
    SourceText   : Str255List.List;
    -- this is a reference.  Do not clear().

    First : integer;
    TempStr : Str255; 
    Move2Line : Str255List.AListIndex := 0;
    DT : ADialogTaskRecord;
  begin
    SourceText := GetList( SourceBox );
    for i in 1..Str255List.Length( SourceText ) loop
        Str255List.Find( SourceText, i, TempStr );
        TempStr := ToLower( TempStr );
        if length( TempStr ) > 0 then
           First := Index_Non_Blank( TempStr );
-- should not be case sensitive
           begin
	     if SourceLanguage = Perl then
                if Slice( TempStr, First, First+3 ) = "sub " then
                   Str255List.Queue( TheList, TempStr );
                   BooleanList.Queue( TheButtons, False );
                   Str255IndexList.Queue( ThePositions, i );
		end if;
	     else
                if Slice( TempStr, First, First+9 ) = "procedure " then
                   Str255List.Queue( TheList, TempStr );
                   BooleanList.Queue( TheButtons, False );
                   Str255IndexList.Queue( ThePositions, i );
                elsif Slice( TempStr, First, First+8 ) = "function " then
                   Str255List.Queue( TheList, TempStr );
                   BooleanList.Queue( TheButtons, False );
                   Str255IndexList.Queue( ThePositions, i );
                   SessionLog( TempStr );
		end if;
             end if;
           exception when others => null;
              -- string exception could be raised on short strings
           end;
        end if;
    end loop;

    if Str255List.Length( TheList ) = 0 then
       NoteAlert( "There are no subprograms" );
       goto Done;
    end if;

    OpenWindow( To255( "Find Subprogram" ), 1, 1, DisplayInfo.H_Res-2, DisplayInfo.V_Res-1,
      Normal );

    BooleanList.Replace( TheButtons, 1, True );

    Init( SubBox, 1, 2, DisplayInfo.H_Res-4, DisplayInfo.V_Res-4 );
    SetList( SubBox, TheList );
    SetChecks( SubBox, TheButtons );
    AddControl( SubBox'unchecked_access, false );

    Init( SubBar, DisplayInfo.H_Res-3, 1, DisplayInfo.H_Res-3,
       DisplayInfo.V_Res-4 );
    AddControl( SubBar'unchecked_access, false );

    Init( GotoButton, 2, DisplayInfo.V_Res-3, 11, DisplayInfo.V_Res-3, 'g' );
    SetText( GotoButton, To255( "Goto" ) );
    SetInstant( GotoButton );
    AddControl( GotoButton'unchecked_access, false );

    Init( CancelButton, 22, DisplayInfo.V_Res-3, 31, DisplayInfo.V_Res-3, 'l' );
    SetText( CancelButton, To255( "Cancel" ) );
    SetInstant( CancelButton );
    AddControl( CancelButton'unchecked_access, false );

    DoDialog( DT );

    if DT.control = 3 then -- goto pressed?
       Str255IndexList.Find( ThePositions, GetCheck( SubBox ), Move2Line );
       MoveCursor( SourceBox, 0, 
         Move2Line - GetCurrent( SourceBox ) );
    end if;

    CloseWindow;

  <<Done>>
    Str255List.Clear( TheList );
    BooleanList.Clear( TheButtons );
    Str255IndexList.Clear( ThePositions );
    UpdateSourceDisplay;
  end FindSubprogram;


-------------------------------------------------------------------------------
--  FIND TAGGED RECORD
--
-- Create a list of all tagged record (Ada object) headers in the current
-- program.  Allow the user to chose one and move to that line.
-------------------------------------------------------------------------------

  procedure FindTaggedRecord is
    TagBox       : aliased ARadioList;
    TagBar       : aliased AScrollBar;
    GotoButton   : aliased ASimpleButton;
    CancelButton : aliased ASimpleButton;
    TheList      : Str255List.List;
    TheButtons   : BooleanList.List;
    ThePositions : Str255IndexList.List;
    SourceText   : Str255List.List;
    -- this is a reference.  Do not clear().

    TempStr : Str255; 
    Move2Line : Str255List.AListIndex := 0;
    DT : ADialogTaskRecord;
  begin
    SourceText := GetList( SourceBox );
    for i in 1..Str255List.Length( SourceText ) loop
        Str255List.Find( SourceText, i, TempStr );
        if length( TempStr ) > 0 then
-- should not be case sensitive
           if SourceLanguage = Ada_Language then
             TempStr := ToLower( TempStr );
             if Index( TempStr, "tagged record" ) > 0 then
                Str255List.Queue( TheList, TempStr );
                BooleanList.Queue( TheButtons, False );
                Str255IndexList.Queue( ThePositions, i );
             elsif Index( TempStr, "with record" ) > 0 then
                Str255List.Queue( TheList, TempStr );
                BooleanList.Queue( TheButtons, False );
                Str255IndexList.Queue( ThePositions, i );
             elsif Index( TempStr, "with private" ) > 0 then
                Str255List.Queue( TheList, TempStr );
                BooleanList.Queue( TheButtons, False );
                Str255IndexList.Queue( ThePositions, i );
             end if;
           elsif SourceLanguage = Java or SourceLanguage = PHP then
             TempStr := ToLower( TempStr );
             if Index( TempStr, "class " ) > 0 then
                Str255List.Queue( TheList, TempStr );
                BooleanList.Queue( TheButtons, False );
                Str255IndexList.Queue( ThePositions, i );
             end if;
           end if;
        end if;
    end loop;

    if Str255List.Length( TheList ) = 0 then
       NoteAlert( "There are no tagged records" );
       goto Done;
    end if;

    OpenWindow( To255( "Find Class / Tagged Record" ), 1, 1, DisplayInfo.H_Res-2, DisplayInfo.V_Res-1,
      Normal );

    BooleanList.Replace( TheButtons, 1, True );

    Init( TagBox, 1, 2, DisplayInfo.H_Res-4, DisplayInfo.V_Res-4 );
    SetList( TagBox, TheList );
    SetChecks( TagBox, TheButtons );
    AddControl( TagBox'unchecked_access, false );

    Init( TagBar, DisplayInfo.H_Res-3, 1, DisplayInfo.H_Res-3,
       DisplayInfo.V_Res-4 );
    AddControl( TagBar'unchecked_access, false );

    Init( GotoButton, 2, DisplayInfo.V_Res-3, 11, DisplayInfo.V_Res-3, 'g' );
    SetText( GotoButton, To255( "Goto" ) );
    SetInstant( GotoButton );
    AddControl( GotoButton'unchecked_access, false );

    Init( CancelButton, 22, DisplayInfo.V_Res-3, 31, DisplayInfo.V_Res-3, 'l' );
    SetText( CancelButton, To255( "Cancel" ) );
    SetInstant( CancelButton );
    AddControl( CancelButton'unchecked_access, false );

    DoDialog( DT );

    if DT.control = 3 then -- goto pressed?
       Str255IndexList.Find( ThePositions, GetCheck( TagBox ), Move2Line );
       MoveCursor( SourceBox, 0, 
         Move2Line - GetCurrent( SourceBox ) );
    end if;

    CloseWindow;

  <<Done>>
    Str255List.Clear( TheList );
    BooleanList.Clear( TheButtons );
    Str255IndexList.Clear( ThePositions );
    UpdateSourceDisplay;
  end FindTaggedRecord;


-------------------------------------------------------------------------------
--  FIND DIALOG
--
-- Find menu/Find/Replace
--
-- Open a window and prompt the user for text to find, with appropriate
-- checkbox options.
-------------------------------------------------------------------------------

  function FindDialog return boolean is
    TextLine        : aliased AnEditLine;
    FindButton      : aliased ASimpleButton;
    CancelButton    : aliased ASimpleButton;
    BackwardsButton : aliased ACheckBox;
    RegExpButton    : aliased ACheckBox;
    ReplaceButton   : aliased ASimpleButton;
    ReplaceLabel    : aliased AStaticLine;
    ReplaceLine     : aliased AnEditLine;
    DT : ADialogTaskRecord;
    FindNotCancelled : boolean := true;
    -- Text2Find is defined in encompasing procedure
  begin
    OpenWindow( To255( "Find/Replace Text" ), 10, 9, 70, 17, Normal );

    Init( TextLine, 1, 2, 58, 2 );
    SetText( TextLine, Text2Find );
    AddControl( TextLine'unchecked_access, false );

    Init( ReplaceLabel, 1, 4, 9, 4 );
    SetText( Replacelabel, To255( "Replace:" ) );
    AddControl( ReplaceLabel'unchecked_access, false );

    Init( ReplaceLine, 10, 4, 58, 4 );
    SetText( ReplaceLine, Text2Replace );
    AddControl( ReplaceLine'unchecked_access, false );

    Init( FindButton, 2, 6, 11, 6, s_Find_Hot );
    SetText( FindButton, s_Find );
    SetInstant( FindButton );
    AddControl( FindButton'unchecked_access, false );

    Init( CancelButton, 12, 6, 22, 6, s_Cancel_Hot );
    SetText( CancelButton, s_Cancel );
    SetInstant( CancelButton );
    AddControl( CancelButton'unchecked_access, false );

    Init( BackwardsButton, 24, 6, 32, 6, 'b' );
    SetText( BackwardsButton, To255( "Back" ) );
    SetCheck( BackwardsButton, FindBackwards );
    AddControl( BackwardsButton'unchecked_access, false );

    Init( RegExpButton, 35, 6, 46, 6, 'x' );
    SetText( RegExpButton, To255( "RegExp" ) );
    SetCheck( RegExpButton, FindRegExp );
    AddControl( RegExpButton'unchecked_access, false );

    Init( ReplaceButton, 47, 6, 59, 6, 'r' );
    SetText( ReplaceButton, To255( "Replace" ) );
    SetInstant( ReplaceButton );
    AddControl( ReplaceButton'unchecked_access, false );

    loop
      DoDialog( DT );
      case DT.control is
      when 4 => Text2Find := GetText( TextLine );
                Text2Replace := NullStr255;
                FindBackwards := GetCheck( BackwardsButton );
                FindRegExp := GetCheck( RegExpButton );
                Replacing := false;
                exit;
      when 5 => FindNotCancelled := false; -- find cancelled
                Text2Find := NullStr255;
                Text2Replace := NullStr255;
                Replacing := false;
                exit;
      when 7 => if GetCheck( RegExpButton ) then
                   SetStatus( ReplaceButton, Off );
                else
                   SetStatus( ReplaceButton, On );
                end if;
      when 8 => Text2Find := GetText( TextLine );
                Text2Replace := GetText( ReplaceLine );
                FindBackwards := GetCheck( BackwardsButton );
                FindRegExp := GetCheck( RegExpButton );
                Replacing := true;
                exit;
      when others => null;
      end case;
    end loop;
    CloseWindow;
    if FindNotCancelled then
       UpdateSourceDisplay;
    end if;
    return FindNotCancelled;
  end FindDialog;


-------------------------------------------------------------------------------
--  SAVE SOURCE
--
-- File menu/Save
--
-- Save the current source file.  If DoBackgroundUpdate is true, compile
-- quietly after saving.  If ForcePrompt is true, prompt for pathname,
-- otherwise only prompt if the path is not known.                               --
-------------------------------------------------------------------------------

  procedure SaveSource( DoBackgroundUpdate : boolean := true;
                        ForcePrompt : boolean := false ) is
     ProjectDir : str255;
     TempHeader : str255list.list;
     ssf        : ASelectSaveFileRec;
     SaveAs     : boolean := false;
  begin
    -- no saving if read-only session
    if not ProjectLocked then
       return;
    end if;
    TempHeader := GetList( SourceBox );
    if Str255List.length( TempHeader ) = 0 then
       if length( SourcePath ) > 0 then -- if untitled, don't bother
          NoteAlert( "Blank source file not saved" );
       end if;
       SessionLog( "Blank source file not saved" );
       return;
    elsif not WasTouched( SourceBox ) and not ForcePrompt then
       SessionLog( "SaveSource: save skipped--no source changes" );
       return;
    elsif length( SourcePath ) = 0 or ForcePrompt then
        SaveAs := true;
        ProjectDir := GetPath;
        ssf.Prompt := To255( "Save as ..." );
        if sourceType = AdaBody then
           ssf.Default := To255( "untitled.adb" );
        elsif sourceType = AdaSpec then
           ssf.Default := To255( "untitled.ads" );
        elsif sourceType = ShellScript then
           ssf.Default := To255( "untitled.sh" );
        elsif sourceType = CHeader then
           ssf.Default := To255( "untitled.h" );
        elsif sourceType = CSource then
           ssf.Default := To255( "untitled.c" );
        elsif sourceType = CPPheader then
           ssf.Default := To255( "untitled.h" );
        elsif sourceType = CPPSource then
           ssf.Default := To255( "untitled.cc" );
        elsif sourceType = JavaSource then
           ssf.Default := To255( "untitled.java" );
        elsif sourceType = BushSource then
           ssf.Default := To255( "untitled.bush" );
        elsif sourceType = PerlSource then
           ssf.Default := To255( "untitled.pl" );
        elsif sourceType = PerlModule then
           ssf.Default := To255( "untitled.pm" );
        elsif sourceType = PHPSource then
           ssf.Default := To255( "untitled.php" );
        elsif sourceType = WebPage then
           ssf.Default := To255( "untitled.html" );
        else
           ssf.Default := To255( "untitled.adb" );
        end if;
        SelectSaveFile( ssf );
        -- ssf changes current path, but we want to stick to the
        -- project directory by default.  Get..Title will show
        -- absolute path if source not in current (project) directory.
        if ssf.replied then
           SourcePath := ssf.path & "/" & ssf.fname;
           SetPath( ProjectDir ); -- restore old path
        end if;
        if (not ssf.replied) or (length( SourcePath ) = 0) then
           SessionLog( ssf.Prompt & " was cancelled" );
           SetPath( ProjectDir ); -- restore old path
           return;
        end if;

     end if;
     --TempHeader := GetList( SourceBox );
     if SaveAs and IsFile( SourcePath ) then  -- overwrite?
        SaveSourceFile( SourcePath, TempHeader ); -- save source
        SetSourceLanguage( SourcePath );   -- determine the language
        SetKeywords( SourcePath );            -- check hilighting
	MoveCursor( SourceBox, 0, 0 );        -- save deletes spaces
     elsif SaveAs then                        -- new file?
        SaveSourceFile( SourcePath, TempHeader ); -- save source
        if HasCVS and Opt_CVS and IsCVSProject then
           CVSAdd;                            -- add to CVS
        end if;
        if HasSVN and Opt_SVN and IsSVNProject then
           SVNAdd;                            -- add to CVS
        end if;
        SetSourceLanguage( SourcePath );   -- determine the language
        SetKeywords( SourcePath );            -- check hilighting
	MoveCursor( SourceBox, 0, 0 );        -- save deletes spaces
     else                                     -- simple save?
        SaveSourceFile( SourcePath, TempHeader );   -- just save
     end if;
     if LastError = TT_OK then
        SessionLog( "Saved as " & SourcePath );
     else
       SessionLog( "SaveSource: Error saving file", LastError );
       StopAlert( "Error saving file: # " & AnErrorCode'image(
         LastError ) );
     end if;
     ClearTouch( SourceBox );
     if DoBackgroundUpdate then
        BackgroundUpdate( SourcePath );
     end if;
pragma Debug( SessionLog( "SaveSource: Before update source path is " & ToString( SourcePath ) ) );
     UpdateQuickOpen( SourcePath,
       GetCurrent( SourceBox ), GetPosition( SourceBox ) );
pragma Debug( SessionLog( "SaveSource: After update source path is " & ToString( SourcePath ) ) );
  end SaveSource;


-------------------------------------------------------------------------------
--  SHOW LINE STATS
--
-- File menu/Stats
--
-- Show statistics about the current source file in the window's info line.
-------------------------------------------------------------------------------

  procedure ShowLineStats is
    StatsLine : Str255;
    Alloc     : long_integer;
    SourceListPtr : Str255List.List;
    SemiLineCount, SemiCount : long_integer := 0;
    Line : Str255;
  begin
    Str255List.GetAllocation( alloc );
    StatsLine := Str255List.AListIndex'image( GetCurrent( SourceBox ) ) &
        To255( "/" & Str255List.AListIndex'image( GetLength( SourceBox ) ) &
          " line(s)  " & Str255List.AListIndex'image(
              GetLength( SourceBox ) / 66 ) &
          " pages  " & long_integer'image( Alloc / 1024 ) &
          " K used  " & long_integer'image( Freemem / 1024 / 1024 ) &
          " Meg total free" );
    SetInfoText( StatsLine & " [Calc SLOC...]" );
    DrawWindow; -- show stats so far
    SourceListPtr := GetList( SourceBox );
    for i in 1..Str255List.Length( SourceListPtr ) loop
        Str255List.Find( SourceListPtr, i, Line );
        SemiLineCount := long_integer( Count( Line, ";" ) );
        -- will count semi-colons in strings
        SemiCount := SemiCount + SemiLineCount;
    end loop;
    SetInfoText( StatsLine & " " & SemiCount'img & " SLOC" );
    -- don't clear SourceListPtr!
  end ShowLineStats;


-------------------------------------------------------------------------------
--  CHECK SOURCE
--
-- File menu/Check
--
-- Save the source file and compile it with error checking only (do not create
-- an obj file)  Use flags appropriate to the source file language.
-------------------------------------------------------------------------------

  procedure CheckSource is
    ErrFile : Str255;
  begin
    -- tell user what we're doing in info bar
    SetInfoText( To255( "Checking..." ) );
    -- save the file, but don't bother trying to compile
    SaveSource( DoBackgroundUpdate => false );
    MakeTempFileName( ErrFile ); 
    --
    -- Checking Java program?  Try to compile it
    --
    if SourceLanguage = Java then
       if Proj_GCJ then
          ShellOut( "gcj -c -C -Wall " & SourcePath & " 2> " & ErrFile );
          -- Note: Java errors go to standard output
       else
          ShellOut( "javac " & SourcePath & " > " & ErrFile & " 2>&1" );
          -- Note: some Java's put errors go to standard output
       end if;
    --
    -- Checking C++ program?  Try to compile it with -c
    --
    elsif SourceType = CPPSource then
       ShellOut( "g++ -c -Wall " & SourcePath & " " &
         Proj_GCCOptions & " 2> " & ErrFile );
    --
    -- Checking C program?  Try to compile it with -c
    --
    elsif SourceType = CSource then
       ShellOut( "gcc -c -Wall " & SourcePath & " " &
         Proj_GCCOptions & " 2> " & ErrFile );
    --
    -- Checking Bush program?  Try to compile it with -c
    --
    elsif SourceLanguage = Shell then
       ShellOut( "sh -n " & SourcePath & " 2> " & ErrFile );
    elsif SourceLanguage = Bush then
       ShellOut( "bush -cg " & SourcePath & " 2> " & ErrFile );
    elsif SourceLanguage = Perl then
       ShellOut( "perl -cw " & SourcePath & " 2> " & ErrFile );
    elsif SourceLanguage = PHP then
       ShellOut( "php -l " & SourcePath & " 2> " & ErrFile );
    elsif SourceLanguage = HTML then
       ShellOut( "tidy " & SourcePath & " >/dev/null 2> " & ErrFile );
    --
    -- Else must be an Ada program.
    --
    elsif Proj_Alt then
       ShellOut( "gnatgcc -O -c -gnatc -gnatf " & SourcePath & " " &
         Proj_GCCOptions & " 2> " & ErrFile );
    elsif Proj_Egcs then
       ShellOut( "egcs -O -c -gnatc -gnatf " & SourcePath & " " &
         Proj_GCCOptions & " 2> " & ErrFile );
    else
       ShellOut( "gcc -O -c -gnatc -gnatf " & SourcePath & " " &
         Proj_GCCOptions & " 2> " & ErrFile );
    end if;
    ClearGnatErrors;
    LoadList( ErrFile, GnatErrors );
-- cheat: gcj breaks normalize with a string error
-- Regular Java get messages mangled...
--if not Proj_GCJ then
    NormalizeGnatErrors;
--end if;
    Erase( ErrFile );
    SetInfoText( NullStr255 );
    if Str255List.Length( GnatErrors ) > 0 then
       ShowListInfo( "Source File Problems", 1, 1, DisplayInfo.H_Res-2, 23, GnatErrors );
       --if NotAda then
          -- not from gnat? then Next Error won't work. Discard.
       --   Str255List.Clear( GnatErrors );
       --end if;
    else
       NoteAlert( "File is OK" );
    end if;
  end CheckSource;


-------------------------------------------------------------------------------
--  STUB SOURCE
--
-- File menu/Stub
--
-- Save the Ada source file and run gnatstub to create a stubbed body.  Ensure
-- the source is a package spec.
-------------------------------------------------------------------------------

  procedure StubSource is
    NewPath : Str255;
    SPLen   : natural;
  begin
    SPLen := length( SourcePath );
    if Slice( SourcePath, SPLen-3, SPLen ) /= ".ads" then
       CautionAlert( "You can only stub a package spec" );
       SessionLog( "You can only stub a package spec" );
       return;
    end if;
    NewPath := To255( Slice( SourcePath, 1, SPLen-4 ) & ".adb" );
    if IsFile( NewPath ) then
       if NoAlert( "Overwrite existing package body?", Warning ) then
          SessionLog( "User decided not to overwrite body with stub" );
          return;
       end if;
       Erase( NewPath );
    end if;
    SaveSource( DoBackgroundUpdate => false );
    SessionLog( "Stubbing " & SourcePath );
    if not UNIX( "gnatstub " & Proj_GCCOptions & " " &
       SourcePath & " > /dev/null" ) then
       StopAlert( "gnatstub reported problems" );
       SessionLog( "gnatstub reported problems" );
    else
       NoteAlert( "Created " & ToString( NewPath ) );
    end if;
  end StubSource;


-------------------------------------------------------------------------------
--  DIFF SOURCE
--
-- File menu/Diff
--
-- Using the UNIX diff command to create a list of differences between the
-- current source file and the source file as of the last save.
-------------------------------------------------------------------------------

  procedure DiffSource is
     TempPath  : Str255;
     TempPath2 : Str255;
     TempList, SrcHeader  : Str255List.List;
     --RadioList : Str255List.List;
     Filename  : Str255;
  begin
     SessionLog( "DiffSource: diff-ing " & SourcePath );
     if length( SourcePath ) = 0 then
        NoteAlert( "Source file hasn't been saved" );
        return;
     end if;
     SplitPath( SourcePath, TempPath, Filename );
     if length( Filename ) = 0 and length( TempPath ) = 0 then
        Filename := TempPath;
     elsif length( Filename ) = 0 then
        Filename := TempPath;
     end if;
     MakeTempFileName( TempPath );
     TempPath2 := TempPath & "_2";
     SrcHeader := GetList( SourceBox );
     SaveList( TempPath, SrcHeader );
     SetInfoText( "Diff-ing..." );
     UNIX( "diff -w -b -a " & SourcePath & " " & TempPath &
           "  > " & TempPath2 );
     SetInfoText( "Loading diff info..." );
     if NotEmpty( TempPath2 ) then
        LoadList( TempPath2, TempList );
     else
        Str255List.Queue( TempList, To255( "No differences" ) );
     end if;
     Erase( TempPath );
     Erase( TempPath2 );
     ShowListInfo( "Differences Since Last Save", 0, 1, DisplayInfo.H_Res-1,
       DisplayInfo.V_Res-1, TempList );
     SetInfoText( "" );
     Str255List.Clear( TempList );
  end DiffSource;


-------------------------------------------------------------------------------
--  XREF SOURCE
--
-- File menu/xref
--
-- Save the current Ada source file.  Use gnatxref to create a cross-reference
-- listing for this file.
-------------------------------------------------------------------------------

  procedure XrefSource is
     -- display gnatxref info about the source
     -- this should really use a radio list and allow goto
     TempPath  : Str255;
     TempList  : Str255List.List;
     --RadioList : Str255List.List;
     Filename  : Str255;
  begin
     SessionLog( "XrefSource: crossreferencing " & SourcePath );
     SplitPath( SourcePath, TempPath, Filename );
     if length( Filename ) = 0 and length( TempPath ) = 0 then
        Filename := SourcePath; -- kludge
     elsif length( Filename ) = 0 then
        Filename := TempPath;
     end if;
     MakeTempFileName( TempPath );
     SaveSource( DoBackgroundUpdate => false );
     SetInfoText( "Crossreferencing..." );
     UNIX( "gnatxref -v " & SourcePath &
           " | grep " & Filename &
           " | sort > " & TempPath );
     SetInfoText( "Sorting..." );
     LoadList( TempPath, TempList );
     Erase( TempPath );
     ShowListInfo( "Crossrefences", 0, 1, DisplayInfo.H_Res-1,
       DisplayInfo.V_Res-1, TempList );
     SetInfoText( "" );
     Str255List.Clear( TempList );
  end XrefSource;


-------------------------------------------------------------------------------
--  OPTIONS WINDOW
--
-- Misc menu/options
--
-- Open a window and let the user configure global options (options related to
-- all projects.  Options are saved in global vars beginning with "Opt_".
-------------------------------------------------------------------------------

  procedure OptionsWindow is
    QuietBox    : aliased ACheckBox;     -- 1
    BlueBox     : aliased ACheckBox;     -- 2
    CVSBox      : aliased ARadioButton;  -- 3
    SVNBox      : aliased ARadioButton;  -- 4
    NVCBox      : aliased ARadioButton;  -- 5
    KeyNormalBox : aliased ARadioButton; -- 6
    KeyYellowBox : aliased ARadioButton; -- 7
    KeyGreenBox  : aliased ARadioButton; -- 8
    KeyBlueBox   : aliased ARadioButton; -- 9
    KeyRedBox    : aliased ARadioButton; -- 10
    KeyPurpleBox : aliased ARadioButton; -- 11
    KeyBlackBox  : aliased ARadioButton; -- 12
    FuncNormalBox : aliased ARadioButton; -- 13
    FuncYellowBox : aliased ARadioButton; -- 14
    FuncGreenBox  : aliased ARadioButton; -- 15
    FuncBlueBox   : aliased ARadioButton; -- 16
    FuncRedBox    : aliased ARadioButton; -- 17
    FuncPurpleBox : aliased ARadioButton; -- 18
    FuncBlackBox  : aliased ARadioButton; -- 19
    HelpNoneBox   : aliased ARadioButton; -- 20
    HelpInfoBox   : aliased ARadioButton; -- 21
    HelpProtoBox : aliased ARadioButton; -- 22
    HelpBothBox  : aliased ARadioButton; -- 23
    BackupLabel : aliased AStaticLine;   -- 24
    BackupCmd   : aliased AnEditLine;    -- 25
    OKButton    : aliased ASimpleButton; -- 26
    VCLabel     : aliased AStaticLine;   -- 27
    KeyLabel    : aliased AStaticLine;   -- 28
    FuncLabel   : aliased AStaticLine;   -- 29
    HelpLabel   : aliased AStaticLine;   -- 30

    DT : ADialogTaskRecord;
  begin
    OpenWindow( To255( "Options" ), 1, 2, DisplayInfo.H_Res-2, 23, Normal,
      HasInfoBar => true );

    Init( QuietBox, 1, 2, 30, 2, 'q' );
    SetText( QuietBox, To255( "Quiet Updates" ) );
    SetInfo( QuietBox, To255( "Don't automatically compile on saves" ) );
    AddControl( QuietBox'unchecked_access, false );

    Init( BlueBox, 40, 2, 70, 2, 'b' );
    SetText( BlueBox, To255( "Blue background" ) );
    SetInfo( BlueBox, To255( "Blue background on colour display" ) );
    AddControl( BlueBox'unchecked_access, false );

    Init( CVSBox, 3, 5, 18, 5, 1, 'c' );
    SetText( CVSBox, To255( "CVS" ) );
    SetInfo( CVSBox, To255( "Use Concurrent Version System to track project changes" ) );
    AddControl( CVSBox'unchecked_access, false );
    if not HasCVS then
       SetStatus( CVSBox, Off );
    end if;

    Init( SVNBox, 19, 5, 37, 5, 1, 'v' );
    SetText( SVNBox, To255( "Subversion" ) );
    SetInfo( SVNBox, To255( "Use Subversion to track project changes" ) );
    AddControl( SVNBox'unchecked_access, false );
    if not HasSVN then
       SetStatus( SVNBox, Off );
    end if;

    Init( NVCBox, 38, 5, 53, 5, 1, 's' );
    SetText( NVCBox, To255( "None" ) );
    SetInfo( NVCBox, To255( "Use no version control" ) );
    AddControl( NVCBox'unchecked_access, false );

    Init( KeyNormalBox, 3, 8, 13, 8, 2 );
    SetText( KeyNormalBox, To255( "Normal" ) );
    SetInfo( KeyNormalBox, To255( "Normal text colour" ) );
    AddControl( KeyNormalBox'unchecked_access, false );

    Init( KeyYellowBox, 14, 8, 24, 8, 2 );
    SetText( KeyYellowBox, To255( "Yellow" ) );
    SetInfo( KeyYellowBox, To255( "Yellow" ) );
    AddControl( KeyYellowBox'unchecked_access, false );

    Init( KeyGreenBox, 25, 8, 34, 8, 2 );
    SetText( KeyGreenBox, To255( "Green" ) );
    SetInfo( KeyGreenBox, To255( "Green" ) );
    AddControl( KeyGreenBox'unchecked_access, false );

    Init( KeyBlueBox, 35, 8, 43, 8, 2 );
    SetText( KeyBlueBox, To255( "Blue" ) );
    SetInfo( KeyBlueBox, To255( "Blue" ) );
    AddControl( KeyBlueBox'unchecked_access, false );

    Init( KeyRedBox, 44, 8, 51, 8, 2 );
    SetText( KeyRedBox, To255( "Red" ) );
    SetInfo( KeyRedBox, To255( "Red" ) );
    AddControl( KeyRedBox'unchecked_access, false );

    Init( KeyPurpleBox, 52, 8, 62, 8, 2 );
    SetText( KeyPurpleBox, To255( "Purple" ) );
    SetInfo( KeyPurpleBox, To255( "Purple" ) );
    AddControl( KeyPurpleBox'unchecked_access, false );

    Init( KeyBlackBox, 63, 8, 73, 8, 2 );
    SetText( KeyBlackBox, To255( "Black" ) );
    SetInfo( KeyBlackBox, To255( "Black" ) );
    AddControl( KeyBlackBox'unchecked_access, false );

    Init( FuncNormalBox, 3, 11, 13, 11, 3 );
    SetText( FuncNormalBox, To255( "Normal" ) );
    SetInfo( FuncNormalBox, To255( "Normal text colour" ) );
    AddControl( FuncNormalBox'unchecked_access, false );

    Init( FuncYellowBox, 14, 11, 24, 11, 3 );
    SetText( FuncYellowBox, To255( "Yellow" ) );
    SetInfo( FuncYellowBox, To255( "Yellow" ) );
    AddControl( FuncYellowBox'unchecked_access, false );

    Init( FuncGreenBox, 25, 11, 34, 11, 3 );
    SetText( FuncGreenBox, To255( "Green" ) );
    SetInfo( FuncGreenBox, To255( "Green" ) );
    AddControl( FuncGreenBox'unchecked_access, false );

    Init( FuncBlueBox, 35, 11, 43, 11, 3 );
    SetText( FuncBlueBox, To255( "Blue" ) );
    SetInfo( FuncBlueBox, To255( "Blue" ) );
    AddControl( FuncBlueBox'unchecked_access, false );

    Init( FuncRedBox, 44, 11, 51, 11, 3 );
    SetText( FuncRedBox, To255( "Red" ) );
    SetInfo( FuncRedBox, To255( "Red" ) );
    AddControl( FuncRedBox'unchecked_access, false );

    Init( FuncPurpleBox, 52, 11, 62, 11, 3 );
    SetText( FuncPurpleBox, To255( "Purple" ) );
    SetInfo( FuncPurpleBox, To255( "Purple" ) );
    AddControl( FuncPurpleBox'unchecked_access, false );

    Init( FuncBlackBox, 63, 11, 73, 11, 3 );
    SetText( FuncBlackBox, To255( "Black" ) );
    SetInfo( FuncBlackBox, To255( "Black" ) );
    AddControl( FuncBlackBox'unchecked_access, false );

    Init( HelpNoneBox, 3, 14, 13, 14, 4 );
    SetText( HelpNoneBox, To255( "None" ) );
    SetInfo( HelpNoneBox, To255( "Show no help for common words" ) );
    AddControl( HelpNoneBox'unchecked_access, false );

    Init( HelpInfoBox, 14, 14, 25, 14, 4 );
    SetText( HelpInfoBox, To255( "Info" ) );
    SetInfo( HelpInfoBox, To255( "Show info about common words" ) );
    AddControl( HelpInfoBox'unchecked_access, false );

    Init( HelpProtoBox, 26, 14, 36, 14, 4 );
    SetText( HelpProtoBox, To255( "Syntax" ) );
    SetInfo( HelpProtoBox, To255( "Show syntax of common words" ) );
    AddControl( HelpProtoBox'unchecked_access, false );

    Init( HelpBothBox, 37, 14, 48, 14, 4 );
    SetText( HelpBothBox, To255( "Both" ) );
    SetInfo( HelpBothBox, To255( "Show both syntax and info about common words" ) );
    AddControl( HelpBothBox'unchecked_access, false );

    Init( BackupLabel, 1, 17, 8, 17 );
    SetText( BackupLabel, To255( "Backup:") );
    AddControl( BackupLabel'unchecked_access, false );

    Init( BackupCmd, 9, 17, DisplayInfo.H_Res-4, 17 );
    SetText( BackupCmd, Opt_Backup );
    SetInfo( BackupCmd, To255( "Shell Command to back up project files" ) );
    AddControl( BackupCmd'unchecked_access, false );

    Init( OKButton, 35, 19, 50, 19, 'o' );
    SetText( OKButton, To255( "OK" ) );
    AddControl( OKButton'unchecked_access, false );

    Init( VCLabel, 1, 4, 16, 4 );
    SetText( VCLabel, To255( "Version Control:") );
    AddControl( VCLabel'unchecked_access, false );

    Init( KeyLabel, 1, 7, 16, 7 );
    SetText( KeyLabel, To255( "Keyword Hilight:") );
    AddControl( KeyLabel'unchecked_access, false );

    Init( FuncLabel, 1, 10, 20, 10 );
    SetText( FuncLabel, To255( "Function Hilight:") );
    AddControl( FuncLabel'unchecked_access, false );

    Init( HelpLabel, 1, 13, 20, 13 );
    SetText( HelpLabel, To255( "Item Help:") );
    AddControl( HelpLabel'unchecked_access, false );

    SetCheck( QuietBox,  Opt_Quiet );
    SetCheck( BlueBox,  Opt_Blue );

    SetCheck( CVSBox, false );
    SetCheck( SVNBox, false );
    SetCheck( NVCBox, false );
    if not HasCVS and not HasSVN then
       SetCheck( NVCBox, true );
    elsif Opt_CVS then
       SetCheck( CVSBox, true );
    elsif Opt_SVN then
       SetCheck( SVNBox, true );
    else
       SetCheck( NVCBox, true );
    end if;

    SetCheck( KeyNormalBox,  false );
    SetCheck( KeyYellowBox,  false );
    SetCheck( KeyGreenBox,  false );
    SetCheck( KeyBlueBox,  false );
    SetCheck( KeyRedBox,  false );
    SetCheck( KeyPurpleBox,  false );
    SetCheck( KeyBlackBox,  false );
    case KeywordHilight is
    when yellow => SetCheck( KeyYellowBox, true );
    when green  => SetCheck( KeyGreenBox, true );
    when blue   => SetCheck( KeyBlueBox, true );
    when red    => SetCheck( KeyRedBox, true );
    when purple => SetCheck( KeyPurpleBox, true );
    when black  => SetCheck( KeyBlackBox, true );
    when others => SetCheck( KeyNormalBox, true );
    end case;

    SetCheck( FuncNormalBox,  false );
    SetCheck( FuncYellowBox,  false );
    SetCheck( FuncGreenBox,  false );
    SetCheck( FuncBlueBox,  false );
    SetCheck( FuncRedBox,  false );
    SetCheck( FuncPurpleBox,  false );
    SetCheck( FuncBlackBox,  false );
    SetCheck( FuncNormalBox, false );
    case FunctionHilight is
    when yellow => SetCheck( FuncYellowBox, true );
    when green  => SetCheck( FuncGreenBox, true );
    when blue   => SetCheck( FuncBlueBox, true );
    when red    => SetCheck( FuncRedBox, true );
    when purple => SetCheck( FuncPurpleBox, true );
    when black  => SetCheck( FuncBlackBox, true );
    when others => SetCheck( FuncNormalBox, true );
    end case;

    SetCheck( HelpNoneBox,  false );
    SetCheck( HelpInfoBox,  false );
    SetCheck( HelpProtoBox,  false );
    SetCheck( HelpBothBox,  false );
    case AutoHelpStyle is
    when none => SetCheck( HelpNoneBox, true );
    when info => SetCheck( HelpInfoBox, true );
    when proto => SetCheck( HelpProtoBox, true );
    when others => SetCheck( HelpBothBox, true );
    end case;

    loop
      DoDialog( DT );
      case DT.control is
      when 26 => exit;
      when others => null;
      end case;
    end loop;
    if GetCheck( KeyYellowBox ) then
       KeywordHilight := yellow;
    elsif GetCheck( KeyGreenBox ) then
       KeywordHilight := green;
    elsif GetCheck( KeyBlueBox ) then
       KeywordHilight := blue;
    elsif GetCheck( KeyRedBox ) then
       KeywordHilight := red;
    elsif GetCheck( KeyPurpleBox ) then
       KeywordHilight := purple;
    elsif GetCheck( KeyBlackBox ) then
       KeywordHilight := black;
    else
       KeywordHilight := white;
    end if;
    SetKeywordHilight( SourceBox, KeywordHilight );
    if GetCheck( FuncYellowBox ) then
       FunctionHilight := yellow;
    elsif GetCheck( FuncGreenBox ) then
       FunctionHilight := green;
    elsif GetCheck( FuncBlueBox ) then
       FunctionHilight := blue;
    elsif GetCheck( FuncRedBox ) then
       FunctionHilight := red;
    elsif GetCheck( FuncPurpleBox ) then
       FunctionHilight := purple;
    elsif GetCheck( FuncBlackBox ) then
       FunctionHilight := black;
    else
       FunctionHilight := white;
    end if;
    SetFunctionHilight( SourceBox, FunctionHilight );
    if GetCheck( HelpInfoBox ) then
       AutoHelpStyle := Info;
    elsif GetCheck( HelpProtoBox ) then
       AutoHelpStyle := Proto;
    elsif GetCheck( HelpNoneBox ) then
       AutoHelpStyle := None;
    else
       AutoHelpStyle := Both;
    end if;
    Opt_Quiet := GetCheck( QuietBox );
    Opt_Blue := GetCheck( BlueBox );
    Opt_CVS := GetCheck( CVSBox );
    Opt_SVN := GetCheck( SVNBox );
    Opt_Backup := GetText( BackupCmd );
    BlueBackground( Opt_Blue );
    CloseWindow;
  end OptionsWindow;


-------------------------------------------------------------------------------
--  PROJECT PARAMS
--
-- Proj menu/params
--
-- Display the project parameters window and let the user change the project
-- parameters.  If parameters affecting the entire project are changed, force
-- a rebuild of the entire project on the next build.
-------------------------------------------------------------------------------

  procedure ProjectParams is

    RepLabel  : aliased AStaticLine;   -- 1
    RepLine   : aliased AnEditLine;    -- 2
    MainLabel : aliased AStaticLine;   -- 3
    MainLine  : aliased AnEditLine;    -- 4
    GUILabel  : aliased AStaticLine;   -- 5
    GUILine   : aliased AnEditLine;    -- 6
    OptLabel  : aliased AStaticLine;   -- 7
    OptBox1   : aliased ARadioButton;  -- 8
    OptBox2   : aliased ARadioButton;  -- 9
    OptBox3   : aliased ARadioButton;  -- 10
    OptBox4   : aliased ARadioButton;  -- 11
    DebugLabel: aliased AStaticLine;   -- 12
    DebugBox1 : aliased ARadioButton;  -- 13
    DebugBox2 : aliased ARadioButton;  -- 14
    DebugBox3 : aliased ARadioButton;  -- 15
    KindLabel : aliased AStaticLine;   -- 16
    KindBox1  : aliased ARadioButton;  -- 17
    KindBox2  : aliased ARadioButton;  -- 18
    KindBox3  : aliased ARadioButton;  -- 19
    KindBox4  : aliased ARadioButton;  -- 20
    BuildLabel: aliased AStaticLine;   -- 21
    BuildBox1 : aliased ARadioButton;  -- 22
    BuildBox2 : aliased ARadioButton;  -- 23
    BuildBox3 : aliased ARadioButton;  -- 24
    BuildBox4 : aliased ARadioButton;  -- 25

    StaticBox : aliased ACheckBox;     -- 26

    OKButton  : aliased ASimpleButton; -- 27 / 21

    -- screen two

    MakeLabel : aliased AStaticLine;   -- 1
    MakeLine  : aliased AnEditLine;    -- 2
    LinkLabel : aliased AStaticLine;   -- 3
    LinkLine  : aliased AnEditLine;    -- 4

    AdaLabel  : aliased AStaticLine;   -- 5
    AdaBox1   : aliased ARadioButton;  -- 6
    AdaBox2   : aliased ARadioButton;  -- 7

    CLabel    : aliased AStaticLine;   -- 8
    CBox1     : aliased ARadioButton;  -- 9
    CBox2     : aliased ARadioButton;  -- 10

    JavaLabel : aliased AStaticLine;   -- 11
    JavaBox1  : aliased ARadioButton;  -- 12
    JavaBox2  : aliased ARadioButton;  -- 13

    CPULabel  : aliased AStaticLine;   -- 14
    CPUBox1   : aliased ARadioButton;  -- 15
    CPUBox2   : aliased ARadioButton;  -- 16
    CPUBox3   : aliased ARadioButton;  -- 17
    CPUBox4   : aliased ARadioButton;  -- 18
    CPUBox5   : aliased ARadioButton;  -- 19
    CPUBox6   : aliased ARadioButton;  -- 20

    DT : ADialogTaskRecord;

  begin
    OpenWindow( To255( "Project Parameters (General)" ), 1, 4, DisplayInfo.H_Res-2, 23, Normal, HasInfoBar => true );

    Init( RepLabel, 1, 2, 12, 2 );
    SetText( RepLabel, To255( "Repository:" ) );
    SetStyle( RepLabel, Bold );
    SetColour( RepLabel, Yellow );
    AddControl( RepLabel'unchecked_access, false );

    Init( RepLine, 13, 2, DisplayInfo.H_Res-4, 2 );
    SetText( RepLine, Proj_Repository );
    SetInfo( RepLine, To255( "Subversion repository URL (if using svn)" ) );
    AddControl( RepLine'unchecked_access, false );

    Init( MainLabel, 1, 4, 10, 4 );
    SetText( MainLabel, To255( "Program:" ) );
    SetStyle( MainLabel, Bold );
    SetColour( MainLabel, Yellow );
    AddControl( MainLabel'unchecked_access, false );

    Init( MainLine, 11, 4, DisplayInfo.H_Res-4, 4 );
    SetText( MainLine, Proj_Main );
    SetInfo( MainLine, To255( "Name of the main program (e.g. gnatmake name)" ) );
    AddControl( MainLine'unchecked_access, false );

    Init( GUILabel, 1, 6, 12, 6 );
    SetText( GUILabel, To255( "GUI Builder:" ) );
    SetStyle( GUILabel, Bold );
    SetColour( GUILabel, Yellow );
    AddControl( GUILabel'unchecked_access, false );

    Init( GUILine, 14, 6, DisplayInfo.H_Res-4, 6 );
    SetText( GUILine, Proj_GUI );
    SetInfo( GUILine, To255( "GUI builder program to run for GUI menu item" ) );
    AddControl( GUILine'unchecked_access, false );

    Init( OptLabel, 1, 8, 10, 8 );
    SetText( OptLabel, To255( "Optimize:" ) );
    SetStyle( OptLabel, Bold );
    SetColour( OptLabel, Yellow );
    AddControl( OptLabel'unchecked_access, false );

    Init( OptBox1, 11, 8, 25, 8, 1 );
    SetText( OptBox1, To255( "None" ) );
    SetInfo( OptBox1, To255( "No special optimization" ) );
    AddControl( OptBox1'unchecked_access, false );

    Init( OptBox2, 26, 8, 41, 8, 1 );
    SetText( OptBox2, To255( "Basic" ) );
    SetInfo( OptBox2, To255( "Build with basic optimization (if available)" ) );
    AddControl( OptBox2'unchecked_access, false );

    Init( OptBox3, 42, 8, 57, 8, 1 );
    SetText( OptBox3, To255( "Size" ) );
    SetInfo( OptBox3, To255( "Build by optimizing for size (if available)" ) );
    AddControl( OptBox3'unchecked_access, false );

    Init( OptBox4, 58, 8, 73, 8, 1 );
    SetText( OptBox4, To255( "Speed" ) );
    SetInfo( OptBox4, To255( "Build by optimizing for speed (if available)" ) );
    AddControl( OptBox4'unchecked_access, false );

    Init( DebugLabel, 1, 11, 10, 11 );
    SetText( DebugLabel, To255( "Debug:" ) );
    SetStyle( DebugLabel, Bold );
    SetColour( DebugLabel, Yellow );
    AddControl( DebugLabel'unchecked_access, false );

    Init( DebugBox1, 11, 11, 25, 11, 3 );
    SetText( DebugBox1, To255( "Release" ) );
    SetInfo( DebugBox1, To255( "Build for final release version (e.g. make release)" ) );
    AddControl( DebugBox1'unchecked_access, false );

    Init( DebugBox2, 26, 11, 41, 11, 3 );
    SetText( DebugBox2, To255( "Alpha/Beta" ) );
    SetInfo( DebugBox2, To255( "Build for limited testing version (e.g. make beta)" ) );
    AddControl( DebugBox2'unchecked_access, false );

    Init( DebugBox3, 58, 11, 73, 11, 3 );
    SetText( DebugBox3, To255( "Prerelease" ) );
    SetInfo( DebugBox3, To255( "Build for developmental version (e.g. make)" ) );
    AddControl( DebugBox3'unchecked_access, false );

    Init( KindLabel, 1, 12, 10, 12 );
    SetText( KindLabel, To255( "Kind:" ) );
    SetStyle( KindLabel, Bold );
    SetColour( KindLabel, Yellow );
    AddControl( KindLabel'unchecked_access, false );

    Init( KindBox1, 11, 12, 25, 12, 4 );
    SetText( KindBox1, To255( "Program" ) );
    SetInfo( KindBox1, To255( "Build a standalone application" ) );
    AddControl( KindBox1'unchecked_access, false );

    Init( KindBox2, 26, 12, 41, 12, 4 );
    SetText( KindBox2, To255( "Package" ) );
    SetInfo( KindBox2, To255( "Build an Ada package" ) );
    AddControl( KindBox2'unchecked_access, false );

    Init( KindBox3, 42, 12, 57, 12, 4 );
    SetText( KindBox3, To255( "Static Lib" ) );
    SetInfo( KindBox3, To255( "Build a static library" ) );
    AddControl( KindBox3'unchecked_access, false );

    Init( KindBox4, 58, 12, 73, 12, 4 );
    SetText( KindBox4, To255( "Shared Lib" ) );
    SetInfo( KindBox4, To255( "Build a shared library" ) );
    SetStatus( KindBox4, Off );
    AddControl( KindBox4'unchecked_access, false );

    Init( BuildLabel, 1, 13, 10, 13 );
    SetText( BuildLabel, To255( "Builder:" ) );
    SetStyle( BuildLabel, Bold );
    SetColour( BuildLabel, Yellow );
    AddControl( BuildLabel'unchecked_access, false );

    Init( BuildBox1, 11, 13, 25, 13, 5 );
    SetText( BuildBox1, To255( "Gnatmake" ) );
    SetInfo( BuildBox1, To255( "Build an Ada project with 'gnatmake'" ) );
    AddControl( BuildBox1'unchecked_access, false );

    Init( BuildBox2, 26, 13, 41, 13, 5 );
    SetText( BuildBox2, To255( "Make" ) );
    SetInfo( BuildBox2, To255( "Build a project with 'make'" ) );
    AddControl( BuildBox2'unchecked_access, false );

    Init( BuildBox3, 42, 13, 57, 13, 5 );
    SetText( BuildBox3, To255( "Cook" ) );
    SetInfo( BuildBox3, To255( "Build a project with 'cook'" ) );
    AddControl( BuildBox3'unchecked_access, false );

    Init( BuildBox4, 58, 13, 73, 13, 5 );
    SetText( BuildBox4, To255( "JGnatmake" ) );
    SetInfo( BuildBox4, To255( "Build an Ada project into Java application with 'jgnatmake'" ) );
    AddControl( BuildBox4'unchecked_access, false );

    Init( StaticBox, 1, 15, 21, 15, 's' );
    SetText( StaticBox, To255( "Static Linking" ) );
    SetInfo( StaticBox, To255( "Build all libraries into final executable" ) );
    AddControl( StaticBox'unchecked_access, false );

    Init( OKButton, 35, 17, 50, 17, 'C' );
    SetText( OKButton, To255( "Continue" ) );
    SetInfo( OKButton, To255( "Continue on to compiler options" ) );
    AddControl( OKButton'unchecked_access, false );

    --

    SetCheck( OptBox1, false );
    SetCheck( OptBox2, false );
    SetCheck( OptBox3, false );
    SetCheck( OptBox4, false );
    if Proj_Opt = 1 then
       SetCheck( OptBox1, true );
    elsif Proj_Opt = 2 then
       SetCheck( OptBox2, true );
    elsif Proj_Opt = 3 then
       SetCheck( OptBox3, true );
    else
       SetCheck( OptBox4, true );
    end if;

    SetCheck( DebugBox1, false );
    SetCheck( DebugBox2, false );
    SetCheck( DebugBox3, false );
    if Proj_Debug = 1 then
       SetCheck( DebugBox1, true );
    elsif Proj_Debug = 2 then
       SetCheck( DebugBox2, true );
    else
       SetCheck( DebugBox3, true );
    end if;

    SetCheck( KindBox1, false );
    SetCheck( KindBox2, false );
    SetCheck( KindBox3, false );
    SetCheck( KindBox4, false );
    if Proj_Kind = 1 then
       SetCheck( KindBox1, true );
    elsif Proj_Kind = 2 then
       SetCheck( KindBox2, true );
    elsif Proj_Kind = 3 then
       SetCheck( KindBox3, true );
    else
       SetCheck( KindBox4, true );
    end if;

    SetCheck( BuildBox1, false );
    SetCheck( BuildBox2, false );
    SetCheck( BuildBox3, false );
    SetCheck( BuildBox4, false );
    if Proj_Builder = 1 then
       SetCheck( BuildBox1, true );
    elsif Proj_Builder = 2 then
       SetCheck( BuildBox2, true );
    elsif Proj_Builder = 3 then
       SetCheck( BuildBox3, true );
    else
       SetCheck( BuildBox4, true );
    end if;

    SetCheck( StaticBox, Proj_Static );

    loop
      DoDialog( DT );
      case DT.control is
      when 27 => -- OK
        if GetCheck( OptBox1 ) and Proj_Opt /= 1 then
           Proj_Opt := 1;
           NeedsFullRecompile := true;
        elsif GetCheck( OptBox2 ) and Proj_Opt /= 2 then
           Proj_Opt := 2;
           NeedsFullRecompile := true;
        elsif GetCheck( OptBox3 ) and Proj_Opt /= 3 then
           Proj_Opt := 3;
           NeedsFullRecompile := true;
        elsif GetCheck( OptBox4 ) and Proj_Opt /= 4 then
           NeedsFullRecompile := true;
           Proj_Opt := 4;
        end if;

        if GetCheck( DebugBox1 ) and Proj_Debug /= 1 then
           Proj_Debug := 1;
           NeedsFullRecompile := true;
        elsif GetCheck( DebugBox2 ) and Proj_Debug /= 2 then
           Proj_Debug := 2;
           NeedsFullRecompile := true;
        elsif GetCheck( DebugBox3 ) and Proj_Debug /= 3 then
           Proj_Debug := 3;
           NeedsFullRecompile := true;
        end if;

        if GetCheck( KindBox1 ) then
           Proj_Kind := 1;
        elsif GetCheck( KindBox2 ) then
           Proj_Kind := 2;
        elsif GetCheck( KindBox3 ) then
           Proj_Kind := 3;
        else
           Proj_Kind := 4;
        end if;

        if GetCheck( BuildBox1 ) then
           Proj_Builder := 1;
        elsif GetCheck( BuildBox2 ) then
           Proj_Builder := 2;
        elsif GetCheck( BuildBox3 ) then
           Proj_Builder := 3;
        else
           Proj_Builder := 4;
        end if;

        Proj_Main        := GetText( MainLine );
        Proj_Static      := GetCheck( StaticBox );
        Proj_GUI         := GetText( GUILine );
        Proj_Repository  := GetText( RepLine );
        exit;
      when others => null;
      end case;
    end loop;

    CloseWindow;

    OpenWindow( To255( "Project Parameters (Compilers)" ), 1, 4, DisplayInfo.H_Res-2, 23, Normal, HasInfoBar => true );

    Init( MakeLabel, 1, 2, 10, 2 );
    SetText( MakeLabel, To255( "Compiling:" ) );
    SetStyle( MakeLabel, Bold );
    SetColour( MakeLabel, Yellow );
    AddControl( MakeLabel'unchecked_access, false );

    Init( MakeLine, 11, 2, DisplayInfo.H_Res-4, 2 );
    SetText( MakeLine, Proj_GCCOptions );
    SetInfo( MakeLine, To255( "Additional compiling options" ) );
    AddControl( MakeLine'unchecked_access, false );

    Init( LinkLabel, 1, 4, 10, 4 );
    SetText( LinkLabel, To255( "Linking:" ) );
    SetStyle( LinkLabel, Bold );
    SetColour( LinkLabel, Yellow );
    AddControl( LinkLabel'unchecked_access, false );

    Init( LinkLine, 11, 4, DisplayInfo.H_Res-4, 4 );
    SetText( LinkLine, Proj_LinkOptions );
    SetInfo( LinkLine, To255( "Additional linking options" ) );
    AddControl( LinkLine'unchecked_access, false );

    Init( AdaLabel, 1, 6, 15, 6 );
    SetText( AdaLabel, To255( "Ada Compiler:" ) );
    SetStyle( AdaLabel, Bold );
    SetColour( AdaLabel, Yellow );
    AddControl( AdaLabel'unchecked_access, false );

    Init( AdaBox1, 16, 6, 40, 6, 11 );
    SetText( AdaBox1, To255( "GCC Ada (gcc)" ) );
    SetInfo( AdaBox1, To255( "Use 'gcc' to compile Ada files" ) );
    AddControl( AdaBox1'unchecked_access, false );

    Init( AdaBox2, 41, 6, 65, 6, 11 );
    SetText( AdaBox2, To255( "GCC Ada (gnatgcc)" ) );
    SetInfo( AdaBox2, To255( "Use 'gnatgcc' to compile Ada files" ) );
    AddControl( AdaBox2'unchecked_access, false );

    Init( CLabel, 1, 7, 15, 7 );
    SetText( CLabel, To255( "C Compiler:" ) );
    SetStyle( CLabel, Bold );
    SetColour( CLabel, Yellow );
    AddControl( CLabel'unchecked_access, false );

    Init( CBox1, 16, 7, 40, 7, 10 );
    SetText( CBox1, To255( "GCC C (gcc)" ) );
    SetInfo( CBox1, To255( "Use 'gcc' to compile C files" ) );
    AddControl( CBox1'unchecked_access, false );

    Init( CBox2, 41, 7, 65, 7, 10 );
    SetText( CBox2, To255( "egcs" ) );
    SetInfo( CBox2, To255( "Use old 'egcs' extended GCC compiler to compile C files" ) );
    AddControl( CBox2'unchecked_access, false );

    Init( JavaLabel, 1, 8, 15, 8 );
    SetText( JavaLabel, To255( "Java Compiler:" ) );
    SetStyle( JavaLabel, Bold );
    SetColour( JavaLabel, Yellow );
    AddControl( JavaLabel'unchecked_access, false );

    Init( JavaBox1, 16, 8, 40, 8, 12 );
    SetText( JavaBox1, To255( "GCC java (gcj)" ) );
    SetInfo( JavaBox1, To255( "Use 'gcj' to compile Java files" ) );
    AddControl( JavaBox1'unchecked_access, false );

    Init( JavaBox2, 41, 8, 65, 8, 12 );
    SetText( JavaBox2, To255( "Sun Java (javac)" ) );
    SetInfo( JavaBox2, To255( "Use 'javac' to compile Java files" ) );
    AddControl( JavaBox2'unchecked_access, false );

    Init( CPULabel, 1, 10, 15, 10 );
    SetText( CPULabel, To255( "CPU:" ) );
    SetStyle( CPULabel, Bold );
    SetColour( CPULabel, Yellow );
    AddControl( CPULabel'unchecked_access, false );

    Init( CPUBox1, 16, 10, 31, 10, 2 );
    SetText( CPUBox1, To255( "386" ) );
    SetInfo( CPUBox1, To255( "Compile for a minimum of Intel 386 (if available)" ) );
    AddControl( CPUBox1'unchecked_access, false );

    Init( CPUBox2, 32, 10, 46, 10, 2 );
    SetText( CPUBox2, To255( "486" ) );
    SetInfo( CPUBox2, To255( "Compile for a minimum of Intel 486 (if available)" ) );
    AddControl( CPUBox2'unchecked_access, false );

    Init( CPUBox3, 47, 10, 62, 10, 2 );
    SetText( CPUBox3, To255( "Pentium/II" ) );
    SetInfo( CPUBox3, To255( "Compile for a minimum of Intel Pentium or Pentium II (if available)" ) );
    AddControl( CPUBox3'unchecked_access, false );

    Init( CPUBox4, 16, 11, 31, 11, 2 );
    SetText( CPUBox4, To255( "Other" ) );
    SetInfo( CPUBox4, To255( "Other processor / Use default for your compiler" ) );
    AddControl( CPUBox4'unchecked_access, false );

    Init( CPUBox5, 32, 11, 46, 11, 2 );
    SetText( CPUBox5, To255( "Athon" ) );
    SetInfo( CPUBox5, To255( "Compile for AMD Athlon 32-bit (if available)" ) );
    AddControl( CPUBox5'unchecked_access, false );

    Init( CPUBox6, 47, 11, 62, 11, 2 );
    SetText( CPUBox6, To255( "x86_64" ) );
    SetInfo( CPUBox6, To255( "Compile for AMD Athlon 64-bit (x86_64) (if available)" ) );
    AddControl( CPUBox6'unchecked_access, false );

    Init( OKButton, 35, 17, 50, 17, 'o' );
    SetText( OKButton, To255( "OK" ) );
    SetInfo( OKButton, To255( "" ) );
    AddControl( OKButton'unchecked_access, false );

    SetCheck( AdaBox1, false );
    SetCheck( AdaBox2, false );
    if Proj_Alt then
       SetCheck( AdaBox2, true );
    else
       SetCheck( AdaBox1, true );
    end if;

    SetCheck( CBox1, false );
    SetCheck( CBox2, false );
    if Proj_Egcs then
       SetCheck( CBox2, true );
    else
       SetCheck( CBox1, true );
    end if;

    SetCheck( JavaBox1, false );
    SetCheck( JavaBox2, false );
    if Proj_GCJ then
       SetCheck( JavaBox1, true );
    else
       SetCheck( JavaBox2, true );
    end if;

    SetCheck( CPUBox1, false );
    SetCheck( CPUBox2, false );
    SetCheck( CPUBox3, false );
    SetCheck( CPUBox4, false );
    if Proj_CPU = 1 then
       SetCheck( CPUBox1, true );
    elsif Proj_CPU = 2 then
       SetCheck( CPUBox2, true );
    elsif Proj_CPU = 3 then
       SetCheck( CPUBox3, true );
    elsif Proj_CPU = 4 then
       SetCheck( CPUBox4, true );
    elsif Proj_CPU = 5 then
       SetCheck( CPUBox5, true );
    else
       SetCheck( CPUBox6, true );
    end if;

    loop
      DoDialog( DT );
      case DT.control is
      when 21 => -- OK

        Proj_GCCOptions := GetText( MakeLine );
        Proj_LinkOptions := GetText( LinkLine );

        Proj_Alt := GetCheck( AdaBox2 );
        Proj_EGCS := GetCheck( CBox2 );
        Proj_GCJ := GetCheck( JavaBox1 );

        if GetCheck( CPUBox1 ) and Proj_CPU /= 1 then
           Proj_CPU := 1;
           NeedsFullRecompile := true;
        elsif GetCheck( CPUBox2 ) and Proj_CPU /= 2 then
           Proj_CPU := 2;
           NeedsFullRecompile := true;
        elsif GetCheck( CPUBox3 ) and Proj_CPU /= 3 then
           Proj_CPU := 3;
           NeedsFullRecompile := true;
        elsif GetCheck( CPUBox4 ) and Proj_CPU /= 4 then
           Proj_CPU := 4;
           NeedsFullRecompile := true;
        elsif GetCheck( CPUBox5 ) and Proj_CPU /= 5 then
           Proj_CPU := 5;
           NeedsFullRecompile := true;
        elsif GetCheck( CPUBox6 ) and Proj_CPU /= 6 then
           Proj_CPU := 6;
           NeedsFullRecompile := true;
        end if;
        exit;

      when others => null;
      end case;
    end loop;

    CloseWindow;


  end ProjectParams;


-------------------------------------------------------------------------------
--  PROJECT HISTORY
--
-- Proj menu/history
--
-- Show stats for entire project, unlike File/stats which is for the current
-- file.  Not complete.
-------------------------------------------------------------------------------

  procedure ProjectHistory is
    ch : character := ASCII.NUL;
  begin
    OpenWindow( To255( "Project History" ), 5, 4, 70, 20, Status, false );

    MoveToGlobal( 6, 6 );
    SetTextStyle( Normal );
    Draw( "Number of successful builds: " & Proj_BuildCount'img );
    MoveToGlobal( 6, 7 );
    Draw( "Last successful build: " & Proj_BuildTimeStr );

    MoveToGlobal( 6, 9 );
    Draw( "Source files (current dir): " &
      UNIX( "ls *.ads *.adb *.c *.cpp *.java *.pm *.pl *.bush *.php 2>/dev/null | wc -l" ) );
    MoveToGlobal( 6, 10 );
    Draw( "Characters typed:" & Proj_KeyCount'img );
    MoveToGlobal( 6, 11 );
    Draw( "Lines typed:" & Proj_LineCount'img );

    MoveToGlobal( 6, 17 );
    Draw( "Characters typed (all projects):" & Opt_KeyCount'img );

    SetPenColour( White );
    MoveToGlobal( 6, 19 );
    Draw( "Press any key to continue" );
    GetKey( ch );
    CloseWindow;
  end ProjectHistory;


-------------------------------------------------------------------------------
--  GOTO LINE
--
-- Edit menu/goto
--
-- Prompt the user for a line to go to, or the last line marked for editing
-- (with ctrl-6 or mark in the edit menu).
-------------------------------------------------------------------------------

  procedure GotoLine is
    -- goto dialog
    TextLine      : aliased ALongIntEditLine;
    GotoButton    : aliased ASimpleButton;
    CancelButton  : aliased ASimpleButton;
    MarkButton    : aliased ASimpleButton;

    DT : ADialogTaskRecord;

    Line2Goto     : long_integer;
  begin
    OpenWindow( To255( "Goto" ), 10, 10, 70, 16, Normal );

    Init( TextLine, 1, 2, 58, 2 );
    SetText( TextLine, NullStr255 );
    AddControl( TextLine'unchecked_access, false );

    Init( GotoButton, 2, 4, 11, 4, 'g' );
    SetText( GotoButton, To255( "Goto" ) );
    SetInstant( GotoButton );
    AddControl( GotoButton'unchecked_access, false );

    Init( CancelButton, 22, 4, 31, 4, 'l' );
    SetText( CancelButton, To255( "Cancel" ) );
    SetInstant( CancelButton );
    AddControl( CancelButton'unchecked_access, false );

    Init( MarkButton, 42, 4, 51, 4, 'm' );
    SetText( MarkButton, To255( "Mark" ) );
    SetInstant( MarkButton );
    AddControl( MarkButton'unchecked_access, false );

    loop
      DoDialog( DT );
      case DT.control is
      when 2 => Line2Goto := GetValue( TextLine );
                if Line2Goto > 0 then
                   if Line2Goto > GetLength( SourceBox ) then
                      Line2Goto := GetLength( SourceBox );
                   end if;
                   MoveCursor( SourceBox, 0, 
                     Line2Goto - GetCurrent( SourceBox ) );
                end if;
                exit;
      when 3 => exit;
      when 4 => Line2Goto := GetMark( SourceBox );
                if Line2Goto > 0 then
                   MoveCursor( SourceBox, 0, 
                      Line2Goto - GetCurrent( SourceBox ) );
                else
                   NoteAlert( "No mark set" );
                end if;
                exit;
      when others => null;
      end case;
    end loop;
    CloseWindow;
    UpdateSourceDisplay;

  end GotoLine;

-------------------------------------------------------------------------------
--  ITEM HELP
--
-- Lookup help for the word the cursor is on.
-------------------------------------------------------------------------------

  procedure ItemHelp is
   posn : integer;
   i    : natural;
   text : str255;
   word : str255;
   term : str255;
   TempStr : str255;
   fp   : functionDataPtr;
   temp : functionDataPtr;
   ch   : character;
   r    : aRect;

   function isIdentChar( ch : character ) return boolean is
   begin
     return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
       (ch = '_' ) or (ch = '.' );
   end isIdentChar;

   OKButton    : aliased aSimpleButton;
   LookupButton: aliased aSimpleButton;
   CommandList : aliased aRadioList;
   InfoLine1   : aliased aStaticLine;
   InfoLine2   : aliased aStaticLine;
   InfoLine3   : aliased aStaticLine;
   InfoLine4   : aliased aStaticLine;
   ProtoLine1  : aliased aStaticLine;
   ProtoLine2  : aliased aStaticLine;
   ProtoLine3  : aliased aStaticLine;
   ProtoLine4  : aliased aStaticLine;
   DescrLabel  : aliased aStaticLine;
   ProtoLabel  : aliased aStaticLine;

   DT : ADialogTaskRecord;

   TempList : Str255List.List;
   CheckList : BooleanList.List;

   first, last, width : integer;

   wordpos : long_integer;

  begin
    OpenWindow( To255( "Item Help" ), 1, 1, DisplayInfo.H_Res-2, DisplayInfo.V_Res-1,
      Normal );

   Init( OKButton, 25, DisplayInfo.V_Res-3, 40, DisplayInfo.V_Res-3, 'o' );
   SetText( LookupButton, To255( "OK" ) );
   AddControl( OKButton'unchecked_access, false );

   Init( LookupButton, 43, DisplayInfo.V_Res-3, 58, DisplayInfo.V_Res-3, 'l' );
   SetText( LookupButton, To255( "Lookup" ) );
   AddControl( LookupButton'unchecked_access, false );

   Init( CommandList, 1, 1, 30, DisplayInfo.V_Res-4 );
   AddControl( CommandList'unchecked_access, false );

   --Init( InfoLine1, 32, 2, 60, 2 );
   Init( InfoLine1, 32, 4, DisplayInfo.H_Res-5, 4 );
   AddControl( infoLine1'unchecked_access, false );

   Init( InfoLine2, 32, 5, DisplayInfo.H_Res-5, 5 );
   AddControl( infoLine2'unchecked_access, false );

   Init( InfoLine3, 32, 6, DisplayInfo.H_Res-5, 6 );
   AddControl( infoLine3'unchecked_access, false );

   Init( InfoLine4, 32, 7, DisplayInfo.H_Res-5, 7 );
   AddControl( infoLine4'unchecked_access, false );

   Init( ProtoLine1, 32, 11, DisplayInfo.H_Res-5, 11 );
   AddControl( ProtoLine1'unchecked_access, false );

   Init( ProtoLine2, 32, 12, DisplayInfo.H_Res-5, 12 );
   AddControl( ProtoLine2'unchecked_access, false );

   Init( ProtoLine3, 32, 13, DisplayInfo.H_Res-5, 13 );
   AddControl( ProtoLine3'unchecked_access, false );

   Init( ProtoLine4, 32, 14, DisplayInfo.H_Res-5, 14 );
   AddControl( ProtoLine4'unchecked_access, false );

   Init( DescrLabel, 32, 2, DisplayInfo.H_Res-5, 2 );
   SetStyle( DescrLabel, heading );
   SetText( DescrLabel, to255( "Description:" ) );
   AddControl( DescrLabel'unchecked_access, false );

   Init( ProtoLabel, 32, 9, DisplayInfo.H_Res-5, 9 );
   SetStyle( ProtoLabel, heading );
   SetText( ProtoLabel, to255( "Syntax:" ) );
   AddControl( ProtoLabel'unchecked_access, false );

    posn := GetPosition( SourceBox );
    CopyLine( SourceBox, text );
    ch := element( text, posn );
    if not isIdentChar( ch ) then
       CautionAlert( "Cursor is not on a letter" );
       return;
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
    while i < length( text ) loop
       ch := element( text, i );
       if isIdentChar( ch ) then
          i := i + 1;
       else
          i := i - 1;
          exit;
       end if;
    end loop;
    last := i;
    word := to255( Slice( text, first, last ) );

<<Lookup>>
    fp := findFunctionData( languageData, sourceLanguage, word );

    Str255List.Clear( TempList );
    if fp /= null then
       temp:= languageData( sourceLanguage ).functionBin( in_bin( toString( word ) ) );
       while temp /= null loop
          Str255List.Insert( TempList, to255( temp.functionName.all ) );
          temp := temp.next;
       end loop;
    end if;
    SetList( CommandList, TempList );

    BooleanList.Clear( CheckList );
    for i in 1..str255list.length( TempList ) loop
        str255list.find( TempList, i, TempStr );
        if TempStr = Word then
           wordpos := i;
        end if;
        BooleanList.Queue( CheckList, false );
    end loop;
    SetChecks( CommandList, CheckList, wordpos );
    MoveCursor( CommandList, 0, -Str255List.Length( TempList ) );
    MoveCursor( CommandList, 0, wordpos-1 );

    text := nullStr255;
    if fp /= null then
       if fp.functionInfo.all'length > 0 then
          text := to255( unpack( fp.functionInfo.all ) );
       else
          text := To255( "No description available" );
       end if;
    else
       text := To255( "No description available" );
    end if;

    SetText( InfoLine1, nullStr255 );
    SetText( InfoLine2, nullStr255 );
    SetText( InfoLine3, nullStr255 );
    SetText( InfoLine4, nullStr255 );
    SetText( ProtoLine1, nullStr255 );
    SetText( ProtoLine2, nullStr255 );
    SetText( ProtoLine3, nullStr255 );
    SetText( ProtoLine4, nullStr255 );

    if length( text ) > 0 then
       r := GetFrame( InfoLine1 );
       width := r.right - r.left + 1;
       first := 1;
       last := first + width - 1;
       if last > length( text ) then
          last := length( text );
       end if;
       SetText( InfoLine1, to255( slice( text, first, last ) ) );
       first := last + 1;
       if first <= length( text ) then
          last := first + width - 1;
          if last > length( text ) then
             last := length( text );
          end if;
          SetText( InfoLine2, to255( slice( text, first, last ) ) );
          first := last + 1;
          if first <= length( text ) then
             last := first + width - 1;
             if last > length( text ) then
                last := length( text );
             end if;
             SetText( InfoLine3, to255( slice( text, first, last ) ) );
             first := last + 1;
             if first <= length( text ) then
                last := first + width - 1;
                if last > length( text ) then
                   last := length( text );
                end if;
                last := first + 1;
                SetText( InfoLine4, to255( slice( text, first, last ) ) );
            end if;
          end if;
       end if;
    end if;

    text := nullStr255;
    if fp /= null then
       if fp.functionProto.all'length > 0 then
          text := to255( unpack( fp.functionProto.all ) );
       else
          text := To255( "No syntax available" );
       end if;
    else
       text := To255( "No syntax available" );
    end if;

    if length( text ) > 0 then
       r := GetFrame( ProtoLine1 );
       width := r.right - r.left + 1;
       first := 1;
       last := first + width - 1;
       if last > length( text ) then
          last := length( text );
       end if;
       SetText( ProtoLine1, to255( slice( text, first, last ) ) );
       first := last + 1;
       if first <= length( text ) then
          last := first + width - 1;
          if last > length( text ) then
             last := length( text );
          end if;
          SetText( ProtoLine2, to255( slice( text, first, last ) ) );
          first := last + 1;
          if first <= length( text ) then
             last := first + width - 1;
             if last > length( text ) then
                last := length( text );
             end if;
             SetText( ProtoLine3, to255( slice( text, first, last ) ) );
             first := last + 1;
             if first <= length( text ) then
                last := first + width - 1;
                if last > length( text ) then
                   last := length( text );
                end if;
                last := first + 1;
                SetText( ProtoLine4, to255( slice( text, first, last ) ) );
            end if;
          end if;
       end if;
    end if;


    loop
      DoDialog( DT );
      case DT.control is
      when 1 => exit;
      when 2 =>
             Str255List.Find( TempList, GetCheck( CommandList ), TempStr );
             word := TempStr;
             goto Lookup;
      when others => null;
      end case;
    end loop;

    CloseWindow;
    Str255List.Clear( TempList );
    BooleanList.Clear( CheckList );

  exception when others =>
    stopalert( "Internal error: exception raised" );
    CloseWindow;
    Str255List.Clear( TempList );
    BooleanList.Clear( CheckList );
  end ItemHelp;

-------------------------------------------------------------------------------
--  COMMENT OUT
--
-- Comment out lines of text.
-------------------------------------------------------------------------------

  procedure CommentOut is
    Mark1 : long_integer;
    Mark2 : Str255List.AListIndex;
    text : str255;
  begin
    Mark1 := GetMark( SourceBox );
    Mark2 := GetCurrent( SourceBox );
    if Mark1 < 0 then
       Mark1 := Mark2;
    end if;
    if Mark1 > long_integer( Mark2 ) then
       Mark2 := Str255List.AListIndex( GetMark( SourceBox ) );
       Mark1 := long_integer( GetCurrent( SourceBox ) );
    end if;
    if Mark1 <= 0 then
       NoteAlert( "Nothing to comment out" );
    else
       for i in Str255List.AListIndex'(Mark1)..Mark2 loop
           SetCursor( SourceBox, 1, i );
           CopyLine( SourceBox, text );
           if SourceLanguage = C then
              text := "// " & text;
           elsif SourceLanguage = CPP then
              text := "// " & text;
           elsif SourceLanguage = Java then
              text := "// " & text;
           elsif SourceLanguage = Ada_Language then
              text := "-- " & text;
           elsif SourceLanguage = Bush then
              text := "-- " & text;
           elsif SourceLanguage = Perl then
              text := "# " & text;
           elsif SourceLanguage = PHP then
              text := "// " & text;
           elsif SourceLanguage = HTML then
              text := "<-- " & text & " -->";
           elsif SourceLanguage = Shell then
              text := "# " & text;
           else
             CautionAlert( "This file has no comment format" );
           end if;
           ReplaceLine( SourceBox, text );
       end loop;
     end if;
  end CommentOut;

-------------------------------------------------------------------------------
--  UPPERCASE BLOCK
--
-- Convert alphabetic characters in block to uppercase.
-------------------------------------------------------------------------------

  procedure UppercaseBlock is
    Mark1 : long_integer;
    Mark2 : Str255List.AListIndex;
    text  : str255;
    ch    : character;
  begin
    Mark1 := GetMark( SourceBox );
    Mark2 := GetCurrent( SourceBox );
    if Mark1 < 0 then
       Mark1 := Mark2;
    end if;
    if Mark1 > long_integer( Mark2 ) then
       Mark2 := Str255List.AListIndex( GetMark( SourceBox ) );
       Mark1 := long_integer( GetCurrent( SourceBox ) );
    end if;
    if Mark1 <= 0 then
       NoteAlert( "Nothing to uppercase" );
    else
       for i in Str255List.AListIndex'(Mark1)..Mark2 loop
           SetCursor( SourceBox, 1, i );
           CopyLine( SourceBox, text );
           for j in 1..length( text ) loop
               ch := element( text, j );
               if ch >= 'a' and ch <= 'z' then
                  ch := character'val( character'pos( ch ) - 32 );
                  replace_element( text, j, ch );
               end if;
           end loop;
           ReplaceLine( SourceBox, text );
       end loop;
    end if;
  end UppercaseBlock;


-------------------------------------------------------------------------------
--  LOWERCASE BLOCK
--
-- Convert alphabetic characters in block to lowercase.
-------------------------------------------------------------------------------
  procedure LowercaseBlock is
    Mark1 : long_integer;
    Mark2 : Str255List.AListIndex;
    text  : str255;
    ch    : character;
  begin
    Mark1 := GetMark( SourceBox );
    Mark2 := GetCurrent( SourceBox );
    if Mark1 < 0 then
       Mark1 := Mark2;
    end if;
    if Mark1 > long_integer( Mark2 ) then
       Mark2 := Str255List.AListIndex( GetMark( SourceBox ) );
       Mark1 := long_integer( GetCurrent( SourceBox ) );
    end if;
    if Mark1 <= 0 then
       NoteAlert( "Nothing to lowercase" );
    else
       for i in Str255List.AListIndex'(Mark1)..Mark2 loop
           SetCursor( SourceBox, 1, i );
           CopyLine( SourceBox, text );
           for j in 1..length( text ) loop
               ch := element( text, j );
               if ch >= 'A' and ch <= 'Z' then
                  ch := character'val( character'pos( ch ) + 32 );
                  replace_element( text, j, ch );
               end if;
           end loop;
           ReplaceLine( SourceBox, text );
       end loop;
    end if;
  end LowercaseBlock;


-------------------------------------------------------------------------------
--  ABOUT PROGRAM
--
-- ? in main menu
--
-- Display the about program window.  Wait for an input event and close it.                --
-------------------------------------------------------------------------------

procedure AboutProgram is
  -- show the about program window
  tiaversion : string := "1.2";
  ch : character := ASCII.NUL;
  TempStr : str255;
  TheSig  : str255;
begin
  OpenWindow( To255( "About TIA" ), 5, 1, 70, 24, Status, false );
  MoveToGlobal( 6, 2 );
  SetTextStyle( Title );
  SetPenColour( White );
  Draw( "Tiny IDE for Ada/Anything (TIA) " & tiaversion );
  MoveToGlobal( 6, 3 );
  SetPenColour( Red );
  Draw( "Tiny IDE for Ada/Anything (TIA) " & tiaversion );
  MoveToGlobal( 6, 4 );
  SetTextStyle( Normal );
  Draw( "Tiny IDE for Ada/Anything (TIA) " & tiaversion );

  SetTextStyle( Normal );
  SetPenColour( White );
  MoveToGlobal( 6, 6 );
  Draw( "This is a GPL licenced program--see COPYING file" );
  MoveToGlobal( 6, 8 );
  Draw( "Written by Ken O. Burtch" );
  MoveToGlobal( 6, 9 );
  Draw( "Copyright (c) 1999-2007 Ken O. Burtch and FSF." );
  MoveToGlobal( 6, 10 );
  Draw( "Read accompanying documentation for more information" );
  MoveToGlobal( 6, 11 );
  Draw( "or visit http://www.pegasoft.ca/tia.html" );

  -- Platform Signature has system information in it
  -- We'll take it from there.

  MoveToGlobal( 6, 13 );
  TheSig := PlatformSig;
  TempStr := To255( Slice( TheSig, 1, Index( TheSig, "^" )-1 ) );
  Delete( TheSig, 1, Index( TheSig, "^" ) );
  Draw( "     O/S: " & TempStr );
  MoveToGlobal( 6, 14 );
  TempStr := To255( Slice( TheSig, 2, Index( TheSig, "^" )-1 ) );
  Draw( "Compiler: " & TempStr );

  MoveToGlobal( 6, 16 );
  Draw( "Edit Keys: ctrl-6 Mark             ctrl-n Next Page" );
  MoveToGlobal( 6, 17 );
  Draw( "           ctrl-] Char Search      ctrl-p Last Page" );
  MoveToGlobal( 6, 18 );
  Draw( "           ctrl-a Macro            ctrl-v Paste" );
  MoveToGlobal( 6, 19 );
  Draw( "           ctrl-b Copy             ctrl-x Cut" );
  MoveToGlobal( 6, 20 );
  Draw( "           ctrl-e Doc End          ctrl-y Doc Start" );

  SetPenColour( White );
  MoveToGlobal( 6, 23 );
  Draw( "Press any key to continue" );
  GetKey( ch );
  CloseWindow;
end AboutProgram;


-------------------------------------------------------------------------------
--  BUILD PROJECT
--
-- Proj menu/build
--
-- This is the big one.  Build (or rebuild) a project and run.  Set Profiling
-- to true if the user selected gprof profiling.  The project is built by
-- creating and running a shell script containing building commands.  Anything
-- written to standard output is shown in the status window.
-----------------------------------------------------------------------

  procedure BuildProject( Profiling : boolean := false ) is
    CompileLine : Str255;             -- gnatmake command
    LinkLine    : Str255;             -- gnatlink command
    ShellLine   : Str255;             -- shell cmd to build project
    ErrFile     : Str255;             -- file with compiling errors
    LinkErrFile : Str255;             -- file with linking errors
    ScriptFile  : Str255;             -- file containing our build script
    Script      : Str255List.List;    -- our script
    LinkErrs    : Str255List.List;    -- link errors (loaded from file)
    BuildTherm  : aliased AThermometer; -- progress thermometer
    BuildMsg    : aliased AStaticLine;-- script messages in window
    PipeLine    : Str255;             -- 
    WindowTitle : Str255;             -- the title of status window
    ProjectName : Str255;             -- name to appear in build window
    TempStr     : Str255;
    StartTime   : ATimeStamp;         -- time of build start
    BuildCount  : long_integer := 0;  -- no of lines of output for build
  begin

    -- make sure the project has a name

    if (length( Proj_Main ) = 0) and (Proj_Builder /= 2 and Proj_Builder /= 3) then
       CautionAlert( "Need a main program in project params to build" );
       return;
    end if;

    -- Save source file but don't start a background update.
    -- If there is an update, display a message to the programmer
    -- and check periodically to see if the update is finished.

    SaveSource( DoBackgroundUpdate => false );
    if IsBackgroundUpdate then
       SetInfoText( "Waiting for background update to finish..." );
       while IsBackgroundUpdate loop
           Wait( 1.0 );
       end loop;
    end if;
    SetInfoText( "" );

    MakeTempFileName( ScriptFile );              -- create tmp files
    ErrFile := ScriptFile & "_ce";               -- for build script
    LinkErrFile := ScriptFile & "_be";           -- and error results

    -- Begin the script to build the project

    Str255List.Queue( Script, To255( "#!/bin/sh" ) );
    Str255List.Queue( Script, To255( "#automatically created by TIA" ) );
    Str255List.Queue( Script, To255( "echo" ) );
    Str255List.Queue( Script, To255( "echo building project..." ) );
  
    -- Alternate builders to gnatmake.

    -- Are we root?  Besides being a stupid way to develop,
    -- root runs gnat at a high priority and can lock up your system.
    -- If we are root, try a nice gnatmake to reduce system load.
   
    if getuid = 0 then                  -- root (or root-ish, at least)?
       CompileLine := To255( "nice " ); -- reduce priority
    else                                -- else
       CompileLine := NullStr255;       -- default priority
    end if;

    if Proj_Builder = 2 then                     -- using make?
       if Proj_Debug = 1 then                    -- release debugging?
          CompileLine := CompileLine & "make release";-- "make release"
       elsif Proj_Debug = 2 then                 -- alpha/beta debugging?
          CompileLine := CompileLine & "make beta";   -- "make beta"
       else                                      -- prerelease debugging?
          CompileLine := CompileLine & "make";        -- "make"
       end if;
       CompileLine := CompileLine & " 2> " & ErrFile;
       Str255List.Queue( Script, CompileLine );
       goto run_it;                              -- go and do it
    elsif Proj_Builder = 3 then                  -- cook?
       CompileLine := CompileLine & "cook";           -- "cook" command
       CompileLine := CompileLine & " 2> " & ErrFile;
       Str255List.Queue( Script, CompileLine );
       goto run_it;                              -- go and do it
    end if;

    -- Down to <<run_it>>, this is for gnatmake/jgnatmake

    -- Create gnatmake command
    --
    -- These are the basic gnatmake switches:
    --
    -- c = don't link and bind because we'll do that separately
    -- i = save files in the same directory where you found source
    -- q = quiet - don't list units as you compile them

    if Proj_Builder = 1 then
       CompileLine := CompileLine & "gnatmake -c -i -q ";
    else
       CompileLine := CompileLine & "jgnatmake -c -i -q ";
    end if;
 
    -- If needs to be rebuilt from scratch, use -f switch, too

    if NeedsFullRecompile or Profiling then                -- need to rebuild?
       CompileLine := CompileLine & "-f ";                 -- force it
    end if;

    -- gnatmake optimization switches
    --
    -- Ox = standard gcc optimization settings
    --   O1 = basic + inlining inside packages (when specified)
    --   O2 = maximum optimization + inlining inside packages (when specified)
    --   O3 = O2 & inlining inside packages (automatic)
    -- ffloat-store = causes greater floating-point accuracy
    -- ffast-math = assume well-behaved math libraries
    -- gnatn = inline between packages (when specified)
    -- gnatN = inline between packages (automatic)

    if Proj_Builder = 1 then                               -- gnatmake?
       if Proj_Opt = 1 then                                -- no optimize?
          null;                                            -- nothing special
       elsif Proj_Opt = 2 then                             -- basic?
          CompileLine := CompileLine & "-O -ffloat-store ";
       elsif Proj_Opt = 3 then                             -- space?
          CompileLine := CompileLine & "-O2 -ffloat-store -gnatn ";
       else                                                -- time?
          CompileLine := CompileLine & "-O3 -ffast-math -gnatn ";
       end if;
    else                                                  -- jgnat
       if Proj_Opt > 1 then                               -- and optmize?
          CompileLine := CompileLine & "-O ";             -- only -O allowed
       end if;
    end if;
   
    -- gnatmake CPU optimizations
    --
    -- egcs may use different options, not applicable to JGNAT
    --
    -- mno-486 = Intel 386
    -- m486 = Intel 486
    -- malign-loops/jumps/etc = recommended for Pentiums GCC FAQ

    if Proj_Builder = 1 then                               -- gnatmake?
       if Proj_CPU = 1 then                                -- and 386?
          CompileLine := CompileLine & "-mtune=i386 ";     -- use this
       elsif Proj_CPU = 2 then                             -- or 486?
          CompileLine := CompileLine & "-mtune=i486 ";     -- use this
       elsif Proj_CPU = 5 then
          CompileLine := CompileLine & "-mtune=athlon ";
       elsif Proj_CPU = 6 then
          CompileLine := CompileLine & "-mtune=athlon64 ";
       elsif Proj_CPU = 3 then                             -- or Pentium?
          TempStr := To255( Slice( PlatformSig, 2, Index( PlatformSig, "^" )-1 ) );
          if index( TempStr, "3." ) > 0 or index( TempStr,
             "4." ) > 0 then                               -- GNAT 3.x or 4.x?
             CompileLine := CompileLine & "-m486 -malign-loops=2 -malign-jumps=2"
                & " -malign-functions=2 -fno-strength-reduce ";
          else                                            -- >= GNAT 5.0
             CompileLine := CompileLine & "-mcpu=i586 -march=i586 ";
          end if;
       else                                               -- something else?
          null;                                           -- nothing special
       end if;
    end if;

    -- gnatmake debugging
    --
    -- g = gdb support
    -- gnata = enable asserts and debug pragmas
    -- gnatE = elaboration checks
    -- gnatf = more error details??
    -- gnato = enable math overflow checks
    -- gnatp = disable all non-essential exception causing checks
    -- gnatwu = warnings on uninitialized/used things
    -- fomit-frame-pointer = faster but disables some 3rd party debugging
    --   utilities
    -- fstack-check = ACT says use this to detect stack overflows
    -- funwind-tables = required by gnat symbolic traceback packages
    -- Wunitiailized = ACT says use this to detect unitialized variables

    if Proj_Debug = 1 then                                 -- release?
       if Proj_Builder = 1 then                            -- gnatmake?
          CompileLine := CompileLine & "-gnatp -gnatf -fomit-frame-pointer -gnatwu ";
          if Proj_Opt > 1 then                             -- optimizing?
             CompileLine := CompileLine & "-Wuninitialized "; -- check this
          end if;                                          -- (needs opt)
       else                                                  -- jgnat?
          CompileLine := CompileLine & "-gnatp -gnatf ";      -- these OK
          -- omit-frame-pointer not applicable in JGNAT
       end if;
    elsif Proj_Debug = 2 then                              -- alpha/beta?
       CompileLine := CompileLine & "-gnata -gnatf -gnatwu "; -- asserts/info/etc.
       if Proj_Opt > 1 and Proj_Builder = 1 then           -- gnatm + opt?
          CompileLine := CompileLine & "-Wuninitialized -fstack-check ";
                                                           -- check this
       end if;                                             -- (needs opt)
    elsif Proj_Debug = 3 then                              -- prerelease?
       CompileLine := CompileLine & "-g -gnata -gnato -gnatE -gnatf -fstack-check -funwind-tables ";
    end if;                                                -- just about all

    -- gnat project type specific switches
    --
    -- fPIC - link with Position Independent Code
    -- shared - link into a shared library

    if Proj_Builder = 1 then                              -- gnatmake?
       if Proj_Kind = 4 then                              -- shared library?
          CompileLine := CompileLine & "-fPIC -shared ";  -- these, at least
       end if;
    end if;
    CompileLine := CompileLine & Proj_GCCOptions & " ";  -- user options
    CompileLine := CompileLine & Proj_Main & ".adb ";    -- and main pgm name
  
    -- gnat profiling switches
    --
    -- user wants to profile the program? gnatmake needs -cargs -pg.
    -- pg - include gprof profiling support
 
    if Profiling then
       CompileLine := CompileLine & "-cargs -pg ";
    end if;

    -- shell commands to run gnatmake and quit if errors

    Str255List.Queue( Script, "echo '" & CompileLine & "'" );
    CompileLine := CompileLine & "2> " & ErrFile;
    Str255List.Queue( Script, CompileLine );
    Str255List.Queue( Script, To255( "if [ $? -ne 0 ] ; then" ) );
    Str255List.Queue( Script, To255( "   exit 1" ) );
    Str255List.Queue( Script, To255( "fi;" ) );

    -- gnatbind (if application)
    --
    -- E = support for gnat symbolic traceback packages
    -- f = full elaboration rules--be strict.
    -- x = don't link

    if Proj_Kind = 1 then
       Str255List.Queue( Script, To255( "echo binding project..." ) );
       if Proj_Builder = 1 then
          if Proj_Debug = 3 then
             Str255List.Queue( Script, "gnatbind -xfE " &
                Proj_GCCOptions & " " & Proj_Main  & ".ali 2> " & LinkErrFile );
          else
             Str255List.Queue( Script, "gnatbind -xf " &
                Proj_GCCOptions & " " & Proj_Main  & ".ali 2> " & LinkErrFile );
          end if;
       else
          Str255List.Queue( Script, "jgnatbind -xf " &
             Proj_GCCOptions & " " & Proj_Main  & ".ali 2> " & LinkErrFile );
       end if;
       Str255List.Queue( Script, To255( "if [ $? -ne 0 ] ; then" ) );
       Str255List.Queue( Script, To255( "   exit 2" ) );
       Str255List.Queue( Script, To255( "fi;" ) );
  
       -- link (if application)
       --
       -- linking is not as critical, so we'll run it nice-ly

       if Proj_Builder = 1 then                       -- gnatmake?
          if Proj_Debug = 1 then                      -- release debugging?
             LinkLine := To255( "nice gnatlink -s " );-- discard symbol tbls
          else                                        -- else
             LinkLine := To255( "nice gnatlink " );   -- normal link
          end if;                                     -- and
          LinkLine := LinkLine & Proj_Main & ".ali " &-- include user options
            Proj_LinkOptions & " ";
       else                                           -- jgnat?
          LinkLine := "nice jgnatlink " & Proj_Main & ".ali " &
            Proj_LinkOptions & " ";
       end if;

       -- static linking?

       if Proj_Static then                            -- static box checked?
          LinkLine := LinkLine & " -static ";         -- link statically
       end if;

       -- profiling? include -pg when linking

       if Profiling then
          LinkLine := LinkLine & "-pg ";
       end if;

       LinkLine := LinkLine & " 2> " & LinkErrFile;
       Str255List.Queue( Script, To255( "echo linking project..." ) );
       Str255List.Queue( Script, LinkLine );
       Str255List.Queue( Script, To255( "if [ $? -ne 0 ] ; then" ) );
       Str255List.Queue( Script, To255( "   exit 3" ) );
       Str255List.Queue( Script, To255( "fi;" ) );
    end if;

   -- end of gnatmake/jgnatmake specific code

<<run_it>>

    -- save shell script we just wrote

    SaveList( ScriptFile, Script );
    if LastError /= TT_OK then
       SessionLog( "BuildProject: Error saving file", LastError );
       StopAlert( "Error saving file: # " & AnErrorCode'image(
          LastError ) );
    end if;

    -- use this command to run the script

    ShellLine := "sh " & ScriptFile & " ; echo done";

    -- Open the status window

    ProjectName := To255( "Project" );
    if length( Proj_Main ) > 0 then
       ProjectName := Proj_Main;
    end if;
    if Proj_Builder = 2 then
       WindowTitle := "Making " & ProjectName;
    elsif Proj_Builder = 3 then
       WindowTitle := "Cooking " & ProjectName;
    elsif NeedsFullRecompile or Profiling then
       WindowTitle := "Completely Rebuilding " & ProjectName;
    else
       WindowTitle := "Building " & ProjectName;
    end if;
    OpenWindow( WindowTitle, 3, 3, DisplayInfo.H_Res-4, 9, normal );
    if LastSuccessfulBuildTime > 0 then
       Init( BuildTherm, 1, 2, 20, 2 );
       SetValue( BuildTherm, 0 );
       SetMax( BuildTherm, 100 );
       AddControl( BuildTherm'unchecked_access,
         IsGlobal => false );
    end if;
    Init( BuildMsg, 1, 4, DisplayInfo.H_Res-8, 4 ); -- buildmsg
    SetText( BuildMsg, "Starting to build..." );    -- is the text
    AddControl( BuildMsg'unchecked_access,          -- in the window
      IsGlobal => false );
    Pipe( ShellLine );                           -- start build subprocess
    DrawWindow;                                  -- display window
    StartTime := GetTimeStamp;
    loop                                         -- while script runs
      exit when PipeFinished;                    -- wait for next line
      NextPipeLine( PipeLine );                  -- of the script output
      SetText( BuildMsg, PipeLine );             -- put it in the window
      DrawWindow;                                -- update window
      BuildCount := BuildCount + 1;
      if LastSuccessfulBuildTime > 0 then
         declare
           BarValue1 : long_integer;
           BarValue2 : long_integer;
         begin
           -- Calculate the value for the progress bar
           -- If there's a very small number of output lines, don't use
           -- output lines.  Otherwise, take the % done by time and the %
           -- done by output.  Use the lower (conservative) value.
           BarValue1 := long_integer( GetTimeStamp - StartTime ) * 100 /
              LastSuccessfulBuildTime;
           if LastSuccessfulBuildCount > 0 and LastSuccessfulBuildCount > 20 then
              BarValue2 := (BuildCount * 100) / LastSuccessfulBuildCount;
              if BarValue2 < BarValue1 then
                   BarValue1 := BarValue2;
              end if;
           end if;
           SetValue( BuildTherm, BarValue1);
         end;
      end if;
    end loop;
    CloseWindow;                                 -- close window

    Erase( ScriptFile );                         -- delete our script
    ClearGnatErrors;                             -- discard old error list
    LoadList( ErrFile, GnatErrors );             -- get new error list
    NormalizeGnatErrors;
    Erase( ErrFile );                            -- delete error file
    if length( LinkErrFile ) > 0 then            -- separate link err file?
       LoadList( LinkErrFile, LinkErrs );        -- then load link errors
       Erase( LinkErrFile );                     -- and delete the file
    end if;
    Str255List.Clear( Script );                  -- discard script list
    if Str255List.Length( GnatErrors ) > 0 then  -- show errors (if any)
       ShowListInfo( "Build Errors", 0, 1, DisplayInfo.H_Res-2, 23, GnatErrors,
          longLines => wrap );
       goto done;
    elsif Str255List.Length( LinkErrs ) > 0 then -- or link errors (if any)
       ShowListInfo( "Bind and Link Errors", 0, 1, DisplayInfo.H_Res-2, 23, LinkErrs,
          longLines => wrap );
       goto done;
    else
       LastSuccessfulBuildTime := long_integer( GetTimeStamp - StartTime );
       LastSuccessfulBuildCount := BuildCount;
    end if;                                      -- no building errors?

    -- quiet updates? sync disks to ensure everything is saved

    if Opt_Quiet then
       Sync;
    end if;

    -- no errors? then if profiling, run program without prompting
    -- if no profiling, prompt to run.

    if Profiling then
       ShellOut( "./" & Proj_Main );
    else
       Proj_BuildCount := Proj_BuildCount + 1; -- stats
       Proj_BuildTime  := GetTimeStamp;
       Proj_BuildTimeStr := GetDate & " " & GetTime;
       if length( Proj_Main ) = 0 then
          NoteAlert(  "Project is ready." );
       elsif not NoAlert( "Ready.  Run " & ToString(Proj_Main) & "?", kind => success ) then
          ShellOut( "./" & Proj_Main );
       end if;
    end if;

    -- was project completely rebuilt? then record platform sig and
    -- clear flag.

    if NeedsFullRecompile then
       NeedsFullRecompile := false;
       Proj_PlatSig := PlatformSig; -- this is what was rebuilt on last
    end if;

<<done>>
    Str255List.Clear( LinkErrs );
  end BuildProject;


-------------------------------------------------------------------------------
--  PROFILE PROJECT
--
-- Proj menu/profile
--
-- Profile project using gprof and show the results.
-------------------------------------------------------------------------------

  procedure ProfileProject is
    Gmon : Str255 := To255( "gmon.out" );     -- gmon file path
    GprofOutput : str255;                     -- file to hold gprof output
    TempList : Str255List.List;               -- temp string list
  begin

    -- To profile the project, it must be completely rebuilt
    -- using the grof switches.  Ask user if they really want to
    -- do this.

    if NoAlert( "OK to completely rebuild project?", kind => Warning ) then
       return;
    end if;

    MakeTempFileName( GprofOutput );             -- tmp file for output
    BuildProject( Profiling => true );           -- rebuild project
    ShellOut( "./" & Proj_Main );                -- run it
    if IsFile( Gmon ) then                       -- profiling data?
       UNIX( "gprof " & Proj_Main & " > " & GprofOutput  );
       if IsFile( GprofOutput ) then             -- gprof summary?
          LoadList( GprofOutput, TempList );     -- load & display
          ShowListInfo( "Gprof Profile for " & ToString( Proj_Main ),
            0, 1, DisplayInfo.H_Res-2, 23, TempList );
          Str255List.Clear( TempList );          -- deallocate list
          Erase( GprofOutput);                   -- delete gprof summary
       else
          NoteAlert( "No output from gprof command" );
       end if;
       Erase( Gmon );                            -- delete profiling data
    else
       NoteAlert( "No profiling data from executable" );
    end if;

    -- Force rebuild to remove profiling data next time compiled

    NeedsFullRecompile := true;
  end ProfileProject;


-------------------------------------------------------------------------------
--  BACKUP PROJECT
--
-- Proj menu/backup now
--
-- Run backup command specified by user in the options window.  Also run
-- automatically every 24 hours by main program.
-------------------------------------------------------------------------------

  procedure BackupProject is
  begin
    Proj_BackupTime := GetTimeStamp;    -- record time and do it
    SetInfoText( To255( "24 hour project backup in progress..." ) );
    DrawWindow;
    if UNIX( Opt_Backup ) then
       SetInfoText( To255( "Project backed up." ) );
    else
       SetInfoText( To255( "There was an error backing up the project" ) );
    end if;
    -- Note: time is not saved until project is saved on shutdown
  end BackupProject;


-------------------------------------------------------------------------------
--  OPEN SOURCE
--
-- File menu/open source
--
-- Load a source file into the main window.  Handle the open dialog box.
-------------------------------------------------------------------------------

  procedure OpenSource is

    procedure BrowseOpenSource( NewFilename : out str255 ) is
      -- The open source browse dialog
      ProjectDir : str255;
      sof : ASelectOpenFileRec;
    begin
      ProjectDir := GetPath;
      sof.prompt := To255( "Open which source file?" );
      sof.direct := false;
      sof.suffix := NullStr255;
      SelectOpenFile( sof );
      if sof.replied then
         NewFilename := sof.path & "/" & sof.fname;
      else
         NewFilename := NullStr255;
      end if;
      -- sof may change path but we want to stay in project directory
      SetPath( ProjectDir );
    end BrowseOpenSource;

    TextLine     : aliased AnEditLine;      -- file name line
    NewButton    : aliased ASimpleButton;   -- new button
    OpenButton   : aliased ASimpleButton;   -- open button
    CancelButton : aliased ASimpleButton;   -- cancel button
    BrowseButton : aliased ASimpleButton;   -- browse button
    OneButton    : aliased ASimpleButton;   -- quick open one button
    TwoButton    : aliased ASimpleButton;   -- quick open two button
    ThreeButton  : aliased ASimpleButton;   -- quick open three button
    FourButton   : aliased ASimpleButton;   -- quick open four button
    FiveButton   : aliased ASimpleButton;   -- quick open five button
    NewFilename  : str255;

    DT : ADialogTaskRecord;

    procedure SwitchToNewFile is
    -- this was procedure SwitchToNewFile( path : str255 ) but
    -- gnat 3.10 was screwing up the parameter.
    begin
      SaveSource;                                -- save old source file
      if IsFile( NewFilename ) then              -- new file exists?
         SourcePath := NewFileName;              -- record source path
         Str255List.Clear( SourceText );         -- discard old source
         LoadSourceFile( SourcePath, SourceText ); -- load new source
         SetSourceLanguage( SourcePath );   -- determine the language
         SetKeywords( SourcePath );              -- determine hilighting
         SetList( SourceBox, SourceText );       -- put in window
         Str255List.Clear( SourceText );    -- no longer used
         SetCursor( SourceBox, 1, 1 );           -- reposition cursor to top
         SetThumb( SourceBar, 1 );               -- move to top of file
      else                                       -- otherwise no file
         StopAlert( ToString( NewFilename ) & " doesn't exist" );
      end if;
    end SwitchToNewFile;

    procedure SwitchToNewFile( sr : ASourceReference ) is
      -- Quick open a new file
      TempSave : ASourceReference;
      -- kludge: gnat 3.10 mangled sr during return from SaveSource call
    begin
      TempSave := sr;                            -- save this source ref
      SaveSource;                                -- save old source file
      if IsFile( TempSave.path ) then            -- source ref exists?
         Str255List.Clear( SourceText );         -- discard old source
         SourcePath := TempSave.path;            -- record source path
         LoadSourceFile( SourcePath, SourceText ); -- load new source
         SetSourceLanguage( SourcePath );   -- determine the language
         SetKeywords( SourcePath );              -- determine hilighting
         SetList( SourceBox, SourceText );       -- put in window
         Str255List.Clear( SourceText );    -- no longer used
         SetCursor( SourceBox, TempSave.Posn,    -- restore cursor
           TempSave.Line );                      -- to old position
         SetThumb( SourceBar, long_integer(      -- and set the scroll bar
           TempSave.Posn ) );                    -- accordingly
      else                                       -- otherwise no such file
         StopAlert( ToString( SourcePath ) & " doesn't exist" );
      end if;
    end SwitchToNewFile;

  begin

    OpenWindow( To255( "Open/New Source" ), 10, 6, DisplayInfo.H_Res-10, 19, Normal, true );

    Init( TextLine, 1, 2, DisplayInfo.H_Res-21, 2 );
    SetText( TextLine, NullStr255 );
    SetInfo( TextLine, To255( "Path of file to load" ) );
    AddControl( TextLine'unchecked_access, false );

    Init( OpenButton, 2, 4, 13, 4, 'o' );
    SetText( OpenButton, "Open" );
    SetInfo( OpenButton, To255( "Open file you named" ) );
    SetInstant( OpenButton );
    AddControl( OpenButton'unchecked_access, false );

    Init( CancelButton, 14, 4, 25, 4, 'l' );
    SetText( CancelButton, "Cancel" );
    SetInfo( CancelButton, To255( "Cancel" ) );
    SetInstant( CancelButton );
    AddControl( CancelButton'unchecked_access, false );

    Init( BrowseButton, 26, 4, 41, 4, 'b' );
    SetText( BrowseButton, "Browse..." );
    SetInfo( BrowseButton, To255( "Look for the file to open" ) );
    SetInstant( BrowseButton );
    AddControl( BrowseButton'unchecked_access, false );

    Init( NewButton, 41, 4, 52, 4, 'n' );
    SetText( NewButton, "New" );
    SetInfo( NewButton, To255( "Start a new file" ) );
    SetInstant( NewButton );
    AddControl( NewButton'unchecked_access, false );

    Init( OneButton, 1, 6, DisplayInfo.H_Res-21, 6, '1' );
    SetText( OneButton, "1 " & QuickOpen1.path );
    SetInfo( OneButton, To255( "Open this file" ) );
    SetInstant( OneButton );
    if length( QuickOpen1.path ) = 0 then
       SetStatus( OneButton, off );
       SetText( OneButton, "1 - " );
    end if;
    AddControl( OneButton'unchecked_access, false );

    Init( TwoButton, 1, 7, DisplayInfo.H_Res-21, 7, '2' );
    SetText( TwoButton, "2 " & QuickOpen2.path );
    SetInfo( TwoButton, To255( "Open this file" ) );
    SetInstant( TwoButton );
    if length( QuickOpen2.path ) = 0 then
       SetStatus( TwoButton, off );
       SetText( TwoButton, "2 - " );
    end if;
    AddControl( TwoButton'unchecked_access, false );

    Init( ThreeButton, 1, 8, DisplayInfo.H_Res-21, 8, '3' );
    SetText( ThreeButton, "3 " & QuickOpen3.path );
    SetInfo( ThreeButton, To255( "Open this file" ) );
    SetInstant( ThreeButton );
    if length( QuickOpen3.path ) = 0 then
       SetText( ThreeButton, "3 - " );
       SetStatus( ThreeButton, off );
    end if;
    AddControl( ThreeButton'unchecked_access, false );

    Init( FourButton, 1, 9, DisplayInfo.H_Res-21, 9, '4' );
    SetText( FourButton, "4 " & QuickOpen4.path );
    SetInfo( FourButton, To255( "Open this file" ) );
    SetInstant( FourButton );
    if length( QuickOpen4.path ) = 0 then
       SetText( FourButton, "4 - " );
       SetStatus( FourButton, off );
    end if;
    AddControl( FourButton'unchecked_access, false );

    Init( FiveButton, 1, 10, DisplayInfo.H_Res-21, 10, '5' );
    SetText( FiveButton, "5 " & QuickOpen5.path );
    SetInfo( FiveButton, To255( "Open this file" ) );
    SetInstant( FiveButton );
    if length( QuickOpen5.path ) = 0 then
       SetText( FiveButton, "5 - " );
       SetStatus( FiveButton, off );
    end if;
    AddControl( FiveButton'unchecked_access, false );

    loop
      DoDialog( DT );
      case DT.control is
      when 2 => NewFilename := GetText( TextLine );
                if Index( NewFilename, "." ) = 0 then
                   NewFilename := NewFilename & ".adb";
                end if;
                SwitchToNewFile;
                exit;
      when 3 => exit; -- Cancel
      when 4 => BrowseOpenSource( NewFilename );
                if length( NewFilename ) > 0 then
                   SwitchToNewFile;
                end if;
                exit;
      when 5 => SaveSource;
  		NewSource;
                SetList( SourceBox, SourceText );
                Str255List.Clear( SourceText );
                SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
                SetKeywords( SourcePath );
                Touch( SourceBox );
                exit;
      when 6 => SwitchToNewFile( QuickOpen1 );
                exit;
      when 7 => SwitchToNewFile( QuickOpen2 );
                exit;
      when 8 => SwitchToNewFile( QuickOpen3 );
                exit;
      when 9 => SwitchToNewFile( QuickOpen4 );
                exit;
      when 10 => SwitchToNewFile( QuickOpen5 );
                exit;
      when others=> null;
      end case;
    end loop;
    CloseWindow;
    SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
    UpdateSourceDisplay;
    DrawWindow( Frame );
  end OpenSource;


-------------------------------------------------------------------------------
--  REVERT SOURCE
--
-- File menu/revert
--
-- Discard all recent changes and reload the current source file.                        --
-------------------------------------------------------------------------------

  procedure RevertSource is
  begin
    if IsFile( SourcePath ) then
       Str255List.Clear( SourceText );
       LoadSourceFile( SourcePath, SourceText );
       SetList( SourceBox, SourceText );
       Str255List.Clear( SourceText );    -- no longer used
       SetThumb( SourceBar, 1 );
       ClearTouch( SourceBox ); -- should probably be done by SetList
    else
       StopAlert( ToString( SourcePath ) & " doesn't exist" );
    end if;
    SetInfoText( "Reverted to last saved " & SourcePath );
    UpdateSourceDisplay;
  end RevertSource;


-------------------------------------------------------------------------------
--  DELETE SOURCE
--
-- File menu/delete
--
-- Delete a file and remove it from CVS if necessary.                                  --
-------------------------------------------------------------------------------

  procedure DeleteFile is

    procedure BrowseDeleteFile( DeletePath : out str255 ) is
      -- The delete file browse dialog
      ProjectDir : str255;
      sof        : ASelectOpenFileRec;
    begin
      ProjectDir := GetPath;
      sof.prompt := To255( "Open file to delete." );
      sof.direct := false;
      sof.suffix := NullStr255;
      SelectOpenFile( sof );
      if sof.replied then
         DeletePath := sof.path & "/" & sof.fname;
      else
         DeletePath := NullStr255;
      end if;
      -- sof may change path but we want to stay in project directory
      SetPath( ProjectDir );
    end BrowseDeleteFile;

    DeletePath : Str255;

  begin
    BrowseDeleteFile( DeletePath );       -- prompt for the file to delete
    if length( DeletePath ) = 0 then      -- nothing? then we're done
       return;
    end if;
    if IsFile( DeletePath ) then          -- verify the file exists
       Erase( DeletePath );               -- erase the file
       if LastError /= 0 then             -- failed? report error
          StopAlert( "Unable to delete file" );
          return;
       end if;
       if HasCVS and Opt_CVS and IsCVSProject then -- using CVS?
          CVSRemove( DeletePath );        -- remove from project
       end if;
       if HasSVN and Opt_SVN and IsSVNProject then -- using SVN?
          CVSRemove( DeletePath );        -- remove from project
       end if;
       if DeletePath = SourcePath then    -- is it current file?
          ClearTouch( SourceBox );        -- discard the source file
          NewSource;                      -- and show a new one
          SetKeywords( SourcePath );
          Touch( SourceBox );
       end if;
    else
       StopAlert( ToString( DeletePath ) & " doesn't exist" );
    end if;
    SetInfoText( "Deleted " & DeletePath );
  end DeleteFile;


-------------------------------------------------------------------------------
--  PRINT SOURCE
--
-- File menu/print
--
-- Print the current source file to the default printer.
-------------------------------------------------------------------------------

  procedure PrintSource is
    SourceHeader : Str255List.List;
  begin
    SourceHeader := GetList( SourceBox );
    PrintList( SourceHeader );
    SetInfoText( "Printing spooled." );
  end PrintSource;


-------------------------------------------------------------------------------
--  GOTO NEXT ERROR
--
-- Find menu/next error
--
-- Take the next error in the error list.  Move to that line and character
-- position and show the error message in the window's info line.
-------------------------------------------------------------------------------

  procedure GotoNextError is
    PrefixStr  : Str255;
    TempStr    : Str255;
    File2Load  : Str255;
    ColonCount : integer := 0;
    WillBeLastColon : integer := 1;
    LastColon  : integer := 1;
    LineNum    : integer := 0;     -- line number of error
    LinePos    : integer := 0;     -- line character position of error
    WasLoaded  : boolean := false; -- true if source file is available
    button     : AControlNumber;
  begin

    -- if list is empty, there were no errors

    if Str255List.Length( GnatErrors ) = 0 then
       NoteAlert( "There were no errors" );
       return;
    end if;

    -- beyond end of error list?  start over again

    if NextGnatError > Str255List.Length( GnatErrors ) then
       NextGnatError := 1;
    end if;

    -- get the error message.  create the " m/n:" prefix

    Str255List.Find( GnatErrors, NextGnatError, TempStr );
    PrefixStr := (long_integer'image( NextGnatError ) & "/" ) &
               To255( long_integer'image( Str255List.Length( GnatErrors ) ) &
               ": " );

    -- break the error message into file, line, position and message
    -- each field is delimited by a colon (:).  When looping, don't
    -- check for a colon at the end of the line.
    -- (where possible: other languages may not have the position)

    for i in 1..Length( TempStr )-1 loop         -- in the message string
        if Element( TempStr, i ) = ':' then      -- is this a colon?
           ColonCount := ColonCount + 1;         -- this is the nth colon
           LastColon := WillBeLastColon;         -- remember old position
           WillBeLastColon := i;
           if ColonCount = 1 and i > 1 then      -- first field is filename
              -- GCC C errors include a "In function 'name'" message before
              -- the actual error message.  We don't need that since we're
              -- moving directly to the error, so skip these error lines.
              if SourceLanguage = C or SourceLanguage = CPP then
                 if Index( TempStr, " In function " ) > 0 then
                    NextGnatError := NextGnatError + 1;
		    pragma warnings( off ); -- no danger of infinite recursion
                    GotoNextError;
		    pragma warnings( on );
                    return;
                 end if;
              end if;
              File2Load := To255( Slice( TempStr, 1, i-1 ) );
              if not IsFile( File2Load ) then    -- linker may return tempfile
                 File2Load := NullStr255;        -- make sure file exists
              end if;
           elsif ColonCount = 2 then             -- second field is line
              begin                              -- make sure it's really
                LineNum := ToInteger( Slice( TempStr, LastColon + 1, i - 1 ) ); 
              exception when others =>           -- a numeric value
                LineNum := 0;
              end;
              if LineNum = 0 then                -- not numeric?
                 exit;
               end if;
           elsif ColonCount = 3 then             -- third field is position
              begin                              -- make sure it's really
                LinePos := ToInteger( Slice( TempStr, LastColon + 1, i - 1 ) ); 
              exception when others =>           -- a numeric value
                LinePos := 0;
              end;
              exit;
           end if;
        end if;
    end loop;

    -- load the source file (if necessary)

    if length( File2Load ) = 0 then              -- nothing to load?
       WasLoaded := false;
    elsif SourcePath = File2Load then            -- source file unchanged?
       WasLoaded := true;
    elsif isLoadException( SourcePath, File2Load ) then -- already know not to load it?
       WasLoaded := true;
    else
       button := YesCancelAlert( "Load new file " & Basename(File2Load) & "? No, stay in current?", status );
       if button = 1 then                        -- load new source file
          SaveSource;
          SourcePath := File2Load;
          SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
          Str255List.Clear( SourceText );
          LoadSourceFile( SourcePath, SourceText );
          SetSourceLanguage( SourcePath );   -- determine the language
          SetKeywords( SourcePath );
          SetList( SourceBox, SourceText );
          Str255List.Clear( SourceText );
          WasLoaded := true;
       elsif button = 2 then                     -- use current file
          AddLoadException( SourcePath, File2Load ); -- don't ask again
          WasLoaded := true;
       else                                      -- just show error and
          WasLoaded := false;                    -- don't try to find it
       end if;
    end if;

    -- only reposition the cursor if the file loaded

    if WasLoaded then
       if LineNum > 0 then                       -- line number known?
          MoveCursor( SourceBox, -256,           -- reposition to
             long_integer( LineNum )             -- the start of
             - GetCurrent( SourceBox ) );        -- that line
       end if;
       if LinePos > 0 then                       -- line position known?
          MoveCursor( SourceBox, LinePos-1, 0 ); -- move cursor
       end if;                                   -- to that character
    end if;

    -- display remainder of string as the error message

    SetInfoText( PrefixStr &
       Slice( TempStr, WillBeLastColon+1, length( TempStr ) ) );
    NextGnatError := NextGnatError + 1;
    UpdateSourceDisplay;
  end GotoNextError;


-------------------------------------------------------------------------------
-- DROP-DOWN MENUS
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--  FILE MENU
-------------------------------------------------------------------------------

procedure FileMenu is

  NewButton    : aliased ASimpleButton;
  OpenButton   : aliased ASimpleButton;
  SaveButton   : aliased ASimpleButton;
  SaveAsButton : aliased ASimpleButton;
  RevertButton : aliased ASimpleButton;
  --DiffButton   : aliased ASimpleButton;
  DiffSaveButton : aliased ASimpleButton;
  DiffCommitButton  : aliased ASimpleButton;
  LogButton    : aliased ASimpleButton;
  PrintButton  : aliased ASimpleButton;
  DeleteButton : aliased ASimpleButton;
  StubButton   : aliased ASimpleButton;
  CheckButton  : aliased ASimpleButton;
  XrefButton   : aliased ASimpleButton;
  QuitButton   : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;

  HBar1        : aliased AnHorizontalSep;
  HBar2        : aliased AnHorizontalSep;
  HBar3        : aliased AnHorizontalSep;

  DT : ADialogTaskRecord;

begin
  OpenWindow( To255( "File Menu" ), 5, DisplayInfo.V_Res-22, 28,
    DisplayInfo.V_Res-3, Normal );

  Init( NewButton, 1, 1, 22, 1, 'n' );
  SetInstant( NewButton );
  SetText( NewButton, "New Source" );
  AddControl( NewButton'unchecked_access, false );

  Init( OpenButton, 1, 2, 22, 2, 'o' );
  SetInstant( OpenButton );
  SetText( OpenButton, "Open Source..." );
  AddControl( OpenButton'unchecked_access, false );

  Init( SaveButton, 1, 4, 22, 4, 's' );
  SetInstant( SaveButton );
  SetText( SaveButton, "Save" );
  AddControl( SaveButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( SaveButton, Off );
  end if;

  Init( SaveAsButton, 1, 5, 22, 5, '!' );
  SetInstant( SaveAsButton );
  SetText( SaveAsButton, "Save As ... (!)" );
  AddControl( SaveAsButton'unchecked_access, false );

  Init( RevertButton, 1, 6, 22, 6, '*' );
  SetInstant( RevertButton );
  SetText( RevertButton, "Revert (*)" );
  AddControl( RevertButton'unchecked_access, false );

  Init( PrintButton, 1, 7, 22, 7, '$' );
  SetInstant( PrintButton );
  SetText( PrintButton, "Print ($)" );
  AddControl( PrintButton'unchecked_access, false );

  Init( DeleteButton, 1, 8, 22, 8, 'd' );
  SetInstant( DeleteButton );
  SetText( DeleteButton, "Delete..." );
  AddControl( DeleteButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( StubButton, Off );
  end if;

  Init( DiffSaveButton, 1, 10, 22, 10, 'f' );
  SetInstant( DiffSaveButton );
  SetText( DiffSaveButton, "Diff Last Save..." );
  AddControl( DiffSaveButton'unchecked_access, false );

  Init( DiffCommitButton, 1, 11, 22, 11, 'i' );
  SetInstant( DiffCommitButton );
  SetText( DiffCommitButton, "Diff Shared..." );
  AddControl( DiffCommitButton'unchecked_access, false );

  Init( LogButton, 1, 12, 22, 12, 'h' );
  SetInstant( LogButton );
  SetText( LogButton, "Change Log" );
  AddControl( LogButton'unchecked_access, false );

  Init( StubButton, 1, 13, 22, 13, 'b' );
  SetInstant( StubButton );
  SetText( StubButton, "Stub" );
  AddControl( StubButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( StubButton, Off );
  end if;

  Init( CheckButton, 1, 14, 22, 14, 'k' );
  SetInstant( CheckButton );
  SetText( CheckButton, "Check" );
  AddControl( CheckButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( CheckButton, Off );
  end if;

  Init( XrefButton, 1, 15, 22, 15, 'x' );
  SetInstant( XrefButton );
  SetText( XrefButton, "Xref" );
  AddControl( XrefButton'unchecked_access, false );

  Init( QuitButton, 1, 17, 22, 17, 'q' );
  SetInstant( QuitButton );
  SetText( QuitButton, "Quit" );
  AddControl( QuitButton'unchecked_access, false );

  Init( CancelButton, 1, 18, 22, 18, 'l' );
  SetInstant( CancelButton );
  SetText( CancelButton, "Cancel" );
  AddControl( CancelButton'unchecked_access, false );

  Init( HBar1, 1, 3, 22, 3 );
  AddControl( HBar1'unchecked_access, false );

  Init( HBar2, 1, 9, 22, 9 );
  AddControl( HBar2'unchecked_access, false );

  Init( HBar3, 1, 16, 22, 16 );
  AddControl( HBar3'unchecked_access, false );

  -- Disable Menu Items

  if not (HasCVS and Opt_CVS and IsCVSProject) and
     not (HasSVN and Opt_SVN and IsSVNProject) then
     SetStatus( DiffSaveButton, Off );
     SetStatus( DiffCommitButton, Off );
     SetStatus( LogButton, Off );
  end if;

  if SourceLanguage = UnknownLanguage then
     SetStatus( CheckButton, Off );
  end if;
  if SourceLanguage /= Ada_Language then
     SetStatus( XrefButton, Off );
     SetStatus( StubButton, Off );
  end if;

  DoDialog( DT, HearInCB => MenuInputCB );
  CloseWindow;
  case DT.Control is
  when 1 => NewSource;
            SetList( SourceBox, SourceText );
            Str255List.Clear( SourceText );
            SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
            SetKeywords( SourcePath );
            Touch( SourceBox );
  when 2 => OpenSource;
  when 3 => SaveSource;
            SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
  when 4 => SaveSource( ForcePrompt => true );
            SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
  when 5 => RevertSource;
  when 6 => PrintSource;
  when 7 => DeleteFile;
  when 8 => DiffSource;
  when 9 => if Opt_CVS then
               CVSDiff;
            else
               SVNDiff;
            end if;
  when 10 => if Opt_CVS then
               CVSLog;
             else
               SVNLog;
             end if;
  when 11 => StubSource;
  when 12 => CheckSource;
  when 13 => XrefSource;
  when 14 => declare
              Response : AControlNumber;
            begin
              if length( SourcePath ) = 0 then
                 SaveSource( DoBackgroundUpdate => false,
                             ForcePrompt => true );
                 Done := true;
              elsif WasTouched( SourceBox ) then
                 Response := YesCancelAlert( "Save changes to "
                   & ToString( GetWindowTitleFromPath( SourcePath ) )
                   & "?", status );
                 if Response = 1 then
                    SaveSource( DoBackgroundUpdate => false,
                                ForcePrompt => false );
                    Done := true;
                 elsif Response = 2 then
                    Done := true;
                 end if;
              else
                  Done := true;
              end if;
            exception when others =>
              StopAlert( "An unexpected exception occurred while quitting" );
            end;
  when others => SetInfoText( "" );
  end case;
end FileMenu;


-------------------------------------------------------------------------------
--  EDIT MENU
-------------------------------------------------------------------------------

procedure EditMenu is

  CopyButton   : aliased ASimpleButton;
  CutButton    : aliased ASimpleButton;
  ClearButton  : aliased ASimpleButton;
  PasteButton  : aliased ASimpleButton;
  HBar         : aliased AnHorizontalSep;
  MarkButton   : aliased ASimpleButton;
  ClearMarkButton : aliased ASimpleButton;
  HBar2        : aliased AnHorizontalSep;
  GotoButton   : aliased ASimpleButton;
  AppendButton : aliased ASimpleButton;
  HBar3        : aliased AnHorizontalSep;
  CommentButton: aliased ASimpleButton;
  UppercaseButton: aliased ASimpleButton;
  LowercaseButton: aliased ASimpleButton;
  HBar4        : aliased AnHorizontalSep;
  CancelButton : aliased ASimpleButton;

  DT : ADialogTaskRecord;

  s : string(1..1);

begin
  OpenWindow( To255( "Edit Menu" ), 15, DisplayInfo.V_Res-20, 48,
    DisplayInfo.V_Res-3, Normal );

  Init( CopyButton, 1, 1, 32, 1, 'c' );
  SetText( CopyButton, "Copy (Control-B)" );
  SetInstant( CopyButton );
  AddControl( CopyButton'unchecked_access, false );

  Init( CutButton, 1, 2, 32, 2, 'u' );
  SetText( CutButton, "Cut (Control-B + Control-X)" );
  SetInstant( CutButton );
  AddControl( CutButton'unchecked_access, false );

  Init( ClearButton, 1, 3, 32, 3, 'x' );
  SetText( ClearButton, "Clear (Control-X)" );
  SetInstant( ClearButton );
  AddControl( ClearButton'unchecked_access, false );
  SetStatus( ClearButton, Off );

  Init( PasteButton, 1, 4, 32, 4, 'p' );
  SetText( PasteButton, "Paste (Control-V)" );
  SetInstant( PasteButton );
  AddControl( PasteButton'unchecked_access, false );

  Init( HBar, 1, 5, 32, 5 );
  AddControl( HBar'unchecked_access, false );

  Init( MarkButton, 1, 6, 32, 6, 'm' );
  SetText( MarkButton, "Mark (Control-6)" );
  SetInstant( MarkButton );
  AddControl( MarkButton'unchecked_access, false );

  Init( ClearMarkButton, 1, 7, 32, 7, 'k' );
  SetText( ClearMarkButton, "Clear Mark" );
  SetInstant( ClearMarkButton );
  AddControl( ClearMarkButton'unchecked_access, false );

  Init( HBar2, 1, 8, 32, 8 );
  AddControl( HBar2'unchecked_access, false );

  Init( AppendButton, 1, 9, 32, 9, 'a' );
  SetText( AppendButton, "Append" );
  SetInstant( AppendButton );
  AddControl( AppendButton'unchecked_access, false );

  Init( GotoButton, 1, 10, 32, 10, 'g' );
  SetText( GotoButton, "Goto" );
  SetInstant( GotoButton ); -- duplicate button with Find.
  AddControl( GotoButton'unchecked_access, false );

  Init( HBar3, 1, 11, 32, 11 );
  AddControl( HBar3'unchecked_access, false );

  Init( CommentButton, 1, 12, 32, 12, 'o' );
  SetText( CommentButton, "Comment Out" );
  SetInstant( CommentButton );
  AddControl( CommentButton'unchecked_access, false );

  Init( UppercaseButton, 1, 13, 32, 13, 'r' );
  SetText( UppercaseButton, "Uppercase Lines" );
  SetInstant( UppercaseButton );
  AddControl( UppercaseButton'unchecked_access, false );

  Init( LowercaseButton, 1, 14, 32, 14, 'l' );
  SetText( LowercaseButton, "Lowercase Lines" );
  SetInstant( LowercaseButton );
  AddControl( LowercaseButton'unchecked_access, false );

  Init( HBar4, 1, 15, 32, 15 );
  AddControl( HBar4'unchecked_access, false );

  Init( CancelButton, 1, 16, 32, 16, 'l' );
  SetText( CancelButton, "Cancel" );
  SetInstant( CancelButton );
  AddControl( CancelButton'unchecked_access, false );

  DoDialog( DT, HearInCB => MenuInputCB );
  CloseWindow; -- close window resets userio losing keys
  case DT.Control is
  when 1 => s(1) := CopyKey;
            SetInputString( To255( s ) );
            SetInfoText( "Copied lines" );
  when 2 => s(1) := ClearKey;
            SetInputString( To255( s ) );
            SetInfoText( "Cleared lines" );
  when 3 => null;
            --s(1) := ClearKey;
            --SetInputString( To255( s ) );
  when 4 => s(1) := PasteKey;
            SetInputString( To255( s ) );
            SetInfoText( "Pasted lines" );
  when 6 => s(1) := MarkKey;
            SetInputString( To255( s ) );
            SetInfoText( "Pasted lines" );
  when 7 => SetMark( SourceBox, -1 );
            SetInfoText( "Mark set" );
  when 9 => MoveCursor( SourceBox, 256, 0 ); -- append
  when 10 => GotoLine;
  when 12 => CommentOut;
  when 13 => UppercaseBlock;
  when 14 => LowercaseBlock;
  when others => SetInfoText( "" ); -- cancel
  end case;
end EditMenu;


-------------------------------------------------------------------------------
--  FIND MENU
-------------------------------------------------------------------------------

procedure FindMenu is

  FindButton   : aliased ASimpleButton;
  NextButton   : aliased ASimpleButton;
  SubButton    : aliased ASimpleButton;
  TagButton    : aliased ASimpleButton;
  ErrButton    : aliased ASimpleButton;
  GotoButton   : aliased ASimpleButton;
  ItemHelpButton : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;

  HBar1        : aliased AnHorizontalSep;

  DT : ADialogTaskRecord;

  procedure FindOrReplace is
    -- not finished yet
    TempHeader : Str255List.List;
    ThisLine   : Str255;
  begin
    if not Replacing then
       FindText( SourceBox, Text2Find, FindBackwards, FindRegExp );
       SetThumb( SourceBar, GetCurrent( SourceBox ) );
    else
       ReplaceText( SourceBox, Text2Find, Text2Replace, FindBackwards, FindRegExp );
       SetThumb( SourceBar, GetCurrent( SourceBox ) );
    end if;
    DrawWindow;
  end FindOrReplace;

begin
  OpenWindow( To255( "Find Menu" ), 25, DisplayInfo.V_Res-13, 46,
    DisplayInfo.V_Res-3, Normal );

  Init( FindButton, 1, 1, 20, 1, 'y' );
  SetInstant( FindButton );
  SetText( FindButton, "Find/Replace (y)" );
  AddControl( FindButton'unchecked_access, false );

  Init( NextButton, 1, 2, 20, 2, 'n' );
  SetInstant( NextButton );
  SetText( NextButton, "Next" );
  AddControl( NextButton'unchecked_access, false );

  Init( SubButton, 1, 3, 20, 3, 's' );
  SetInstant( SubButton );
  SetText( SubButton, "Subprograms..." );
  AddControl( SubButton'unchecked_access, false );

  Init( TagButton, 1, 4, 20, 4, 'c' );
  SetInstant( TagButton );
  SetText( TagButton, "Class..." );
  AddControl( TagButton'unchecked_access, false );

  Init( ErrButton, 1, 5, 20, 5, 'x' );
  SetInstant( ErrButton );
  SetText( ErrButton, "Next Error" );
  AddControl( ErrButton'unchecked_access, false );

  Init( GotoButton, 1, 6, 20, 6, 'g' );
  SetInstant( GotoButton );
  SetText( GotoButton, "Goto" );
  AddControl( GotoButton'unchecked_access, false );

  Init( ItemHelpButton, 1, 7, 20, 7, 'h' );
  SetInstant( ItemHelpButton );
  SetText( ItemHelpButton, "Item Help" );
  AddControl( ItemHelpButton'unchecked_access, false );

  Init( CancelButton, 1, 9, 20, 9, 'l' );
  SetInstant( CancelButton );
  SetText( CancelButton, "Cancel" );
  AddControl( CancelButton'unchecked_access, false );

  Init( HBar1, 1, 8, 20, 8 );
  AddControl( HBar1'unchecked_access, false );

  -- Disable Menu Items

  -- BUSH language definitions not loaded?  Assume nothing loaded.
  if languageData( BUSH ).keywordCount = 0 then
     SetStatus( ItemHelpButton, off );
  end if;

  -- Previous text to find
  if length( Text2Find ) > 0 then
    SetStatus( NextButton, On );
  else
    SetStatus( NextButton, Off );
  end if;

  -- Function lookup not available for all languages
  if SourceLanguage /= Ada_Language and SourceLanguage /= Perl and SourceLanguage /= PHP then
     SetStatus( SubButton, Off );
  end if;
  if SourceLanguage /= Ada_Language and SourceLanguage /= Java and SourceLanguage /= PHP then
     SetStatus( TagButton, Off );
  end if;

  DoDialog( DT, HearInCB => MenuInputCB );
  CloseWindow;

  case DT.Control is
  when 1 => if FindDialog then
               if length( Text2Find ) > 0 then
                  FindOrReplace;
               else
                  SetFindPhrase( SourceBox, NullStr255 );
               end if;
            else
               SetFindPhrase( SourceBox, NullStr255 );
               SetStatus( NextButton, Off );
            end if;
  when 2 => FindOrReplace;
  when 3 => FindSubprogram;
  when 4 => FindTaggedRecord;
  when 5 => GotoNextError;
  when 6 => GotoLine;
  when 7 => ItemHelp;
  when others => SetInfoText( "" ); -- cancel
  end case;
end FindMenu;


-------------------------------------------------------------------------------
--  MISC MENU
-------------------------------------------------------------------------------

procedure MiscMenu is

  procedure ShowManual( title, manpage : string ) is
  -- display a list of signals
  -- for some reason causes problems for main menu
     TempList : Str255List.List;
     TempFile : Str255;
     TempLine : Str255;
     p : integer;
  begin
    MakeTempFileName( TempFile ); 
    UNIX( manpage & " > " & TempFile );
    if IsFile( TempFile ) then
       LoadList( TempFile, TempList );
       -- remove bold facing
       for i in 1..Str255List.Length( TempList ) loop
           Str255List.Find( TempList, i, TempLine );
           p := 1;
           loop
               exit when p > length( TempLine );
               if Element( TempLine, p ) = ASCII.BS then
                  Delete( TempLine, p, p+1 );
               else
                  p := p + 1;
               end if;
           end loop;
           Str255List.Replace( TempList, i, TempLine );
       end loop;
       ShowListInfo( Title, 0, 1, DisplayInfo.H_Res-2, 23, TempList );
       Erase( TempFile );
       Str255List.Clear( TempList );
    end if;
  end ShowManual;

  MacButton      : aliased ASimpleButton;
  OptionButton   : aliased ASimpleButton;
  DebuggerButton : aliased ASimpleButton;
  GDBButton      : aliased ASimpleButton;
  GUIButton      : aliased ASimpleButton;
  SignalButton   : aliased ASimpleButton;
  StatsButton    : aliased ASimpleButton;
  CancelButton   : aliased ASimpleButton;

  HBar1          : aliased AnHorizontalSep;
  HBar2          : aliased AnHorizontalSep;

  DT : ADialogTaskRecord;

begin
  OpenWindow( To255( "Misc Menu" ), 35, DisplayInfo.V_Res-14, 56,
    DisplayInfo.V_Res-3, Normal );

  Init( MacButton, 1, 1, 20, 1, 'm' );
  SetInstant( MacButton );
  SetText( MacButton, "Edit Macros" );
  AddControl( MacButton'unchecked_access, false );

  Init( OptionButton, 1, 2, 20, 2, 'o' );
  SetInstant( OptionButton );
  SetText( OptionButton, "Options" );
  AddControl( OptionButton'unchecked_access, false );

  Init( DebuggerButton, 1, 3, 20, 3, 'd' );
  SetInstant( DebuggerButton );
  SetText( DebuggerButton, "Debugger" );
  AddControl( DebuggerButton'unchecked_access, false );

  Init( GDBButton, 1, 4, 20, 4, 'g' );
  SetInstant( GDBButton );
  SetText( GDBButton, "gdb" );
  AddControl( GDBButton'unchecked_access, false );

  Init( GUIButton, 1, 5, 20, 5, 'u' );
  SetInstant( GUIButton );
  SetText( GUIButton, "GUI Builder" );
  AddControl( GUIButton'unchecked_access, false );

  Init( StatsButton, 1, 6, 20, 6, 't' );
  SetInstant( StatsButton );
  SetText( StatsButton, "Stats" );
  AddControl( StatsButton'unchecked_access, false );

  Init( SignalButton, 1, 8, 20, 8, 's' );
  SetInstant( SignalButton );
  SetText( SignalButton, "Signals" );
  AddControl( SignalButton'unchecked_access, false );
  SetStatus( SignalButton, off ); -- not debugged yet

  Init( CancelButton, 1, 10, 20, 10, 'l' );
  SetInstant( CancelButton );
  SetText( CancelButton, "Cancel" );
  AddControl( CancelButton'unchecked_access, false );

  Init( HBar1, 1, 7, 20, 7 );
  AddControl( HBar1'unchecked_access, false );

  Init( HBar2, 1, 9, 20, 9 );
  AddControl( HBar2'unchecked_access, false );

  DoDialog( DT, HearInCB => MenuInputCB );
  CloseWindow;

  case DT.Control is
  when 1 => EditMacros;
  when 2 => OptionsWindow;
  when 3=>  if Proj_Debug /= 3 then
         NoteAlert( "Debugging must be set to Prerelease" );
       else
         CautionAlert( "Debugger is experimental." );
         Debugger( Proj_Main );
       end if;
  when 4 => DoGDB;
  when 5 => DoGUI;
  when 6 => ShowLineStats;
  when 7 => null; --ShowManual( "Signals", "man 7 signal" );
  when others => SetInfoText( "" ); -- cancel
  end case;
end MiscMenu;


-------------------------------------------------------------------------------
--  PROJ MENU
-------------------------------------------------------------------------------

procedure ProjectMenu is

  OpenButton   : aliased ASimpleButton;
  ParamButton  : aliased ASimpleButton;
  BuildButton  : aliased ASimpleButton;
  ProfileButton: aliased ASimpleButton;
  HistoryButton: aliased ASimpleButton;
  BackupButton : aliased ASimpleButton;
  UpdateButton : aliased ASimpleButton;
  CommitButton : aliased ASimpleButton;
  ImportButton : aliased ASimpleButton;
  CancelButton : aliased ASimpleButton;
  HBar1        : aliased AnHorizontalSep;
  HBar2        : aliased AnHorizontalSep;

  DT : ADialogTaskRecord;

  procedure OpenNewProject is
    sof : ASelectOpenFileRec;
  begin
    SaveProject;
    -- more here
    sof.prompt := To255( "Open which project file?" );
    sof.direct := false;
    sof.suffix := NullStr255;
    SelectOpenFile( sof );
    if sof.replied then
       ProjectPath := sof.path & "/" & sof.fname;
       LoadProject;
    end if;
  end OpenNewProject;

begin
  OpenWindow( To255( "Project Menu" ), 40, DisplayInfo.V_Res-16, 63,
    DisplayInfo.V_Res-3, Normal );

  Init( OpenButton, 1, 1, 22, 1, 'o' );
  SetInstant( OpenButton );
  SetText( OpenButton, "Open Proj..." );
  AddControl( OpenButton'unchecked_access, false );

  Init( ParamButton, 1, 2, 22, 2, 'p' );
  SetInstant( ParamButton );
  SetText( ParamButton, "Params" );
  AddControl( ParamButton'unchecked_access, false );

  Init( BuildButton, 1, 3, 22, 3, 'b' );
  SetInstant( BuildButton );
  SetText( BuildButton, "Build" );
  AddControl( BuildButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( BuildButton, Off );
  end if;

  Init( ProfileButton, 1, 4, 22, 4, 'f' );
  SetInstant( ProfileButton );
  SetText( ProfileButton, "Profile" );
  AddControl( ProfileButton'unchecked_access, false );

  Init( HistoryButton, 1, 5, 22, 5, 'h' );
  SetInstant( HistoryButton );
  SetText( HistoryButton, "History" );
  AddControl( HistoryButton'unchecked_access, false );

  Init( BackupButton, 1, 7, 22, 7, 'n' );
  SetInstant( BackupButton );
  SetText( BackupButton, "Backup Now" );
  AddControl( BackupButton'unchecked_access, false );

  Init( UpdateButton, 1, 8, 22, 8, 'u' );
  SetInstant( UpdateButton );
  SetText( UpdateButton, "Update / Diff ..." );
  AddControl( UpdateButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( UpdateButton, Off );
  end if;

  Init( CommitButton, 1, 9, 22, 9, 'c' );
  SetInstant( CommitButton );
  SetText( CommitButton, "Share Changes..." );
  AddControl( CommitButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( CommitButton, Off );
  end if;

  Init( ImportButton, 1, 10, 22, 10, 'j' );
  SetInstant( ImportButton );
  SetText( ImportButton, "Share Project..." );
  AddControl( ImportButton'unchecked_access, false );
  if not ProjectLocked then
     SetStatus( ImportButton, Off );
  end if;

  Init( CancelButton, 1, 12, 22, 12, 'l' );
  SetInstant( CancelButton );
  SetText( CancelButton, "Cancel" );
  AddControl( CancelButton'unchecked_access, false );

  Init( HBar1, 1, 6, 22, 6 );
  AddControl( HBar1'unchecked_access, false );

  Init( HBar2, 1, 11, 22, 11 );
  AddControl( HBar2'unchecked_access, false );

  if length( Opt_Backup ) = 0 then
     SetStatus( BackupButton, Off );
  end if;

  -- Don't import if no source control available or if already source controlled
  -- Could be a little smarter...i.e. if someone was moving project from one kind of
  -- source control to another, they might want to import but won't be able to...
  if ( not (HasCVS and Opt_CVS ) or not (HasSVN and Opt_SVN) ) or IsCVSProject or IsSVNProject then
    SetStatus( ImportButton, Off );
  end if;
  -- Don't use source control if not available or project is not in source control
  if not ( HasCVS and Opt_CVS and IsCVSProject ) and
     not ( HasSVN and Opt_SVN and IsSVNProject ) then
  --if not (HasCVS and Opt_CVS and IsCVSProject) then
    SetStatus( UpdateButton, Off );
    SetStatus( CommitButton, Off );
  end if;

  DoDialog( DT, HearInCB => MenuInputCB );
  CloseWindow;

  case DT.Control is
  when 1 => OpenNewProject;
  when 2 => ProjectParams;
  when 3 => BuildProject;
  when 4 => ProfileProject;
  when 5 => ProjectHistory;
  when 6 => BackupProject;
  when 7 => if Opt_CVS then
               CVSUpdate;
            else
               SVNUpdate;
            end if;
  when 8 => declare
               Response : AControlNumber;
            begin
               if WasTouched( SourceBox ) then
                  Response := YesCancelAlert( "Save changes to "
                     & ToString( GetWindowTitleFromPath( SourcePath ) )
                     & "?", status );
                  if Response = 1 then
                     SaveSource( DoBackgroundUpdate => false );
                 end if;
               end if;
               if Response /= 3 then
                  if Opt_CVS then
                     CVSCommit;     -- save changes
                  else
                     SVNCommit;     -- save changes
                  end if;
                  RefreshSource; -- CVS may have made changes
               end if;
            end;

  when 9 => if length( ProjectPath ) = 0 then
               SaveProject; -- save project file before sharing
               -- Should automatically call CVS/SVN if new...
            else
               SaveProject; -- save project file before sharing
               if Opt_CVS then
                  CVSImport;
               else
                  SVNImport;
               end if;
            end if;
  when others => SetInfoText( "" ); -- cancel
  end case;

end ProjectMenu;


-------------------------------------------------------------------------------
-- HOUSEKEEPING
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--  MAIN
--
-- Called after startup.  Create the main TIA window.  Handle main and quick
-- open menus.  After 24 hours, backup project.  Display a friendly TIA tip on
-- startup.
-------------------------------------------------------------------------------

procedure Main is

  OneDay : ATimeStamp := 24*60*60*1_000_000; -- 24 hours, in milliseconds

  FileButton : aliased ASimpleButton;
  EditButton : aliased ASimpleButton;
  FindButton : aliased ASimpleButton;
  MiscButton : aliased ASimpleButton;
  ProjButton : aliased ASimpleButton;
  AboutButton: aliased ASimpleButton;
  -- these appear on a wide screen
  QuickLabel : aliased AStaticLine;
  OneButton  : aliased ASimpleButton;
  TwoButton  : aliased ASimpleButton;
  ThreeButton : aliased ASimpleButton;
  FourButton : aliased ASimpleButton;
  FiveButton : aliased ASimpleButton;
  OtherButton: aliased ASimpleButton;
  FrameWidth : aliased AStaticLine;
  FrameHeight: aliased AStaticLine;
  StatsLabel : aliased AStaticLine;

  DT         : ADialogTaskRecord;

  -- copy of routine from OpenSource
  -- probably layout should be changed to avoid this

    procedure SwitchToNewFile( sr : ASourceReference ) is
      TempSave : ASourceReference;
      -- kludge: gnat 3.10 mangled sr during return from SaveSource call
    begin
      TempSave := sr;
      SaveSource;
      if IsFile( TempSave.path ) then
         SourcePath := TempSave.path;
         Str255List.Clear( SourceText );
         LoadSourceFile( SourcePath, SourceText );
         SetSourceLanguage( SourcePath );   -- determine the language
         SetKeywords( SourcePath );
         SetList( SourceBox, SourceText );
         Str255List.Clear( SourceText );    -- no longer used
         SetCursor( SourceBox, TempSave.Posn, TempSave.Line );
         SetThumb( SourceBar, long_integer( TempSave.Posn ) );
      else
         StopAlert( ToString( SourcePath ) & " doesn't exist" );
      end if;
      UpdateSourceDisplay;
    end SwitchToNewFile;

begin
  OpenWindow( GetWindowTitleFromPath( SourcePath ), 0, 0,
     DisplayInfo.H_Res-1, DisplayInfo.V_Res-1, normal, true );

  if DisplayInfo.H_Res > 90 then
     Init( SourceBox, 1, 1, DisplayInfo.H_Res-23, DisplayInfo.V_Res-4 );
     SetSourceLanguage( SourceBox, Ada_Language );
     AddControl( SourceBox'unchecked_access, true );

     Init( SourceBar, DisplayInfo.H_Res-22, 1, DisplayInfo.H_Res-22,
        DisplayInfo.V_Res-5 );
     AddControl( SourceBar'unchecked_access, IsGlobal => true );
  else
     Init( SourceBox, 1, 1, DisplayInfo.H_Res-3, DisplayInfo.V_Res-4 );
     SetSourceLanguage( SourceBox, Ada_Language );
     AddControl( SourceBox'unchecked_access, true );

     Init( SourceBar, DisplayInfo.H_Res-2, 1, DisplayInfo.H_Res-2,
        DisplayInfo.V_Res-5 );
     AddControl( SourceBar'unchecked_access, IsGlobal => true );
  end if;

  Init( FileButton, 1, DisplayInfo.V_Res-3, 10, DisplayInfo.V_Res-3, 'f' );
  SetText( FileButton, To255( "File" ) );
  SetInfo( FileButton, To255( "File Menu" ) );
  SetInstant( FileButton );
  AddControl( FileButton'unchecked_access, IsGlobal => true );
  
  Init( EditButton, 11, DisplayInfo.V_Res-3, 20, DisplayInfo.V_Res-3, 'e' );
  SetText( EditButton, To255( "Edit" ) );
  SetInfo( EditButton, To255( "Edit Menu" ) );
  SetInstant( EditButton );
  AddControl( EditButton'unchecked_access, IsGlobal => true );
  
  Init( FindButton, 21, DisplayInfo.V_Res-3, 30, DisplayInfo.V_Res-3, 'i' );
  SetText( FindButton, To255( "Find" ) );
  SetInfo( FindButton, To255( "Find text" ) );
  SetInstant( FindButton );
  AddControl( FindButton'unchecked_access, IsGlobal => true );
  
  Init( MiscButton, 31, DisplayInfo.V_Res-3, 40, DisplayInfo.V_Res-3, 'm' );
  SetText( MiscButton, To255( "Misc" ) );
  SetInfo( MiscButton, To255( "Misc Menu" ) );
  SetInstant( MiscButton );
  AddControl( MiscButton'unchecked_access, IsGlobal => true );
  
  Init( ProjButton, 41, DisplayInfo.V_Res-3, 50, DisplayInfo.V_Res-3, 'p' );
  SetText( ProjButton, To255( "Proj" ) );
  SetInfo( ProjButton, To255( "Project Menu" ) );
  SetInstant( ProjButton );
  AddControl( ProjButton'unchecked_access, IsGlobal => true );
  
  --Init( ProjButton, 51, DisplayInfo.V_Res-3, 60, DisplayInfo.V_Res-3, 'p' );
  --SetText( ProjButton, To255( "Proj" ) );
  --SetInfo( ProjButton, To255( "Change Project Parameters - optimization, debugging, ..." ) );
  --SetInstant( ProjButton );
  --AddControl( SimpleButton, ProjButton'unchecked_access, IsGlobal => true );
  
  Init( AboutButton, 61, DisplayInfo.V_Res-3, 66, DisplayInfo.V_Res-3, '?' );
  SetText( AboutButton, To255( "?" ) );
  SetInfo( AboutButton, To255( "About this program" ) );
  SetInstant( AboutButton );
  AddControl( AboutButton'unchecked_access, IsGlobal => true );
 
  -- Wide Screen

  if DisplayInfo.H_Res > 90 then

    Init( QuickLabel, DisplayInfo.H_Res-20, 4, DisplayInfo.H_Res-2,
       4 );
    SetText( QuickLabel, "Quick Open" );
    SetStyle( QuickLabel, Heading );
    AddControl( QuickLabel'unchecked_access, false );

    Init( OneButton, DisplayInfo.H_Res-20, 6, DisplayInfo.H_Res-2,
       6, '1' );
    SetText( OneButton, "1 -" );
    SetInstant( OneButton );
    AddControl( OneButton'unchecked_access, false );

    Init( TwoButton, DisplayInfo.H_Res-20, 8, DisplayInfo.H_Res-2,
       8, '2' );
    SetText( TwoButton, "2 -" );
    SetInstant( TwoButton );
    AddControl( TwoButton'unchecked_access, false );

    Init( ThreeButton, DisplayInfo.H_Res-20, 10, DisplayInfo.H_Res-2,
       10, '3' );
    SetText( ThreeButton, "3 -" );
    SetInstant( ThreeButton );
    AddControl( ThreeButton'unchecked_access, false );

    Init( FourButton, DisplayInfo.H_Res-20, 12, DisplayInfo.H_Res-2,
       12, '4' );
    SetText( FourButton, "4 -" );
    SetInstant( FourButton );
    AddControl( FourButton'unchecked_access, false );

    Init( FiveButton, DisplayInfo.H_Res-20, 14, DisplayInfo.H_Res-2,
       14, '5' );
    SetText( FiveButton, "5 -" );
    SetInstant( FiveButton );
    AddControl( FiveButton'unchecked_access, false );

    Init( OtherButton, DisplayInfo.H_Res-20, 16, DisplayInfo.H_Res-2,
       16, 'o' );
    SetText( OtherButton, "Other ..." );
    SetInfo( OtherButton, To255( "Open something else" ) );
    SetInstant( OtherButton );
    AddControl( OtherButton'unchecked_access, false );

    ShowingMarginStats := true;

    Init( StatsLabel, DisplayInfo.H_Res-20, 19, DisplayInfo.H_Res-2,
      19 );
    SetText( StatsLabel, "Location" );
    SetStyle( StatsLabel, Heading );
    AddControl( StatsLabel'unchecked_access, false );

    Init( CursorPosX, DisplayInfo.H_Res-20, 21, DisplayInfo.H_Res-2,
      21 );
    AddControl( CursorPosX'access, false );

    Init( CursorPosY, DisplayInfo.H_Res-20, 22, DisplayInfo.H_Res-2,
      22 );
    AddControl( CursorPosY'access, false );

    Init( DocLength, DisplayInfo.H_Res-20, 23, DisplayInfo.H_Res-2,
      23 );
    AddControl( DocLength'access, false );

    declare
      r : aRect := getFrame( SourceBox );
    begin
      Init( FrameWidth, DisplayInfo.H_Res-20, 24, DisplayInfo.H_Res-2,
        24 );
      SetText( FrameWidth, " Width:" & integer'image( r.right-r.left-1  ) );
      AddControl( FrameWidth'unchecked_access, false );
      Init( FrameHeight, DisplayInfo.H_Res-20, 25, DisplayInfo.H_Res-2,
        25 );
      SetText( FrameHeight, "Height:" & integer'image( r.bottom-r.top-1  ) );
      AddControl( FrameHeight'unchecked_access, false );
    end;

  end if;

  if length( SourcePath ) > 0 then
     LoadSourceFile( SourcePath, SourceText );
     SetList( SourceBox, SourceText );
     Str255List.Clear( SourceText );    -- no longer used
     SetSourceLanguage( SourcePath );   -- determine the language
     SetKeywords( SourcePath );
     UpdateSourceDisplay;
  else
     OpenSource;
  end if;

  SetThumb( SourceBar, 1 );
  SetMax( SourceBar, GetLength( SourceBox ) );
  SetScrollBar( SourceBox, 2 );
  SetOwner( SourceBar, 1 );

  SetInfoText( "TIA Tip: " & GetTiaTip ); -- startup help tip
  loop

    -- backup check

    if length( Opt_Backup ) > 0 then          -- is there a backup command?
       if GetTimeStamp >= Proj_BackupTime + OneDay then
          -- has it been 24 hours since last recorded backup?
          BackupProject;
       end if;
    end if;

    -- update quick buttons (should really check for changes
    -- instead of a brute-force update of all buttons
    if length( QuickOpen1.path ) = 0 then
       SetStatus( OneButton, off );
       SetText( OneButton, "1 - " );
       SetInfo( OneButton, NullStr255 );
    else
       SetStatus( OneButton, standby );
       SetText( OneButton, "1 " & Basename( QuickOpen1.path ) );
       SetInfo( OneButton, "Open " & QuickOpen1.path );
    end if;
    if length( QuickOpen2.path ) = 0 then
       SetStatus( TwoButton, off );
       SetText( TwoButton, "2 - " );
       SetInfo( TwoButton, NullStr255 );
    else
       SetStatus( TwoButton, standby );
       SetText( TwoButton, "2 " & Basename( QuickOpen2.path ) );
       SetInfo( TwoButton, "Open " & QuickOpen2.path );
    end if;
    if length( QuickOpen3.path ) = 0 then
       SetStatus( ThreeButton, off );
       SetText( ThreeButton, "3 - " );
       SetInfo( ThreeButton, NullStr255 );
    else
       SetStatus( ThreeButton, standby );
       SetText( ThreeButton, "3 " & Basename( QuickOpen3.path ) );
       SetInfo( ThreeButton, "Open " & QuickOpen3.path );
    end if;
    if length( QuickOpen4.path ) = 0 then
       SetStatus( FourButton, off );
       SetText( FourButton, "4 - " );
       SetInfo( FourButton, NullStr255 );
    else
       SetStatus( FourButton, standby );
       SetText( FourButton, "4 " & Basename( QuickOpen4.path ) );
       SetInfo( FourButton, "Open " & QuickOpen4.path );
    end if;
    if length( QuickOpen5.path ) = 0 then
       SetStatus( FiveButton, off );
       SetText( FiveButton, "5 - " );
       SetInfo( FiveButton, NullStr255 );
    else
       SetStatus( FiveButton, standby );
       SetText( FiveButton, "5 " & Basename( QuickOpen5.path ) );
       SetInfo( FiveButton, "Open " & QuickOpen5.path );
    end if;
    DrawWindow( Frame );

    DoDialog( DT, HearInCB => InputCB, HearOutCB => OutputCB );
    case DT.control is
    when 3 => FileMenu;
    when 4 => EditMenu;
    when 5 => FindMenu;
    when 6 => MiscMenu;
    when 7 => ProjectMenu;
    when 8 => AboutProgram;
    -- wide screen
    when 10 => SwitchToNewFile( QuickOpen1 );
      SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
      DrawWindow( Frame );
    when 11 => SwitchToNewFile( QuickOpen2 );
      SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
      DrawWindow( Frame );
    when 12 => SwitchToNewFile( QuickOpen3 );
      SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
      DrawWindow( Frame );
    when 13 => SwitchToNewFile( QuickOpen4 );
      SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
      DrawWindow( Frame );
    when 14 => SwitchToNewFile( QuickOpen5 );
      SetWindowTitle( GetWindowTitleFromPath( SourcePath ) );
      DrawWindow( Frame );
    when 15 => OpenSource;
    when others => null;
    end case;
    exit when done;
  end loop;
SessionLog( "Closing main window" );
  CloseWindow;
end Main;


-------------------------------------------------------------------------------
--  STARTUP
--
-- Startup TextTools, get information about the the current development
-- platform.  If there is a project name on the command line, load the project.
-- Load the global options file.
-------------------------------------------------------------------------------

procedure Startup is
  cvs_found_at : natural := 0;
  TempStr : Str255;
  TempList : Str255List.List;
  TempFile : Str255;
  OneDay : ATimeStamp := 24*60*60*1_000_000; -- 24 hours, in milliseconds
begin
  StartupCommon( "TIA", "tia" );                 -- TextTools' common pkg
  StartupOS;                                     -- TextTools' OS package
  StartupUserIO;                                 -- TextTools' User IO pkg
  BlueBackground( blueOn => true );              -- blue background
  StartupControls;                               -- TextTools' controls
  StartupWindows;                                -- TextTools' windows
  InitBackground;                                -- init background updates
  GetDisplayInfo( DisplayInfo );                 -- screen size, etc.

  OpenWindow( to255( "Starting TIA" ), 3, 3, DisplayInfo.H_Res-4, 9, normal );
  MoveTo( 3, 3 );
  Draw( "Checking platform...                                    " );

  GetPlatformSig;                                -- determine develop plat.
  if Ada.Command_Line.Argument_Count > 0 then    -- user gave a proj name?
     ProjectPath := To255( Ada.Command_Line.Argument( 1 ) );
     if Index( ProjectPath, ".adp" ) = 0 then    -- add ".adp" if missing
        ProjectPath := ProjectPath & ".adp";
     end if;
     LoadProject;                                -- load this project
  else                                           -- Brand new project?
     SourcePath := NullStr255;                   -- no source file name
     if UNIX( "gnatgcc -v > /dev/null 2>/dev/null" ) then -- using ALT?
        Proj_Alt := true;                        -- turn on by default
     end if;                                     -- in project params
  end if;

  MoveTo( 3, 3 );
  Draw( "Loading languages definitions...                        " );
  begin
    LoadLanguageData;
  exception when ada.text_io.name_error =>
    StopAlert( "Unable to load language definition file '" & languageFileName & "'" );
    StopAlert( "Some features have been disabled" );
    CloseWindow;
  when format_error =>
    StopAlert( "Language definition file is not formatted properly" );
    CloseWindow;
    raise;
  end;
  -- Even if it didn't load, use empty one as default
  SetLanguageData( SourceBox, languageData'access );
  SetSourceLanguage( SourceBox, ADA_LANGUAGE ); -- default
  SetHTMLTagsStyle( SourceBox, false ); -- default

  MoveTo( 3, 3 );
  Draw( "Loading options...                                      " );
  LoadOptions;                                   -- global options file

  -- Load Item Help File

  if IsFile( to255( "$HOME/.tiahelp.txt" ) ) then       -- local tiahelp.txt?
     LoadList( to255( "$HOME/.tiahelp.txt" ), ItemHelpList );    -- load it
  elsif IsFile( to255( "/etc/tiahelp.txt" ) ) then    -- else /etc file?
     LoadList( to255( "tiahelp.txt" ), ItemHelpList );    -- load it
  end if;

  MoveTo( 3, 3 );
  Draw( "Checking for source control...                          " );
  -- Check for Subversion

  HasSVN := false;
  if unix( "svn --version --quiet > /dev/null" ) then
     HasSVN := true;
  end if;

  -- Check for CVS

  for i in 1..Ada.Command_Line.Environment.Environment_Count loop
     if Ada.Command_Line.Environment.Environment_Value(i)'length < 255 then
        TempStr := To255( Ada.Command_Line.Environment.Environment_Value(i) );
        if length( TempStr ) > 8 then
           if Head( TempStr, 8 ) = To255( "CVSROOT=" ) then
              cvs_found_at := i;
              exit;                              -- CVSROOT defined?
           end if;
        end if;
    end if;
  end loop;
  if cvs_found_at > 0 then                       -- if defined
    if IsDirectory( Tail( TempStr, length( TempStr )-8 ) ) then
       if unix("cvs -v >/dev/null" ) then        -- try running cvs
         HasCVS := true;                         -- no error? good
       else                                      -- else warning
           CautionAlert( "CVSROOT defined but cannot find/execute cvs" );
        end if;
    else                                         -- no directory? warning
      CautionAlert( "CVSROOT defined but directory doesn't exist" );
    end if;
  elsif Opt_CVS then                             -- is CVS option on?
     CautionAlert( "CVS not available: CVSROOT variable is not defined" );    -- warning
     Opt_CVS := false;
  end if;
  if HasCVS and Opt_CVS and length( ProjectPath ) /= 0
     and IsCVSProject then
       -- every 24 hours prompt for project update
       if GetTimeStamp - Proj_UpdateTime > OneDay then
          CVSUpdate;
       end if;
  end if;
  if HasSVN and Opt_SVN and length( ProjectPath ) /= 0
     and IsCVSProject then
       -- every 24 hours prompt for project update
       if GetTimeStamp - Proj_UpdateTime > OneDay then
          SVNUpdate;
       end if;
  end if;

  CloseWindow;

end Startup;


-------------------------------------------------------------------------------
--  SHUTDOWN
--
-- Save the current project and options, and shutdown TextTools.
-------------------------------------------------------------------------------

procedure Shutdown is
  -- shutdown tia
begin
  SaveProject;                                   -- save project file
  SaveOptions;                                   -- save options file
  ShutdownWindows;                               -- TextTools' windows
  ShutdownControls;                              -- TextTools' controls
  ShutdownUserio;                                -- TextTools' User IO
  ShutdownOS;                                    -- TextTools' OS package
  ShutdownCommon;                                -- TextTools' common pkg
end Shutdown;


-------------------------------------------------------------------------------
--  TIA main program
-------------------------------------------------------------------------------

begin
  Startup;                                       -- start TIA, load project
  Main;                                          -- main loop
  Shutdown;                                      -- stop TIA
  exception when others =>                       -- handle top-level exc's
     SessionLog( "tia main: an uncaught Ada exception occurred" );
     DrawErr( "Ada exception occurred" );
     DrawErrLn;
     DrawErr( "Shutting down..." );
     DrawErrLn;
     Shutdown;
     raise;
end tia;

