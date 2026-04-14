--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

package body Podmander.Messages is

   package Decoder_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Decoder_Access,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Decoders : Decoder_Maps.Map;

   procedure Register
     (Kind    : String;
      Decoder : Decoder_Access) is
   begin
      if Decoders.Contains (Kind) then
         raise Already_Registered with "kind already registered: " & Kind;
      end if;
      Decoders.Insert (Kind, Decoder);
   end Register;

   function Decode
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class
   is
      Kind : constant String := Msg.Pop_String;
   begin
      if Decoders.Contains (Kind) then
         return Decoders (Kind).all (Msg);
      end if;
      raise Decode_Error with "unknown message kind: " & Kind;
   end Decode;

end Podmander.Messages;
