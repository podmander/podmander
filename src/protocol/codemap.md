# src/protocol/

## Responsibility

Wire-level domain contract shared by Podmander deliverables. It defines stable
types for nodes and agents plus JSON-over-CZMQ protocol messages used between
CLI/operator clients, the controller, and agents: registration, heartbeats,
Deployment_Command, Deployment_Result, status, Stack_Submission, and
Stack_Submission results.

## Design

- `Podmander` is the root pure package; `Podmander.Types` holds shared identity
  and state records such as `Node_Id_Type`, `Agent_Info`, and `Agent_Maps`.
- `Podmander.Messages` is the protocol spine. `Protocol_Message` is an
  interface with `Encode` and `Dispatch_To`; `Message_Handler` is a visitor-like
  interface with one `Handle_*` operation per abstract message category.
- Concrete message packages derive from abstract anchors in the parent package.
  Each concrete type owns JSON encoding, decoding, and dispatch, but no handling
  policy.
- Decoding is registry-based. Child packages register decoder functions by JSON
  `kind` during elaboration; `Podmander.Messages.All_Kinds` forces elaboration
  of all known message packages for consumers that call the generic decoder.
- `JSON_Utils` centralizes field extraction, `kind` handling, timestamp
  formatting, and `Result_Code` string conversion so concrete messages share the
  same Decode_Error behavior.

## Flow

- To send, a caller constructs a concrete message, calls `Encode`, and the
  message appends one JSON string frame to a `CZMQ.Messages.Message`.
- To receive, a caller withs `Podmander.Messages.All_Kinds`, calls
  `Podmander.Messages.Decode`, and the parent parses the JSON frame, reads its
  `kind`, looks up the registered decoder, and returns a class-wide
  `Protocol_Message`.
- The receiver calls `Dispatch_To`; the concrete message invokes the matching
  handler operation, such as `Handle_Deployment_Command` or
  `Handle_Stack_Submission`, keeping routing separate from business logic.
- Deployment_Command carries `catalog_id`, `service_name`, and rendered Quadlet
  text from controller to agent. Deployment_Result echoes `catalog_id`, reports
  a `Result_Code`, and carries service/error details back to the controller.
- Stack_Submission carries TOML and an enrollment secret from an operator path to
  the controller; Stack_Submission_Result reports acceptance or failure text.

## Integration

- The controller implements `Message_Handler` behavior for inbound agent and CLI
  messages and emits Deployment_Command, status, registration, and
  Stack_Submission results.
- Agents decode controller commands, write Quadlets through the execution path,
  and encode Deployment_Result, registration, heartbeat, and status messages.
- The CLI/operator path uses Stack_Submission messages to submit TOML Abstract
  Service Definition input to the controller and receives the controller's
  submission result.
- The `catalog_id` field links protocol deployment traffic to Service Catalog
  rows so Deployment_Result correlation does not depend on service and node name
  lookups.
