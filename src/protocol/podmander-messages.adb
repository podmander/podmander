--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Podmander.Messages.JSON_Utils;

package body Podmander.Messages is

   package Decoder_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Decoder_Access,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

   Decoders    : Decoder_Maps.Map;
   Initialized : Boolean := False;

   procedure Register (Kind : String; Decoder : Decoder_Access) is
   begin
      if not Initialized then
         raise Program_Error
           with
             "Decoder registry not yet initialized; "
             & "missing pragma Elaborate(Podmander.Messages)?";
      end if;
      if Decoders.Contains (Kind) then
         raise Already_Registered with "kind already registered: " & Kind;
      end if;
      Decoders.Insert (Kind, Decoder);
   end Register;

   function Decode
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class
   is
      Raw    : constant String := Msg.Pop_String;
      Result : constant GNATCOLL.JSON.Read_Result := GNATCOLL.JSON.Read (Raw);
   begin
      if not Result.Success then
         raise Decode_Error with "malformed JSON in message";
      end if;

      declare
         Obj  : constant GNATCOLL.JSON.JSON_Value := Result.Value;
         Kind : constant String := JSON_Utils.Get_Kind (Obj);
      begin
         if Decoders.Contains (Kind) then
            return Decoders (Kind).all (Obj);
         end if;
         raise Decode_Error with "unknown message kind: " & Kind;
      end;
   end Decode;

begin
   Initialized := True;
end Podmander.Messages;
