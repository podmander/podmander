--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.IO_Exceptions;
with Ada.Text_IO;
with CZMQ.Certificates;
with CZMQ.Messages;
with CZMQ.Sockets;
with Podmander.Enrollment;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Stack_Submissions;
with Podmander.Messages.Stack_Submission_Results;

package body Podmander.Podctl.Client is

   use type CZMQ.Messages.Receive_Status;

   function Check_TOML_File (Path : String) return File_Check is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return Empty;
      end if;
      Ada.Text_IO.Close (File);
      return Ok;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         return Not_Found;
   end Check_TOML_File;

   function Exit_Code_For (Outcome : Deploy_Outcome) return Integer is
   begin
      case Outcome is
         when Accepted    => return 0;
         when Token_Error => return 1;
         when File_Error  => return 2;
         when Timeout     => return 3;
         when Rejected    => return 4;
      end case;
   end Exit_Code_For;

   function Read_File (Path : String) return String is
      use Ada.Text_IO;
      File   : File_Type;
      Result : Unbounded_String;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Append (Result, Get_Line (File));
         Append (Result, ASCII.LF);
      end loop;
      Close (File);
      return To_String (Result);
   end Read_File;

   function Deploy
     (TOML_Path : String;
      Cfg       : Podmander.Podctl.Config.Connection_Config)
      return Deploy_Result
   is
      use Podmander.Enrollment;
      use Podmander.Messages.Stack_Submissions;
      use Podmander.Messages.Stack_Submission_Results;

      Parsed : Parsed_Token;
   begin
      begin
         Parsed := Parse_Join_Token (To_String (Cfg.Token));
      exception
         when Parse_Error =>
            return
              (Outcome => Token_Error,
               Message => To_Unbounded_String ("invalid join token format"));
      end;

      case Check_TOML_File (TOML_Path) is
         when Not_Found =>
            return
              (Outcome => File_Error,
               Message => To_Unbounded_String ("file not found: " & TOML_Path));
         when Empty =>
            return
              (Outcome => File_Error,
               Message => To_Unbounded_String ("file is empty: " & TOML_Path));
         when Ok =>
            null;
      end case;

      declare
         TOML_Content : constant String := Read_File (TOML_Path);
         Cert         : CZMQ.Certificates.Certificate;
         Sock         : CZMQ.Sockets.Socket;
         Result       : Deploy_Result :=
           (Outcome => Timeout,
            Message => To_Unbounded_String ("no reply from controller (timeout)"));
      begin
         CZMQ.Certificates.Generate (Cert);
         CZMQ.Sockets.Open_Dealer (Sock);
         Cert.Apply (Sock);
         Sock.Set_Curve_Serverkey (To_String (Parsed.Public_Key));
         Sock.Set_Identity ("podctl");
         Sock.Connect (To_String (Cfg.Controller));
         Sock.Set_Receive_Timeout (Reply_Timeout_Ms);

         declare
            Out_Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
            Sub     : constant Stack_Submission :=
              (TOML              => To_Unbounded_String (TOML_Content),
               Enrollment_Secret => Parsed.Secret);
         begin
            Sub.Encode (Out_Msg);
            Out_Msg.Send (Sock);
         end;

         declare
            use Podmander.Messages;
            In_Msg : CZMQ.Messages.Message;
            Status : CZMQ.Messages.Receive_Status;
         begin
            CZMQ.Messages.Receive (Sock, In_Msg, Status);
            if Status /= CZMQ.Messages.Timeout then
               begin
                  declare
                     Decoded : constant Protocol_Message'Class :=
                       Decode (In_Msg);
                  begin
                     if Decoded in Stack_Submission_Result then
                        declare
                           R : constant Stack_Submission_Result :=
                             Stack_Submission_Result (Decoded);
                        begin
                           if R.Success then
                              Result := (Outcome => Accepted, Message => R.Message);
                           else
                              Result := (Outcome => Rejected, Message => R.Message);
                           end if;
                        end;
                     else
                        Result :=
                          (Outcome => Rejected,
                           Message =>
                             To_Unbounded_String ("unexpected response from controller"));
                     end if;
                  end;
               exception
                  when Decode_Error =>
                     Result :=
                       (Outcome => Rejected,
                        Message =>
                          To_Unbounded_String ("malformed response from controller"));
               end;
            end if;
         end;

         CZMQ.Sockets.Close (Sock);
         CZMQ.Certificates.Close (Cert);
         return Result;
      exception
         when CZMQ.CZMQ_Error =>
            CZMQ.Sockets.Close (Sock);
            CZMQ.Certificates.Close (Cert);
            return
              (Outcome => Timeout,
               Message => To_Unbounded_String ("connection refused"));
      end;
   end Deploy;

end Podmander.Podctl.Client;
