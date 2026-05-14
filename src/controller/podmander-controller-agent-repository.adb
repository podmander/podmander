--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;
with Ada.Exceptions;
with Ada.Strings.Unbounded;

package body Podmander.Controller.Agent.Repository is

   use Ada.Strings.Unbounded;
   use Podmander.Types;

   --  ISO 8601 conversion helpers
   --  Ada.Calendar.Formatting.Image returns "YYYY-MM-DD HH:MM:SS"

   function Time_To_ISO8601 (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Time_To_ISO8601;

   function ISO8601_To_Time (S : String) return Ada.Calendar.Time is
      Fixed : String (1 .. 19) := S (S'First .. S'First + 18);
   begin
      Fixed (11) := ' ';
      return Ada.Calendar.Formatting.Value (Fixed);
   end ISO8601_To_Time;

   --  State conversion (DB uses lowercase, Ada uses Mixed_Case)

   function State_To_String (State : Agent_State) return String is
   begin
      case State is
         when Registered   => return "registered";
         when Unresponsive => return "unresponsive";
         when Lost         => return "lost";
      end case;
   end State_To_String;

   function String_To_State (S : String) return Agent_State is
   begin
      if S = "registered" then return Registered;
      elsif S = "unresponsive" then return Unresponsive;
      elsif S = "lost" then return Lost;
      else raise Constraint_Error with "Invalid agent state: " & S;
      end if;
   end String_To_State;

   ---------------
   --  Register --
   ---------------

   procedure Register
     (DB    : in out DB_Handle;
      Agent : Podmander.Types.Agent_Info)
   is
      QH : Query_Handle := Prepare
        (DB, "INSERT INTO agents (name, node_id, state, last_seen) " &
             "VALUES (?, ?, ?, ?)");
   begin
      Bind_Text (QH, 1, To_String (Agent.Name));
      Bind_Text (QH, 2, To_String (Agent.Node_Id));
      Bind_Text (QH, 3, State_To_String (Agent.State));
      Bind_Text (QH, 4, Time_To_ISO8601 (Agent.Last_Seen));
      while Step (QH) loop
         null;  --  INSERT returns no rows
      end loop;
   end Register;

   -----------
   --  Touch --
   -----------

   procedure Touch
     (DB    : in out DB_Handle;
      Agent : Podmander.Types.Agent_Info)
   is
      QH : Query_Handle := Prepare
        (DB, "UPDATE agents SET last_seen = ? WHERE name = ?");
   begin
      Bind_Text (QH, 1, Time_To_ISO8601 (Agent.Last_Seen));
      Bind_Text (QH, 2, To_String (Agent.Name));
      while Step (QH) loop
         null;  --  UPDATE returns no rows
      end loop;
      if Changes (DB) = 0 then
         raise Database_Error with Format_Error
           ((Kind    => Not_Found,
             Message => To_Unbounded_String ("Agent not found: " &
               To_String (Agent.Name)),
             Code    => 0));
      end if;
   end Touch;

   ---------------
   --  Set_State --
   ---------------

   procedure Set_State
     (DB    : in out DB_Handle;
      Agent : Podmander.Types.Agent_Info)
   is
      QH : Query_Handle := Prepare
        (DB, "UPDATE agents SET state = ? WHERE name = ?");
   begin
      Bind_Text (QH, 1, State_To_String (Agent.State));
      Bind_Text (QH, 2, To_String (Agent.Name));
      while Step (QH) loop
         null;  --  UPDATE returns no rows
      end loop;
      if Changes (DB) = 0 then
         raise Database_Error with Format_Error
           ((Kind    => Not_Found,
             Message => To_Unbounded_String ("Agent not found: " &
               To_String (Agent.Name)),
             Code    => 0));
      end if;
   end Set_State;

   --------------
   --  Load_All --
   --------------

   function Load_All (DB : in out DB_Handle) return Agent_Maps.Map is
      QH  : Query_Handle := Prepare
        (DB, "SELECT name, node_id, state, last_seen FROM agents");
      Map : Agent_Maps.Map;
      Rec : Agent_Info;
   begin
      while Step (QH) loop
         Rec.Name      := To_Unbounded_String (Column_Text (QH, 0));
         Rec.Node_Id   := To_Unbounded_String (Column_Text (QH, 1));
         Rec.State     := String_To_State (Column_Text (QH, 2));
         Rec.Last_Seen := ISO8601_To_Time (Column_Text (QH, 3));
         Map.Insert (To_String (Rec.Name), Rec);
      end loop;
      return Map;
   end Load_All;

   -------------
   --  Remove --
   -------------

   procedure Remove
     (DB    : in out DB_Handle;
      Agent : Podmander.Types.Agent_Info) is
      QH : Query_Handle := Prepare
        (DB, "DELETE FROM agents WHERE name = ?");
   begin
      Bind_Text (QH, 1, To_String (Agent.Name));
      while Step (QH) loop
         null;  --  DELETE returns no rows
      end loop;
      --  No-op if agent does not exist — no error raised
   end Remove;

end Podmander.Controller.Agent.Repository;
