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

with common;
use common;

package tiacvs is --------------------------------------------------

-------------------------------------------------------
-- CVS Import                                        --
--                                                   --
-- Save a new project in the CVS repository using    --
-- "cvs import".  The user is prompted for an import --
-- name.                                             --
-------------------------------------------------------

procedure CVSImport;


-------------------------------------------------------
-- CVS Commit                                        --
--                                                   --
-- Save changes to an existing project in the CVS    --
-- repository using "cvs commit".  The user is       --
-- prompted for submission comment.                  --
-------------------------------------------------------

procedure CVSCommit;

-------------------------------------------------------
-- CVS Update                                        --
--                                                   --
-- Merge recent changes in the project with the copy --
-- in the CVS repository using "cvs update".  The    --
-- changes are not committed.                        --
-------------------------------------------------------

procedure CVSUpdate;

-------------------------------------------------------
-- CVS Add                                           --
--                                                   --
-- Add the current source file to the project using  --
-- "cvs add".                                        --
-------------------------------------------------------

procedure CVSAdd;

-------------------------------------------------------
-- CVS Log                                           --
--                                                   --
-- Show the CVS log for the current source file      --
-------------------------------------------------------

procedure CVSLog;

-------------------------------------------------------
-- CVS Diff                                           --
--                                                   --
-- Perform a CVS diff on the current source file     --
-------------------------------------------------------

procedure CVSDiff;

-------------------------------------------------------
-- CVS Remove                                        --
--                                                   --
-- Remove a file from the repository.                --
-------------------------------------------------------

procedure CVSRemove( RemovePath : str255 );

end tiacvs;

