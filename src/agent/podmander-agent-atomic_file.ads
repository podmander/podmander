--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package Podmander.Agent.Atomic_File is

   --  Atomically place Content at Path: write Path & ".tmp", then rename
   --  over Path. Leaves no partial file at Path if the write fails.
   --  Precondition: the directory containing Path must already exist.
   procedure Write (Path : String; Content : String);

end Podmander.Agent.Atomic_File;
