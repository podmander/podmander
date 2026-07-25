--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;

package Podmander.Config is

   use Ada.Strings.Unbounded;

   MAX_ENV_ENTRIES         : constant := 100;
   MAX_PORTS_ENTRIES       : constant := 100;
   MAX_NAMED_PORTS_ENTRIES : constant := 100;
   MAX_VOLUMES_ENTRIES     : constant := 100;

   MIN_PORT : constant := 1;
   MAX_PORT : constant := 65535;

   subtype Port_Number is Positive range MIN_PORT .. MAX_PORT;

   type String_Array is array (Positive range <>) of Unbounded_String;

   type Port_Mapping is record
      Host      : Port_Number;
      Container : Port_Number;
   end record;

   type Port_Array is array (Positive range <>) of Port_Mapping;

   type Named_Port_Mapping is record
      Name      : Unbounded_String;
      Host      : Port_Number;
      Container : Port_Number;
   end record;

   type Named_Port_Array is array (Positive range <>) of Named_Port_Mapping;

   type Ingress_Definition is record
      Host      : Unbounded_String;
      Port_Name : Unbounded_String;
   end record;

   type Env_Entry is record
      Key   : Unbounded_String;
      Value : Unbounded_String;
   end record;

   type Env_Array is array (Positive range <>) of Env_Entry;

   type Volume_Mapping is record
      Host      : Unbounded_String;
      Container : Unbounded_String;
   end record;

   type Volume_Array is array (Positive range <>) of Volume_Mapping;

   type Service_Definition is record
      Service_Name      : Unbounded_String;
      Image             : Unbounded_String;
      Env               : Env_Array (1 .. MAX_ENV_ENTRIES);
      Env_Count         : Natural := 0;
      Ports             : Port_Array (1 .. MAX_PORTS_ENTRIES);
      Ports_Count       : Natural := 0;
      Named_Ports       : Named_Port_Array (1 .. MAX_NAMED_PORTS_ENTRIES) :=
        [others =>
           (Name      => Null_Unbounded_String,
            Host      => Port_Number'First,
            Container => Port_Number'First)];
      Named_Ports_Count : Natural := 0;
      Ingress           : Ingress_Definition :=
        (Host => Null_Unbounded_String, Port_Name => Null_Unbounded_String);
      Volumes           : Volume_Array (1 .. MAX_VOLUMES_ENTRIES);
      Volumes_Count     : Natural := 0;
      Description       : Unbounded_String;
      WantedBy          : Unbounded_String;
   end record;

end Podmander.Config;
