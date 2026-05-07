--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Aggregator that forces elaboration of every concrete message child
--  package. Consumers that need a fully-populated decoder registry
--  (controllers, test runners, anything calling Podmander.Messages.Decode)
--  should `with` this package; the individual children are still
--  `with`able directly when a consumer only needs one kind.

with Podmander.Messages.Deploy_Commands;
pragma Unreferenced (Podmander.Messages.Deploy_Commands);

with Podmander.Messages.Deploy_Results;
pragma Unreferenced (Podmander.Messages.Deploy_Results);

with Podmander.Messages.Heartbeats;
pragma Unreferenced (Podmander.Messages.Heartbeats);

with Podmander.Messages.Register_Requests;
pragma Unreferenced (Podmander.Messages.Register_Requests);

with Podmander.Messages.Register_Responses;
pragma Unreferenced (Podmander.Messages.Register_Responses);

with Podmander.Messages.Result_Codes;
pragma Unreferenced (Podmander.Messages.Result_Codes);

with Podmander.Messages.Status_Queries;
pragma Unreferenced (Podmander.Messages.Status_Queries);

with Podmander.Messages.Status_Responses;
pragma Unreferenced (Podmander.Messages.Status_Responses);

package Podmander.Messages.All_Kinds is
end Podmander.Messages.All_Kinds;
