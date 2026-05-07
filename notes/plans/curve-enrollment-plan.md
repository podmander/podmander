# CURVE Enrollment Implementation Plan

**Requirements:** [curve-enrollment-requirements.md](curve-enrollment-requirements.md)
**Date:** 2026-04-15

## High-Level Architecture

```
Controller                              Agent
-----------                             -----
 CZMQ.Sockets.ROUTER           <----    CZMQ.Sockets.DEALER
 + CZMQ.Certificates (server)            + CZMQ.Certificates (client)
 + Set_Curve_Server (True)              + Set_Curve_Serverkey (controller pubkey)
 + stores enrollment secret             + Apply (agent cert)
                                           + connects to controller address

Join Token format: PTKN-<40-char-z85-pubkey>-<32-char-hex-secret>
```

## Implementation Units

### Unit 1: Controller Certificate Management

**Goal:** Controller generates CURVE certificate on init and configures socket for CURVE server mode.

**Requirements trace:** R1, R4

**Dependencies:** None

**Files:**
- `src/controller/podmander-controller.ads` — add Certificate field to Controller_Instance
- `src/controller/podmander-controller.adb` — initialize certificate, apply to socket, set server mode
- `src/controller/podmander-controller-config.ads` — add enrollment secret storage to Config
- `src/controller/podmander-controller-config.adb` —

**Approach:**
1. Add `CZMQ.Certificates.Certificate` field to `Controller_Instance`
2. In `Initialize`: create certificate with `CZMQ.Certificates.New_Certificate`, apply to socket with `Apply`, call `Set_Curve_Server (True)`
3. Add enrollment secret field to `Controller_Config`
4. Add `Set_Enrollment_Secret` and `Get_Enrollment_Secret` procedures

**Patterns:** Follow existing limited controlled pattern from CZMQ.Sockets

**Test scenarios:**
- [ ] Controller initializes without error when czmq_ada is available
- [ ] Certificate public key is 40 Z85 characters
- [ ] Certificate secret key is 40 Z85 characters
- [ ] Socket is in CURVE server mode after initialization

**Verification:** Controller starts and prints CURVE certificate public key for token generation.

**Planning-time unknowns:** None

---

### Unit 2: Join Token Generation

**Goal:** Generate printable join token containing controller public key and enrollment secret.

**Requirements trace:** R2, R6

**Dependencies:** Unit 1

**Files:**
- `src/controller/podmander-controller-token_gen.ads` — token generation interface
- `src/controller/podmander-controller-token_gen.adb` — token generation implementation

**Approach:**
1. Format: `PTKN-<z85-controller-pubkey>-<hex-enrollment-secret>`
2. Enrollment secret: 32 hex chars (128 bits from Ada.Numerics.Discrete_Random)
3. Function `Generate_Join_Token` returns formatted string
4. Function `Get_Public_Key` exposes certificate public key for external use

**Patterns:** Pure function with no side effects for testability

**Test scenarios:**
- [ ] Token starts with "PTKN-"
- [ ] Token contains exactly one hyphen separator after prefix
- [ ] Public key section is exactly 40 Z85 characters
- [ ] Secret section is exactly 32 hex characters
- [ ] Same inputs produce same token (deterministic for testing)

**Verification:** Token is generated and displayed on controller startup.

**Planning-time unknowns:** None

---

### Unit 3: Agent CURVE Setup

**Goal:** Agent parses join token, generates certificate, configures socket as CURVE client.

**Requirements trace:** R3, R5

**Dependencies:** None (parallel with Unit 1)

**Files:**
- `src/agent/podmander-agent.ads` — add Join_Token field to Agent_Config
- `src/agent/podmander-agent.adb` — parse token, create certificate, apply to socket
- `src/agent/podmander-agent-token.ads` — token parsing interface
- `src/agent/podmander-agent-token.adb` — token parsing implementation

**Approach:**
1. Add `Join_Token` field to `Agent_Config`
2. Create `Parse_Join_Token` function: extract pubkey ( chars 5-44) and secret (chars 46-77)
3. In `Create_Socket`: generate agent certificate, apply to socket, set server key to controller pubkey from token
4. Validate token format before attempting connection

**Patterns:** Validation-first pattern (fail early on malformed input)

**Test scenarios:**
- [ ] Valid token parses to correct pubkey and secret
- [ ] Token without "PTKN-" prefix raises Parse_Error
- [ ] Token with wrong-length pubkey raises Parse_Error
- [ ] Token with wrong-length secret raises Parse_Error
- [ ] Agent socket is configured with correct server key after Parse_Join_Token

**Verification:** Agent connects to controller using valid token.

**Planning-time unknowns:** None

---

### Unit 4: Enrollment Secret Validation

**Goal:** Controller validates enrollment secret before completing agent registration.

**Requirements trace:** R7

**Dependencies:** Unit 1, Unit 2

**Files:**
- `src/controller/podmander-controller-message_handlers.adb` — add enrollment validation to Handle_Register_Request

**Approach:**
1. Add enrollment secret to Register_Request message (include secret in the message payload)
2. In `Handle_Register_Request`: compare submitted secret with stored secret
3. If mismatch: log warning, do not add agent to map, do not send Registered response
4. If match: proceed with normal registration

**Patterns:** Existing handler pattern with explicit error logging

**Test scenarios:**
- [ ] Agent with correct secret completes registration
- [ ] Agent with incorrect secret does not complete registration
- [ ] Agent with missing secret does not complete registration
- [ ] Controller logs warning on invalid secret

**Verification:** Agent without valid secret cannot connect.

**Planning-time unknowns:**
- Should we ban agents that repeatedly fail validation? — Deferred to future enhancement

---

## Quality Bar Checklist

- [ ] Every unit has a requirements trace
- [ ] Dependencies form a DAG (no cycles)
- [ ] Every unit has at least 3 test scenarios
- [ ] No unit touches >8 files (Units 1-4 each touch 2-4 files)
- [ ] No more than 2 new abstractions introduced per unit
- [ ] Every planning-time unknown is classified as blocker or deferred
- [ ] Handoff completeness test: a competent engineer can implement from this plan without inventing behavior

## Outstanding Questions (from requirements)

| # | Question | Resolution |
|---|----------|------------|
| Q1 | Plaintext vs hashed enrollment secret on controller? | Store plaintext for validation. Accept risk for initial implementation. |
| Q2 | Agent blocklist for revocation? | Not in scope for initial implementation. |

---

## Test Coverage Goal

```
Controller side:
  - Certificate generation (Unit 1)
  - Token generation (Unit 2)
  - Enrollment validation (Unit 4)

Agent side:
  - Token parsing (Unit 3)
  - Socket configuration (Unit 3)
  - End-to-end enrollment flow
```