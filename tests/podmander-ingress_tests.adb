--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Config.Parser;
with Podmander.Controller;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Stack_Submission;
with Podmander.Database;
with Podmander.Generators.Quadlet;

package body Podmander.Ingress_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package Parser renames Podmander.Config.Parser;
   package DB renames Podmander.Database;
   package Repo renames Podmander.Controller.Service.Repository;
   package Submission renames Podmander.Controller.Stack_Submission;

   type Forgejo_205_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Forgejo_205_Test) return AUnit.Message_String
   is (AUnit.Format ("Forgejo issue #205 ingress acceptance"));

   overriding
   procedure Register_Tests (T : in out Forgejo_205_Test);

   function Valid_Ingress_TOML (Service : String := "web") return String is
   begin
      return
        "[service."
        & Service
        & "]"
        & ASCII.LF
        & "image = ""nginx:latest"""
        & ASCII.LF
        & "ports = { http = { host = 8080, container = 80 }, metrics = { host = 9090, container = 9090 } }"
        & ASCII.LF
        & "[service."
        & Service
        & ".ingress]"
        & ASCII.LF
        & "host = ""WWW.Example.COM"""
        & ASCII.LF
        & "port = ""http"""
        & ASCII.LF;
   end Valid_Ingress_TOML;

   procedure Assert_Parse_Fails (Content : String; Message : String) is
      Result : constant Parser.Parse_Result := Parser.Parse_Content (Content);
   begin
      Assert (not Result.Success, Message);
   end Assert_Parse_Fails;

   procedure Assert_Parse_Fails_With
     (Content : String; Expected : String; Context : String)
   is
      Result : constant Parser.Parse_Result := Parser.Parse_Content (Content);
   begin
      Assert (not Result.Success, Context);
      if not Result.Success then
         Assert (To_String (Result.Message) = Expected, Context & ": message");
      end if;
   end Assert_Parse_Fails_With;

   procedure Test_Named_Ports_And_Ingress_Parse
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Parser.Parse_Result :=
        Parser.Parse_Content (Valid_Ingress_TOML);
   begin
      Assert (Result.Success, "named ports and ingress should parse");
      if Result.Success then
         Assert
           (Result.Config.Named_Ports_Count = 2, "both named ports parse");
         Assert
           (To_String (Result.Config.Named_Ports (1).Name) = "http",
            "first named port name is retained");
         Assert
           (Result.Config.Named_Ports (1).Host = 8080,
            "named port host mapping is exact");
         Assert
           (Result.Config.Named_Ports (1).Container = 80,
            "named port container mapping is exact");
         Assert
           (To_String (Result.Config.Ingress.Host) = "www.example.com",
            "valid DNS hostname is lowercased");
         Assert
           (To_String (Result.Config.Ingress.Port_Name) = "http",
            "ingress retains its named port reference");
      end if;
   end Test_Named_Ports_And_Ingress_Parse;

   procedure Test_Legacy_Array_Without_Ingress_Remains_Valid
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Parser.Parse_Result :=
        Parser.Parse_Content
          ("[service.web]"
           & ASCII.LF
           & "image = ""nginx:latest"""
           & ASCII.LF
           & "ports = [""8080:80"", { host = 9090, container = 9090 }]"
           & ASCII.LF);
   begin
      Assert
        (Result.Success, "legacy array ports remain valid without ingress");
      if Result.Success then
         Assert (Result.Config.Ports_Count = 2, "legacy ports are retained");
      end if;
   end Test_Legacy_Array_Without_Ingress_Remains_Valid;

   procedure Test_Unknown_Fields_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Parse_Fails
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { http = { host = 8080, container = 80, extra = 1 } }"
         & ASCII.LF,
         "unknown named-port fields must be rejected");
      Assert_Parse_Fails
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { http = { host = 8080, container = 80 } }"
         & ASCII.LF
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.com"""
         & ASCII.LF
         & "port = ""http"""
         & ASCII.LF
         & "unexpected = true"
         & ASCII.LF,
         "unknown ingress fields must be rejected");
   end Test_Unknown_Fields_Are_Rejected;

   procedure Test_Missing_Ingress_Fields_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Prefix : constant String :=
        "[service.web]"
        & ASCII.LF
        & "image = ""nginx:latest"""
        & ASCII.LF
        & "ports = { http = { host = 8080, container = 80 } }"
        & ASCII.LF;
   begin
      Assert_Parse_Fails_With
        (Prefix
         & "[service.web.ingress]"
         & ASCII.LF
         & "port = ""http"""
         & ASCII.LF,
         "Invalid ingress: missing host",
         "missing ingress host must be rejected");
      Assert_Parse_Fails_With
        (Prefix
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.com"""
         & ASCII.LF,
         "Invalid ingress: missing port",
         "missing ingress port must be rejected");
   end Test_Missing_Ingress_Fields_Are_Rejected;

   procedure Test_Invalid_Hostnames_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Hosts : constant array (Positive range 1 .. 8) of Unbounded_String :=
        [To_Unbounded_String ("example.com/route"),
         To_Unbounded_String ("https://example.com"),
         To_Unbounded_String ("example.com:443"),
         To_Unbounded_String ("example.com/path"),
         To_Unbounded_String ("*.example.com"),
         To_Unbounded_String ("127.0.0.1"),
         To_Unbounded_String ("example.-com"),
         To_Unbounded_String ("example.com.")];
   begin
      for Host of Hosts loop
         Assert_Parse_Fails
           ("[service.web]"
            & ASCII.LF
            & "image = ""nginx:latest"""
            & ASCII.LF
            & "ports = { http = { host = 8080, container = 80 } }"
            & ASCII.LF
            & "[service.web.ingress]"
            & ASCII.LF
            & "host = """
            & To_String (Host)
            & """"
            & ASCII.LF
            & "port = ""http"""
            & ASCII.LF,
            "malformed ingress hostname must be rejected");
      end loop;
      Assert_Parse_Fails_With
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { http = { host = 8080, container = 80 } }"
         & ASCII.LF
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.-com"""
         & ASCII.LF
         & "port = ""http"""
         & ASCII.LF,
         "Invalid ingress host 'example.-com': expected DNS hostname",
         "final-label-leading-hyphen diagnostic must be precise");
   end Test_Invalid_Hostnames_Are_Rejected;

   procedure Test_Ingress_Cannot_Reference_Legacy_Or_Unknown_Ports
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Prefix : constant String :=
        "[service.web]" & ASCII.LF & "image = ""nginx:latest""" & ASCII.LF;
   begin
      Assert_Parse_Fails
        (Prefix
         & "ports = [""8080:80""]"
         & ASCII.LF
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.com"""
         & ASCII.LF
         & "port = ""http"""
         & ASCII.LF,
         "ingress must not reference legacy array ports");
      Assert_Parse_Fails
        (Prefix
         & "ports = { http = { host = 8080, container = 80 } }"
         & ASCII.LF
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.com"""
         & ASCII.LF
         & "port = ""missing"""
         & ASCII.LF,
         "ingress must not reference an unknown named port");
   end Test_Ingress_Cannot_Reference_Legacy_Or_Unknown_Ports;

   procedure Test_Named_Port_Map_Shape_Is_Strict
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Prefix : constant String :=
        "[service.web]" & ASCII.LF & "image = ""nginx:latest""" & ASCII.LF;
   begin
      Assert_Parse_Fails
        (Prefix & "ports = { http = 8080 }" & ASCII.LF,
         "the old scalar named-port shorthand must be rejected");
      Assert_Parse_Fails
        (Prefix & "ports = { http = { container = 80 } }" & ASCII.LF,
         "named port mappings require host");
      Assert_Parse_Fails
        (Prefix & "ports = { http = { host = 8080 } }" & ASCII.LF,
         "named port mappings require container");
      Assert_Parse_Fails
        (Prefix
         & "ports = { http = { host = ""8080"", container = 80 } }"
         & ASCII.LF,
         "named port host must be an integer");
      Assert_Parse_Fails
        (Prefix
         & "ports = { http = { host = 8080, container = ""80"" } }"
         & ASCII.LF,
         "named port container must be an integer");
      Assert_Parse_Fails
        (Prefix
         & "ports = { http = { host = 65536, container = 80 } }"
         & ASCII.LF,
         "named port host must be in range");
      Assert_Parse_Fails
        (Prefix
         & "ports = { http = { host = 8080, container = 0 } }"
         & ASCII.LF,
         "named port container must be in range");
   end Test_Named_Port_Map_Shape_Is_Strict;

   procedure Test_Candidate_Duplicate_Host_Ports_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Content : constant String :=
        "[service.web]"
        & ASCII.LF
        & "image = ""nginx:latest"""
        & ASCII.LF
        & "ports = { http = { host = 8080, container = 80 },"
        & " admin = { host = 8080, container = 8081 } }"
        & ASCII.LF;
   begin
      Assert_Parse_Fails_With
        (Content,
         "Duplicate host port 8080 in candidate service version",
         "candidate duplicate host ports must be rejected precisely");
   end Test_Candidate_Duplicate_Host_Ports_Are_Rejected;

   procedure Test_Invalid_Names_Mappings_And_References_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Parse_Fails
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { ""bad.name"" = { host = 8080, container = 80 } }"
         & ASCII.LF,
         "invalid named-port names must be rejected");
      Assert_Parse_Fails
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { http = { host = 0, container = 80 } }"
         & ASCII.LF,
         "invalid named-port mappings must be rejected");
      Assert_Parse_Fails
        ("[service.web]"
         & ASCII.LF
         & "image = ""nginx:latest"""
         & ASCII.LF
         & "ports = { http = { host = 8080, container = 80 } }"
         & ASCII.LF
         & "[service.web.ingress]"
         & ASCII.LF
         & "host = ""example.com"""
         & ASCII.LF
         & "port = ""missing"""
         & ASCII.LF,
         "ingress references to unknown ports must be rejected");
   end Test_Invalid_Names_Mappings_And_References_Are_Rejected;

   procedure Test_Ingress_Port_Is_Loopback_Bound
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Parser.Parse_Result :=
        Parser.Parse_Content (Valid_Ingress_TOML);
   begin
      Assert (Result.Success, "ingress fixture should parse for rendering");
      if Result.Success then
         declare
            Output : constant String :=
              Podmander.Generators.Quadlet.Render (Result.Config);
         begin
            Assert
              (Ada.Strings.Fixed.Index
                 (Output, "PublishPort=127.0.0.1:8080:80")
               > 0,
               "ingress named port must be published on loopback");
            Assert
              (Ada.Strings.Fixed.Index (Output, "PublishPort=9090:9090") > 0,
               "unrelated named ports must remain publicly bound");
         end;
      end if;
   end Test_Ingress_Port_Is_Loopback_Bound;

   procedure Test_Ingress_And_Named_Ports_Persist
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Result  : constant Submission.Submission_Result :=
        Submission.Submit (D, Valid_Ingress_TOML);
      Service : constant Podmander.Controller.Service.Service :=
        Repo.Get_By_Name (D, "web");
      Version : constant Podmander.Controller.Service_Version :=
        Repo.Get_Version (D, Service.Id, 1);
   begin
      Assert (Result.Ok, "valid ingress submission should succeed");
      Assert
        (Version.Named_Ports_Count = 2,
         "named ports persist in service versions");
      Assert
        (To_String (Version.Named_Ports (1).Name) = "http",
         "persisted named port name is observable");
      Assert
        (To_String (Version.Ingress.Host) = "www.example.com",
         "persisted ingress hostname is observable");
      Assert
        (To_String (Version.Ingress.Port_Name) = "http",
         "persisted ingress port reference is observable");
   end Test_Ingress_And_Named_Ports_Persist;

   procedure Test_Cross_Service_Conflicts_And_Own_Retention
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D          : DB.DB_Handle := DB.Open (":memory:");
      First      : constant Submission.Submission_Result :=
        Submission.Submit (D, Valid_Ingress_TOML);
      Same_Host  : constant Submission.Submission_Result :=
        Submission.Submit (D, Valid_Ingress_TOML ("api"));
      Same_Port  : constant Submission.Submission_Result :=
        Submission.Submit
          (D,
           "[service.other]"
           & ASCII.LF
           & "image = ""redis:latest"""
           & ASCII.LF
           & "ports = { cache = { host = 8080, container = 6379 } }"
           & ASCII.LF);
      Retain_Own : constant Submission.Submission_Result :=
        Submission.Submit (D, Valid_Ingress_TOML);
   begin
      Assert (First.Ok, "first service should submit");
      Assert
        (not Same_Host.Ok, "hostname conflicts across services are rejected");
      Assert
        (To_String (Same_Host.Message)
         = "Ingress host 'www.example.com' is already reserved by service 'web'",
         "hostname reservation error is precise");
      Assert (not Same_Port.Ok, "published host-port conflicts are rejected");
      Assert
        (To_String (Same_Port.Message)
         = "Host port '8080' is already reserved by service 'web'",
         "host-port reservation error is precise");
      Assert (Retain_Own.Ok, "a service may retain its own hostname and port");
   end Test_Cross_Service_Conflicts_And_Own_Retention;

   overriding
   procedure Register_Tests (T : in out Forgejo_205_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Named_Ports_And_Ingress_Parse'Access,
         "parse named ports and lower-case ingress");
      Register_Routine
        (T,
         Test_Legacy_Array_Without_Ingress_Remains_Valid'Access,
         "retain legacy array ports without ingress");
      Register_Routine
        (T,
         Test_Unknown_Fields_Are_Rejected'Access,
         "reject unknown named-port and ingress fields");
      Register_Routine
        (T,
         Test_Invalid_Hostnames_Are_Rejected'Access,
         "reject malformed ingress hostnames");
      Register_Routine
        (T,
         Test_Missing_Ingress_Fields_Are_Rejected'Access,
         "reject missing ingress host and port with exact errors");
      Register_Routine
        (T,
         Test_Ingress_Cannot_Reference_Legacy_Or_Unknown_Ports'Access,
         "reject legacy and unknown ingress port references");
      Register_Routine
        (T,
         Test_Named_Port_Map_Shape_Is_Strict'Access,
         "reject shorthand and malformed named-port mappings");
      Register_Routine
        (T,
         Test_Candidate_Duplicate_Host_Ports_Are_Rejected'Access,
         "reject duplicate candidate host ports precisely");
      Register_Routine
        (T,
         Test_Invalid_Names_Mappings_And_References_Are_Rejected'Access,
         "reject invalid names mappings and references");
      Register_Routine
        (T,
         Test_Ingress_Port_Is_Loopback_Bound'Access,
         "bind ingress ports to loopback only");
      Register_Routine
        (T,
         Test_Ingress_And_Named_Ports_Persist'Access,
         "persist named ports and ingress");
      Register_Routine
        (T,
         Test_Cross_Service_Conflicts_And_Own_Retention'Access,
         "enforce cross-service conflicts and own retention");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Forgejo_205_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Ingress_Tests;
