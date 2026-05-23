--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Heartbeats is

   use Ada.Strings.Unbounded;

   -- Agent -> Controller: periodic heartbeat
   type Heartbeat_Message is new Heartbeat_Message_Type with record
      Node_Id   : Unbounded_String;
      Timestamp : Ada.Calendar.Time;
   end record;

   overriding
   procedure Encode (Self : Heartbeat_Message; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To (Self : Heartbeat_Message; H : in out Message_Handler'Class);

end Podmander.Messages.Heartbeats;
