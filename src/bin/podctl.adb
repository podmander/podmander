--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Podctl.Commands;
with Podmander.Podctl.Commands.Deploy;

procedure Podctl is
begin
   Podmander.Podctl.Commands.Instance.Register
     (new Podmander.Podctl.Commands.Instance.Builtin_Help);
   Podmander.Podctl.Commands.Instance.Register
     (new Podmander.Podctl.Commands.Deploy.Command);

   Podmander.Podctl.Commands.Instance.Parse_Global_Switches;
   Podmander.Podctl.Commands.Instance.Execute;
end Podctl;
