------------------------------------------------------------------------------
-- TIA DEBUG - Debugger interface for TIA                                   --
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
-- This is maintained at http://www.vaxxine.com/pegasoft                    --
--                                                                          --
------------------------------------------------------------------------------
with common, os, userio, controls, windows, tiacommon;
use common, os, userio, controls, windows, tiacommon;
with System.Address_To_Access_Conversions;

package body tiadebug is

  package CharPtrs is new System.Address_To_Access_Conversions( character );
  -- to convert "null" to an null address.  Doesn't have to be char ptr.

  type file_id is new integer;

  --function timeout_read( fd : file_id ) return character;
  --pragma import( C, timeout_read );
  -- our C function to read a char or timeout after a 1/4 second

  -- GCC 3.x doesn't like this.  We'll use TextTool's functions as a
  -- workaround
  --errno : integer;
  --pragma import( C, errno );
  -- error of last kernel call
  function C_errno return integer;
  pragma import( C, C_errno, "C_errno" );
  procedure C_reset_errno;
  pragma import( C, C_reset_errno, "C_reset_errno" );

  type pipe_ids is array(0..1) of file_id;
  -- for pipe kernel call

  procedure pipe( result : out integer; ids : out pipe_ids );
  pragma import( C, pipe );
  pragma import_valued_procedure( pipe );
  -- Kernel pipe command: creates a pipe

  function open( path : string; flags : integer ) return file_id;
  pragma import( C, open );
  -- Kernel open command: open a file

  procedure close( id : file_id );
  pragma import( C, close );
  -- Kernel close command: close a file

  procedure write_char( amount_written: out long_integer;
                   id : file_id;
                   buffer : in out character;
                   amount2write : long_integer );
  pragma import( C, write_char, "write" );
  pragma import_valued_procedure( write_char, "write" );
  -- Kernel write command: write a char to a file

  procedure read_char( amount_read: out long_integer;
                  id : file_id;
                  buffer : in out character;
                  amount2read : long_integer );
  pragma import( C, read_char, "read" );
  pragma import_valued_procedure( read_char, "read" );
  -- Kernel read command: read a char to a file

  function fork return integer;
  pragma import( C, fork );
  -- Kernel fork command: create a new process

  procedure dup2( result : out integer; old_id, new_id : file_id );
  pragma import( C, dup2 );
  pragma import_valued_procedure( dup2 );
  -- Kernel dup2 command: duplicate a file id

  procedure wait( pid : out integer; status : in out integer );
  pragma import( C, wait );
  pragma import_valued_procedure( wait );
  -- Kernel wait command: wait until child is done

  procedure C_exit( status : integer );
  pragma import( C, C_exit, "_exit" );
  -- Kernel exit command: stop the process

  procedure execlp_3( result : out integer; path, arg1, arg2 : string;
    arg3 : system.address );
  pragma import( C, execlp_3, "execlp" );
  pragma import_valued_procedure( execlp_3, "execlp" );
  -- Kernel execlp command: run another program the process.  This
  -- variation has two parameters, the program name plus one other.
  -- Last must be null pointer.

  procedure setpgid( result : out integer; pid, gid : integer );
  pragma import( C, setpgid );
  pragma import_valued_procedure( setpgid );
  -- Kernel setpgid command: set program group id for a process

  --function setsid return integer;
  --pragma import( C, setsid );
  -- Kernel setsid command: change a program to a new process group

  function getpid return integer;
  pragma import( C, getpid );
  -- Kernel getpgid command: get current program process id

  function getpgid( pid : integer) return integer;
  pragma import( C, getpgid );
  -- Kernel getpgid command: get a program group id

  function Kill( pid, sig : integer ) return integer;
  pragma import( C, kill );
  -- Kernel kill command: send a signal to a process

  -- Shared resources

  InputPipe  : pipe_ids;
  OutputPipe : pipe_ids;

  procedure Write2Debugger( s : string ) is
    Result : long_integer;
    ch : character;
  begin
    for i in 1..s'length loop
        ch := s(i);
        Write_Char( Result, InputPipe(1), ch, 1 );
        if Result < 0 then
           if C_errno = 9 then
              SessionLog( "Write2Debugger: Bad file number" );
           else
              SessionLog( "Write2Debugger: Error writing" & C_errno'img );
           end if;
           return;
        end if;
    end loop;
    ch := ASCII.LF;
    Write_Char( Result, InputPipe(1), ch, 1 );
    pragma Debug( SessionLog( "Write2Debugger: Wrote " & s ) );
  end Write2Debugger;

  procedure Write2TIA( s : string ) is
    Result : long_integer;
    ch : character;
  begin
    for i in 1..s'length loop
        ch := s(i);
        Write_Char( Result, 1, ch, 1 );
        if Result < 0 then
           if C_errno = 9 then
              SessionLog( "Write2TIA: Bad file number" );
           else
              SessionLog( "Write2TIA: Error writing" & C_errno'img );
           end if;
           return;
        end if;
    end loop;
    ch := ASCII.LF;
    Write_Char( Result, 1, ch, 1 );
    pragma Debug( SessionLog( "Write2TIA: Wrote " & s ) );
  end Write2TIA;

  procedure ReadFromDebugger( s : in out str255 ) is
    Result : long_integer;
    ch : character;
    event : anInputRecord;
  begin
    pragma Debug( SessionLog( "ReadFromDebugger: waiting" ) );
    s := NullStr255;
    loop
       -- Read_Char( Result, OutputPipe(0), ch, 1 );
       --ch := timeout_read( OutputPipe(0) );    -- check debugger
       if ch /= ASCII.NUL then                 -- didn't timeout?
          exit when ch = ASCII.LF;             -- new line? check user
          s := s & ch;                         -- else grow line
          if length( s ) > 5 then              -- does the line contain
             if Head( s, 6 ) = "(gdb) " then   -- gdb prompt?
                exit;                          -- then quit
             elsif length( s ) > 200 then      -- else long line?
                exit;                          -- break it there
             end if;
          end if;
       end if;
       GetInput( event, response => Instant ); -- check user
       if event.inputType /= nullInput then    -- did something?
          setInput( event, useTime => true );  -- requeue event
          pragma Debug( SessionLog( "ReadFromDebugger: Quit on user input" ) );
          exit;                                -- quit & service it
       end if;
    end loop;
    pragma Debug( SessionLog( "ReadFromDebugger: Read " & s ) );
  end ReadFromDebugger;

  procedure ReadFromTIA( s : in out str255 ) is
    Result : long_integer;
    ch : character;
  begin
    pragma Debug( SessionLog( "ReadFromTIA: waiting" ) );
    s := NullStr255;
    loop
       Read_Char( Result, 0, ch, 1 );
       s := s & ch;
       exit when ch = ASCII.LF;
       exit when length( s ) > 250;
    end loop;
    pragma Debug( SessionLog( "ReadFromTIA: Read " & s ) );
  end ReadFromTIA;


  -- The Debugger Process
  --
  -- This is a child process started by TIA containing GDB

  procedure DebuggerProcess( file : string ) is
    Result : integer;
    oldpgid : integer;
  begin

    SessionLog( "DebuggerProcess: Started as pid" & getpid'img );

    -- create pipes to and from standard output /output /error
    -- redirect stderr to stdout

    close( 0 );                       -- close stdin
    close( 1 );                       -- close stdout
    close( 2 );                       -- close stderr
    dup2( Result, InputPipe(0), 0 );  -- input pipe is now input
    dup2( Result, OutputPipe(1), 1 ); -- output pipe is now output
    dup2( Result, OutputPipe(1), 2 ); -- output pipe is now output
    Close( InputPipe( 0 ) );
    Close( OutputPipe( 1 ) );
    SessionLog( "DebuggerProcess: Input is from file id " & InputPipe(1)'img );
    SessionLog( "DebuggerProcess: Output is to file id " & OutputPipe(0)'img );

    -- give this process a new process group id for signalling purposes

    oldpgid := getpgid(0);
    setpgid( Result, 0, 0 );
    if Result /= 0 then
       SessionLog( "DebuggerProcess: unable to setpgid, errno " &
         C_errno'img );
    else
       SessionLog( "DebuggerProcess: Debugger pgid changed from" &
         oldpgid'img & " to" & getpgid(0)'img );
    end if;
    -- set the debug process' process group id to the group id of the
    -- current process.  Do this to kill the debugger and it's child
    -- processes without killing TIA

    -- The new process group will be the same as the debugger processes'
    -- ID, so we don't need to tell TIA what it is

    --new_pgid := setsid;
    --SessionLog( "DebuggerProcess: new session started - " & new_pgid'img );
    --SessionLog( "DebuggerProcess: Starting debugger" );
    if Proj_ALT then
       execlp_3( Result, "gnatgdb" & ASCII.NUL, "gnatgdb" & ASCII.NUL,
         file & ASCII.NUL, CharPtrs.To_Address( null )  );
    else
       execlp_3( Result, "gdb" & ASCII.NUL, "gdb" & ASCII.NUL,
         file & ASCII.NUL, CharPtrs.To_Address( null )  );
    end if;
    -- should never get here unless error
    SessionLog( "DebuggerProcess: error start up, errno " & C_errno'img );
    C_exit( 0 ); 
  end DebuggerProcess;


  -- TIA's Process
  --
  -- This is the main process that runs after the debugger child
  -- process is created.

  procedure TIAProcess( DebugID : integer ) is
    wait_pid : integer;
    wait_status : integer;
    teststr : str255;

    StepButton  : aliased ASimpleButton;
    StepIButton : aliased ASimpleButton;
    NextButton  : aliased ASimpleButton;
    NextIButton : aliased ASimpleButton;
    RunButton   : aliased ASimpleButton;
    BreakButton : aliased ASimpleButton;
    QuitButton  : aliased ASimpleButton;
    CmdLine     : aliased AnEditLine;
    DoButton    : aliased ASimpleButton;
    UntilButton : aliased ASimpleButton;
    ContButton  : aliased ASimpleButton;
    FinishButton: aliased ASimpleButton;
    RegButton   : aliased ASimpleButton;
    StackButton : aliased ASimpleButton;
    ClearButton : aliased ASimpleButton;
    GDBList     : aliased AStaticList;

    GDBOutput   : Str255List.List;
    GDBDone     : boolean := false;

    procedure CheckGDBOutput is
      --TempList : Str255List.List;
      pgid   : integer;
      Result : integer;
      s : str255;
    begin
      SetInfoText( "Press any key to interrupt" );
      loop
         ReadFromDebugger( s );
         Str255List.Queue( GDBOutput, s );
         if Str255List.length( GDBOutput ) > 250 then
            Str255List.Clear( GDBOutput, 1 );
         end if;
         -- This gives a 250 line scroll back buffer
         SetList( GDBList, GDBOutput );
         -- SetList COPIES GDBOutput to the list control
         MoveCursor( GDBList, 0, Str255List.Length( GDBOutput ) );
         -- Force the cursor to the end of the list to display
         -- bottom of list in window
         DrawWindow;
         -- Show what we have so far
         if length( s ) > 0 then
            if Head( s, 5 ) = "(gdb)" then
               exit;
            end if;
         end if;
         -- gdb prompt? then we're done
         if Keypress( shortblock => false ) /= ASCII.NUL then
            -- any keypress interrupts gdb and any sub processes
            -- in its process group
            SessionLog( "CheckGDBOutput: Key pressed, sending ctrl-c/SIGHUP to GDB" );
            pgid := getpgid( DebugID );
            if pgid < 0 then
               SessionLog( "CheckGDBOutput: getpgid failed, errno " & C_errno'img );
            else
               Result := Kill( -pgid, 2 );
               if Result /= 0 then
                  SessionLog( "CheckGDBOutput: Unable to kill " & C_errno'img );
               else
                  null;
                  pragma Debug( SessionLog( "CheckGDBOutput: SIGHUP pgid " & pgid'img ) );
               end if;
            end if;
            SetInfoText( "Interrupting..." );
         end if;
      end loop;
    end CheckGDBOutput;

    procedure GDBCommand( s : string ) is
      -- run a GDB command
      TempStr : Str255;
    begin
      Str255List.Find( GDBOutput, Str255List.Length( GDBOutput ),
        TempStr );
      TempStr := TempStr & " " & s;
      Str255List.Replace( GDBOutput, Str255List.Length( GDBOutput ),
        TempStr );
      Write2Debugger( s );
      CheckGDBOutput;
    end GDBCommand;

    procedure DoBreak is
      -- breakpoint window
      InfoLine : aliased AStaticLine;
      BreakLine : aliased AnEditLine;
      OKButton : aliased ASimpleButton;

      Done : boolean := false;
      DT : ADialogTaskRecord;
    begin
      OpenWindow( To255( "Breakpoint" ), 1, 2, 78, 10, normal );
      Init( InfoLine, 1, 1, 70, 1 );
      SetText( InfoLine, "Stop execution at what line number / subprogram?" );
      AddControl( InfoLine'unchecked_access, false );

      Init( BreakLine, 1, 5, 75, 5 );
      SetText( BreakLine, NullStr255 );
      AddControl( BreakLine'unchecked_access, false );

      Init( OKButton, 35, 7, 45, 7, 'o' );
      SetText( OKButton, "OK" );
      AddControl( OKButton'unchecked_access, false );

      loop
        DoDialog( DT );
        exit when DT.control = 3;
      end loop;
      GDBCommand( "break " & ToString( GetText( BreakLine ) ) );
      CloseWindow;
    end DoBreak;

    procedure DoClear is
      -- clear breakpoint window
      InfoLine : aliased AStaticLine;
      BreakLine : aliased AnEditLine;
      OKButton : aliased ASimpleButton;

      Done : boolean := false;
      DT : ADialogTaskRecord;
    begin
      OpenWindow( To255( "Clear Breakpoint" ), 1, 2, 78, 10, normal );
      Init( InfoLine, 1, 1, 70, 1 );
      SetText( InfoLine, "Clear which breakpoint number?" );
      AddControl( InfoLine'unchecked_access, false );

      Init( BreakLine, 1, 5, 75, 5 );
      SetText( BreakLine, NullStr255 );
      AddControl( BreakLine'unchecked_access, false );

      Init( OKButton, 35, 7, 45, 7, 'o' );
      SetText( OKButton, "OK" );
      AddControl( OKButton'unchecked_access, false );

      loop
        DoDialog( DT );
        exit when DT.control = 3;
      end loop;
      GDBCommand( "delete " & ToString( GetText( BreakLine ) ) );
      CloseWindow;
    end DoClear;

    --Result : integer;           -- result of Linux call
    Done   : boolean := false;  -- true when quitting
    DT     : ADialogTaskRecord; -- results of user input

  begin -- TIA Process

    SessionLog( "TIAProcess: TIA Process started" );

    OpenWindow( To255( "Debugger" ), 0, 1, DisplayInfo.H_Res-1,
      DisplayInfo.V_Res-1, normal, true );

    Init( StepButton, 1, 3, 10, 3, 's' );
    SetText( StepButton, "Step" );
    SetInstant( StepButton );
    SetInfo( StepButton, To255( "Execute until next source line" ) );
    AddControl( StepButton'unchecked_access );

    Init( StepIButton, 11, 3, 20, 3, 'i' );
    SetText( StepIButton, "StepI" );
    SetInstant( StepIButton );
    SetInfo( StepIButton, To255( "Execute until next instruction" ) );
    AddControl( StepIButton'unchecked_access );

    Init( NextButton, 21, 3, 30, 3, 'n' );
    SetText( NextButton, "Next" );
    SetInstant( NextButton );
    SetInfo( NextButton, To255( "Execute until next source line, run subroutines" ) );
    AddControl( NextButton'unchecked_access );

    Init( NextIButton, 31, 3, 40, 3, 'x' );
    SetText( NextIButton, "NextI" );
    SetInstant( NextIButton );
    SetInfo( NextIButton, To255( "Execute until next instruction, run subroutines" ) );
    AddControl( NextIButton'unchecked_access );

    Init( RunButton, 41, 3, 50, 3, 'r' );
    SetText( RunButton, "Run" );
    SetInstant( RunButton );
    SetInfo( RunButton, To255( "Execute program" ) );
    AddControl( RunButton'unchecked_access );

    Init( BreakButton, 51, 3, 60, 3, 'b' );
    SetText( BreakButton, "Break" );
    SetInstant( BreakButton );
    SetInfo( BreakButton, To255( "Add a break point" ) );
    AddControl( BreakButton'unchecked_access );

    Init( QuitButton, 61, 3, 70, 3, 'q' );
    SetText( QuitButton, "Quit" );
    SetInstant( QuitButton );
    SetInfo( QuitButton, To255( "Quit debugging" ) );
    AddControl( QuitButton'unchecked_access );

    Init( UntilButton, 1, 4, 10, 4, 'u' );
    SetText( UntilButton, "Until" );
    SetInstant( UntilButton );
    SetInfo( UntilButton,
      To255( "Execute until a source line greater than current" ) );
    AddControl( UntilButton'unchecked_access );

    Init( ContButton, 11, 4, 20, 4, 'o' );
    SetText( ContButton, "Cont" );
    SetInstant( ContButton );
    SetInfo( ContButton,
      To255( "Continue after stop, breakpoint, debugging" ) );
    AddControl( ContButton'unchecked_access );

    Init( FinishButton, 21, 4, 30, 4, 'f' );
    SetText( FinishButton, "Finish" );
    SetInstant( FinishButton );
    SetInfo( FinishButton,
      To255( "Execute until selected stack frame returns" ) );
    AddControl( FinishButton'unchecked_access );

    Init( RegButton, 31, 4, 40, 4, 'r' );
    SetText( RegButton, "Regs" );
    SetInstant( RegButton );
    SetInfo( RegButton,
      To255( "Show registers" ) );
    AddControl( RegButton'unchecked_access );

    Init( StackButton, 41, 4, 50, 4, 'k' );
    SetText( StackButton, "Stack" );
    SetInstant( StackButton );
    SetInfo( StackButton,
      To255( "Show stack contents" ) );
    AddControl( StackButton'unchecked_access );

    Init( ClearButton, 51, 4, 60, 4, 'c' );
    SetText( ClearButton, "Clear" );
    SetInstant( ClearButton );
    SetInfo( ClearButton,
      To255( "Delete break point" ) );
    AddControl( ClearButton'unchecked_access );

    Init( CmdLine, 1, 5, 65, 5 );
    SetText( CmdLine, NullStr255 );
    SetInfo( CmdLine, To255( "Debugger Command to do" ) );
    AddControl( CmdLine'unchecked_access );

    Init( DoButton, 67, 5, 79, 5, 'd' );
    SetText( DoButton, "Do" );
    SetInfo( DoButton, To255( "Do this debugger command" ) );
    AddControl( DoButton'unchecked_access );

    Init( GDBList, 1, 7, DisplayInfo.H_Res-2, DisplayInfo.V_Res-2 ); -- change
    SetInfo( GDBList, To255( "Do this debugger command" ) );
    AddControl( GDBList'unchecked_access );

    CheckGDBOutput;
    loop
      DoDialog( DT );
      case DT.control is
      when 1 => GDBCommand( "step" );
      when 2 => GDBCommand( "stepi" );
      when 3 => GDBCommand( "next" );
      when 4 => GDBCommand( "nexti" );
      when 5 => GDBCommand( "run" );
      when 6 => DoBreak;
      when 7 => Done := true;
      when 8 => GDBCommand( "until" );
      when 9 => GDBCommand( "cont" );
      when 10 => GDBCommand( "finish" );
      when 11 => GDBCommand( "info registers" );
      when 12 => GDBCommand( "info stack" );
      when 13 => DoClear;
      when 14 => null; -- cmd label
      when 15 => GDBCommand( ToString( GetText( CmdLine ) ) );
      when others => null;
      end case;
      exit when done;
    end loop;
    Write2Debugger( "Quit" & ASCII.LF & "y" );
    -- "y" in case prompted for it while program is running
    CloseWindow;
    SessionLog( "TIAProcess: waiting for debugger to finish" );
    Wait( wait_pid, wait_status );
    SessionLog( "TIAProcess: done" );
  end TIAProcess;

  procedure Debugger( file : Str255 ) is
     -- open the debugger window and run the debugger
     Result     : integer;
     Result2    : integer;
     DebugID    : integer;

  begin

    -- create pipes
    Pipe( Result, InputPipe );
    Pipe( Result2, OutputPipe );
    if Result /= 0 or Result2 /= 0 then
       Close( InputPipe(0) );
       Close( InputPipe(1) );
       Close( OutputPipe(0) );
       Close( OutputPipe(1) );
       SessionLog( "Debugger: unable to create pipes for debugger" );
       return;
    else
       SessionLog( "DebuggerProcess: InputPipe is " & InputPipe(0)'img & "/" &
         InputPipe(1)'img );
       SessionLog( "DebuggerProcess: OutputPipe is " & OutputPipe(0)'img & "/" &
         OutputPipe(1)'img );
    end if;

    DebugID := fork;
    -- create a new process. DebugID is 0 for the child process, and
    -- the child's pid for the parent process

    if DebugID < 0 then
       SessionLog( "Debugger: fork failed" );
    elsif DebugID = 0 then
       DebuggerProcess( ToString( file ) );
       SessionLog( "Debugger: debugger failed, should never get here" );
    else
       TIAProcess( DebugID );
       -- close pipes
       Close( InputPipe(0) );
       Close( InputPipe(1) );
       Close( OutputPipe(0) );
       Close( OutputPipe(1) );
    end if;

  end Debugger;

end tiadebug;
 
