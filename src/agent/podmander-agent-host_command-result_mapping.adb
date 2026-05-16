--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Agent.Host_Command.Result_Mapping is

   function To_Result_Code (Result : Command_Result) return RC.Result_Code is
   begin
      case Result.State is
         when Exited               =>
            if Result.Exit_Status = Host_Command.Success then
               return RC.Ok;
            else
               return RC.Failed;
            end if;

         when Error                =>
            return RC.Unavailable;

         when Crashed | Terminated =>
            return RC.Internal;
      end case;
   end To_Result_Code;

end Podmander.Agent.Host_Command.Result_Mapping;
