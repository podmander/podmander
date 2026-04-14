--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

package body Podmander.Shutdown is

   function Requested return Boolean is
      use type Interfaces.C.int;
   begin
      return Zsys_Interrupted /= 0;
   end Requested;

end Podmander.Shutdown;
