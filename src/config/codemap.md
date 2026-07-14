# src/config/

## Responsibility

Configuration domain model and TOML parser for service input. This folder turns
operator-authored TOML, including Stack_Submission content received over the
wire, into Podmander's current Abstract Service Definition record and validates
the supported fields before generation or persistence.

## Design

- `Podmander.Config` defines the in-memory Abstract Service Definition as
  `Service_Definition`: service name, required image, bounded arrays for
  environment variables, port mappings, and volume mappings, plus Quadlet-facing
  `Description` and `WantedBy` fields.
- Arrays are fixed-capacity (`MAX_ENV_ENTRIES`, `MAX_PORTS_ENTRIES`,
  `MAX_VOLUMES_ENTRIES`) with explicit counts, avoiding dynamic container
  ownership in the service record.
- `Podmander.Config.Parser.Parse_Result` is a discriminated success/failure
  result. Success carries a full `Service_Definition`; failure carries an error
  message for CLI/controller responses.
- File and string parsing share `Extract_Service_Config`, so local deploys and
  Stack_Submission payloads obey the same TOML shape and validation rules.
- Port parsing supports both legacy string form (`HOST:CONTAINER`) and table
  form with integer `host` and `container` fields; volume parsing currently uses
  string `HOST:CONTAINER` entries.

## Flow

- `Parse(Path)` loads TOML from disk; `Parse_Content(Content)` loads TOML from a
  string received elsewhere. Both return formatted TOML parser errors on load
  failure.
- Successful TOML loading enters `Extract_Service_Config`, which requires a
  `[service]` table, selects the first service entry, requires an `image`, and
  accumulates optional `env`, `ports`, and `volumes` into the bounded arrays.
- Each add helper validates shape, type, range, and capacity before mutating the
  service record.
- `Validate` enforces cross-field constraints currently known to the Abstract
  Service Definition: image must be present and volume host/container paths must
  be non-empty.

## Integration

- CLI and controller paths use parsing results to accept or reject operator TOML;
  failures become user-facing error text or Stack_Submission results.
- The generator layer consumes successful `Service_Definition` values to render
  Quadlet `.container` content.
- Deployment flow uses the parsed Abstract Service Definition as the source of
  truth before a derived Quadlet is embedded into a Deployment_Command and later
  reported on through Deployment_Result.
