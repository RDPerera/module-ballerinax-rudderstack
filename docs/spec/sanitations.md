_Author_:  Dilan Perera \
_Created_: 2026/10/25 \
_Updated_: 2026/10/25 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the RudderStack OpenAPI specification.
RudderStack publishes no machine-readable specification for these APIs, so the specification was written from the
[HTTP API](https://www.rudderstack.com/docs/api/http-api/), [Activation API](https://www.rudderstack.com/docs/profiles/dev-docs/activation-api/)
and [Profiles API](https://www.rudderstack.com/docs/api/profiles-api/) documentation, and checked against the open-source
data plane ([rudder-server](https://github.com/rudderlabs/rudder-server)) and the live APIs.
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

The specification was first flattened and aligned (`bal openapi flatten` followed by `bal openapi align`), and then the following changes were made.

1. Add Ballerina names for the header parameters
- **Original**: The `AnonymousId` and `SentAt` header parameters had no Ballerina names.
- **Updated**: Added `x-ballerina-name: anonymousId` and `x-ballerina-name: sentAt`.
- **Reason**: Generates camelCase fields in the `*Headers` records. Added by `bal openapi align`.
<!-- auto-generated -->

2. Shorten the API description
- **Original**: `info.description` held the full notes of the specification author (hosts, authentication, error bodies, limits and availability).
- **Updated**: Replaced with a one-paragraph summary of the three APIs.
- **Reason**: `info.description` becomes the doc comment of the client class.

3. Rename generic and vague schemas
- **Original**: Flattening the `allOf` schemas created `IdentifyEventAllOf2`, `TrackEventAllOf2`, `PageEventAllOf2`, `ScreenEventAllOf2`, `GroupEventAllOf2`, `AliasEventAllOf2`, `BatchedEventAllOf2`, `SingleRequestAllOf2` and `BatchProfilesRequestAllOf2`. The Activation request schemas were named `SingleRequest` and `RequestBase`.
- **Updated**: Renamed to `IdentifyEventFields`, `TrackEventFields`, `PageEventFields`, `ScreenEventFields`, `GroupEventFields`, `AliasEventFields`, `BatchedEventFields`, `SingleProfileRequestFields` and `BatchProfilesRequestFields`, and `SingleRequest` and `RequestBase` to `SingleProfileRequest` and `ProfilesRequestBase`.
- **Reason**: Meaningful type names in the generated `types.bal`. `SingleProfileRequest` pairs with `BatchProfilesRequest`.

4. Rewrite and add descriptions
- **Original**: Several schemas, fields and operations had no description, and others described implementation notes (source file names and observation dates).
- **Updated**: Added user-facing descriptions to all schemas, fields, header parameters and operations.
- **Reason**: The descriptions become the doc comments of the generated types and functions.

5. Rename schemas and operations to human-friendly names
- **Original**: Generic schema names `Identifier`, `Task`, `DeleteResult`, `StartRequest`, `StartResponse`, `RunStatus` and `BatchProfiles`, the flattened context schemas `ContextApp`, `ContextLibrary`, `ContextCampaign` and `ContextExternalId`, and the operationIds `startRun` and `getRunStatus`.
- **Updated**: Renamed the schemas to `ProfileIdentifier`, `ProfilesRunTask`, `DeleteProfilesResult`, `StartProfilesRunRequest`, `StartProfilesRunResponse`, `ProfilesRunStatus`, `BatchProfilesResponse`, `AppInfo`, `LibraryInfo`, `CampaignInfo` and `ExternalId`, and the operationIds to `startProfilesRun` and `getProfilesRunStatus`.
- **Reason**: Names say what each type and operation is for. "Run" alone is ambiguous in a client that also sends events, and `Identifier` and `Task` are too generic to read well in user code.
- **Kept**: The Event Stream operationIds (`identify`, `track`, `page`, `screen`, `group`, `alias`, `batch`) and the event schema names (`Traits`, `Properties`, `Context`, `Integrations`) are RudderStack's own API terms, used by its SDKs and documentation, so they are unchanged.

## OpenAPI cli command

The following command generates the raw OpenAPI-derived client. The command should be executed from the repository root directory.

```bash
bal openapi -i docs/spec/openapi.json -o ballerina --mode client --license docs/license.txt --client-methods remote
```

Note: The license year is hardcoded to 2026, change if necessary.

### Post-generation step: rename the generated client class and connection config

The generated `client.bal` declares `public isolated client class Client` with a `public` `init` that takes a
`ConnectionConfig`. Rename the file to `ballerina/oas_client.bal`, the class to `GeneratedClient`, and make both the
class and its `init` module-private:

- `@display {label: "RudderStack"}` + `public isolated client class Client {` → `isolated client class GeneratedClient {`
- `public isolated function init(ConnectionConfig config,` → `isolated function init(GeneratedConnectionConfig config,`

In the generated `types.bal`, rename the generated connection config and make it module-private:

- `@display {label: "Connection Config"}` + `public type ConnectionConfig record {|` → `type GeneratedConnectionConfig record {|`

`utils.bal` is generated and used as-is.

`ballerina/client.bal` is a hand-written wrapper around `GeneratedClient` (see steps 6 and 7 below) and defines the
public `Client`, `ConnectionConfig`, `AuthConfig`, `Region` and `EventHeaders`. It is intentionally **not** regenerated.

6. Route each API to its own host and credential in a hand-written client
- **Change**: `ballerina/client.bal` is a hand-written wrapper (not generated) around the OpenAPI-generated
  `GeneratedClient`. It creates one `GeneratedClient` per API: the Event Stream client on the data plane URL
  (`serviceUrl`) with HTTP Basic auth, and the Activation and Profiles clients on the hosts of the configured
  `region` (or the `activationServiceUrl` and `profilesServiceUrl` overrides) with a Bearer token. Each operation is
  forwarded to the client of its API.
- **Reason**: The specification attaches the Activation and Profiles paths to their own hosts with path-level
  `servers`, and uses a different security scheme for them. `bal openapi` ignores path-level servers and generates a
  single client with a single base URL and credential, so a single generated client can't call all three APIs.
- **Write key**: The data plane reads the source write key from the HTTP Basic auth **username** and ignores the
  password (`writeKey, _, ok := r.BasicAuth()` in `gateway/handle_http_auth.go` of rudder-server). The Ballerina HTTP
  client rejects an empty password, so the wrapper sends the placeholder password `unused`. Users only set
  `auth.writeKey`.

7. Make the operations easier to use in the hand-written client
- **Single and batch profile operations**: The Activation API takes a single identity (`id`) or a batch (`ids`) on the
  same endpoint, so the generated `getProfiles` and `deleteProfiles` take a `SingleProfileRequest|BatchProfilesRequest`
  union and `getProfiles` returns a `Profile|BatchProfilesResponse` union that callers must test. The wrapper exposes
  `getProfile(SingleProfileRequest) returns Profile`, `getProfiles(BatchProfilesRequest) returns BatchProfilesResponse`,
  `deleteProfile(SingleProfileRequest)` and `deleteProfiles(BatchProfilesRequest)`, each with a precise type.
- **One header type for the Event Stream operations**: The generator creates a separate but identical header record
  for each of the seven Event Stream operations. The wrapper takes a single `EventHeaders` record in all of them.
- **Default `AnonymousId` header**: RudderStack asks for the `AnonymousId` header on every Event Stream request, as
  the data plane uses it as the per-user ordering key. For a single event, the wrapper sends the event's
  `anonymousId` as the header unless the caller sets one.
- **Generated types kept public**: The generated per-operation header records (`IdentifyHeaders` to `BatchHeaders`)
  and the `ProfilesRequest` and `ProfileResponse` unions are still public in `types.bal`, as the generated client's
  remote methods use them and Ballerina warns when a remote method exposes a module-private type. The wrapper's
  operations use `EventHeaders` and the single and batch request types instead.
- **Required data plane URL**: The specification's default server, `https://hosted.rudderlabs.com`, rejects the write
  keys of current workspaces with `401 invalid write key`. The wrapper's `serviceUrl` (the data plane URL) has no
  default, and initialization fails with a clear message when `auth.writeKey` is set without it.
