# Tests

The test suite covers all 13 operations of the RudderStack connector: the Event Stream operations (`identify`, `track`, `page`, `screen`, `group`, `alias`, `batch`), the Activation operations (`getProfile`, `getProfiles`, `deleteProfile`, `deleteProfiles`), and the Profiles operations (`startProfilesRun` with and without parameters, `getProfilesRunStatus`).

It also covers authentication and the connection config:

- The mock service checks credentials the way RudderStack does: the source write key as the HTTP Basic auth username on the data plane, and a Bearer Service Access Token on the Activation and Profiles APIs. It serves the three APIs under separate base paths, so a request sent to the wrong host or with the wrong credential fails.
- Invalid write keys and access tokens return `401`. A Profiles run that is already in progress returns `409`.
- The `AnonymousId` ordering header defaults to the event's `anonymousId` and is forwarded on batches: the mock service rejects a `track` event or a batch whose `anonymousId` doesn't match the header.
- The Activation and Profiles hosts are selected by `region` (US or EU) or by the URL overrides.
- A client created without credentials, with an empty credential, or with a write key but no data plane URL fails to initialize. Calling an operation whose credential isn't set returns an error that names the missing field.

## Running Tests

```bash
bal test
```

The test suite uses a mock server (`tests/mock_service.bal`) that intercepts HTTP calls so no real credentials are required.

To run the tests against the live RudderStack APIs instead, set the following environment variables:

```bash
export IS_LIVE_SERVER=true
export RUDDERSTACK_DATA_PLANE_URL=https://<your-workspace>.dataplane.rudderstack.com
export RUDDERSTACK_WRITE_KEY=<your-source-write-key>
export RUDDERSTACK_ACCESS_TOKEN=<your-access-token>
export RUDDERSTACK_REGION=US  # or EU
bal test --groups live_tests
```

The live tests call all 13 operations. The Event Stream tests send real events to the source and expect `ok`. The Activation and Profiles tests check that the access token is accepted: they target an unknown destination, project or run, and expect the API to reject the request with `400`, `403` or `404` rather than `401`. So they need no Profiles project or Redis destination.
