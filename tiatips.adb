------------------------------------------------------------------------------
-- TIA TIPS - Startup tips for TIA                                          --
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

pragma optimize( space );
package body tiatips is

function GetTiaTip return str255 is
  Tip : Str255;
begin
   case Opt_TipNumber is

   -- Using TIA tips

   when  1=> Tip := To255( "Mark a line by clicking twice, Ctrl-6 or Mark in Edit Menu");
   when  2=> Tip := To255( "To copy multiple lines, mark first line, move to last, then copy");
   when  3=> Tip := To255( "To cut multiple lines, mark first line, move to last, then cut");
   when  4=> Tip := To255( "Press ESC to see the Texttools' accessories window");
   when  5=> Tip := To255( "Type Alt-A to add a comment to the end of a line");
   when  6=> Tip := To255( "Stats in File Menu displays stats about your source code");
   when  7=> Tip := To255( "The QuietUpdates option will reduce your project build time");
   when  8=> Tip := To255( "The Backup option can backup your project every 24 hours");
   when  9=> Tip := To255( "Use the scroll bar to quickly look through your source code");
   when 10=> Tip := To255( "Changing the project parameters may cause a full rebuild");
   when 11=> Tip := To255( "A wide display area will show the quick open buttons");
   when 12=> Tip := To255( "Stub in File Menu will create an Ada package body from a spec");
   when 13=> Tip := To255( "Alt-X or Edit/Next Error will show the next error" );
   when 14=> Tip := To255( "Profile in Project Menu will show performance statistics" );
   when 15=> Tip := To255( "Backup Now in Project Menu will immediately backup the project" );
   when 16=> Tip := To255( "You can email source code to a team member using TIA's Notepad" );
   when 17=> Tip := To255( "Keyboard macros can reduce repetitive typing" );
   when 18=> Tip := To255( "If you have wavplay installed, TIA can play sound effects" );
   when 19=> Tip := To255( "Use check in File Menu when you think you have syntax errors" );
   when 20=> Tip := To255( "TIA will automatically correct several common typos" );
   when 21=> Tip := To255( "Ctrl-L will redraw the screen" );

   -- More Tips

   when 22=> Tip := To255( "In Perl, file/check is the same as perl -wc");
   when 23=> Tip := To255( "In Ada, stronger debugging settings enforce Gnat checking switches");
   when 24=> Tip := To255( "In HTML, file/check is the same as running the tidy program");
   when 25=> Tip := To255( "In Ada, Assert/Debug pragmas won't appear with release debugging");
   when 26=> Tip := To255( "In C, file/check is the same as running gcc -c");
   when 27=> Tip := To255( "File/SaveAs will give the file a new name and add it to CVS");
   when 28=> Tip := To255( "In Ada, Pragma Suppress is always used with release debugging");
   when 29=> Tip := To255( "File/delete will delete the file and also remove it from CVS");
   when 30=> Tip := To255( "To use a debugger, you must use the prerelease debugging param");
   when 31=> Tip := To255( "Ada tools and libraries are available from www.gnuada.org");
   when 32=> Tip := To255( "Ada source code examples are available from www.adapower.org");
   when 33=> Tip := To255( "TIA's source code is available from www.pegasoft.ca");
   when 34=> Tip := To255( "In Ada, use new types to detect type mismatched assignments");
   when 35=> Tip := To255( "Perform a CVS commit by choosing Proj / Share Changes");
   when 36=> Tip := To255( "In Ada, use 'subtype' to rename long type names");
   when 37=> Tip := To255( "Pragma Pack will reduce the size of some data structures");
   when others => Tip := To255( "Thanks for using TIA");
   end case;

   Opt_TipNumber := Opt_TipNumber + 1;
   if Opt_TipNumber > 38 then
      Opt_TipNumber := 1;
   end if;
   return tip;
end GetTiaTip;


end tiatips;
 
