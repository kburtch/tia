------------------------------------------------------------------------------
-- TIA SVN - SVN interface for TIA                                          --
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

with common;
use common;

package tiasvn is --------------------------------------------------

-------------------------------------------------------
-- SVN Import                                        --
--                                                   --
-- Save a new project in the SVN repository using    --
-- "svn import".  The user is prompted for an import --
-- name.                                             --
-------------------------------------------------------

procedure SVNImport;


-------------------------------------------------------
-- SVN Commit                                        --
--                                                   --
-- Save changes to an existing project in the SVN    --
-- repository using "cvs commit".  The user is       --
-- prompted for submission comment.                  --
-------------------------------------------------------

procedure SVNCommit;

-------------------------------------------------------
-- CVS Update                                        --
--                                                   --
-- Merge recent changes in the project with the copy --
-- in the CVS repository using "cvs update".  The    --
-- changes are not committed.                        --
-------------------------------------------------------

procedure SVNUpdate;

-------------------------------------------------------
-- SVN Add                                           --
--                                                   --
-- Add the current source file to the project using  --
-- "svn add".                                        --
-------------------------------------------------------

procedure SVNAdd;

-------------------------------------------------------
-- SVN Log                                           --
--                                                   --
-- Show the SVN log for the current source file      --
-------------------------------------------------------

procedure SVNLog;

-------------------------------------------------------
-- SVN Diff                                           --
--                                                   --
-- Perform a SVN diff on the current source file     --
-------------------------------------------------------

procedure SVNDiff;

-------------------------------------------------------
-- SVN Remove                                        --
--                                                   --
-- Remove a file from the repository.                --
-------------------------------------------------------

procedure SVNRemove( RemovePath : str255 );

end tiasvn;

