# Profile refresh and activation

This example refreshes the profiles of a RudderStack Profiles project and reads them: it starts a Profiles run, polls the run until it finishes, then fetches the refreshed profiles of a few customers from the Redis destination through the Activation API.

## Prerequisites

- Ballerina Swan Lake 2201.12.x or later
- A RudderStack Profiles project that syncs to a Redis destination (needed by the Activation API)
- A Service Access Token with **Edit** on the Profiles resource and **Destination Data Access** on the Redis destination
- Push the connector to the local repository:
  ```bash
  cd ../../ballerina
  bal pack && bal push --repository=local
  ```
- Create a `Config.toml` in this directory:
  ```toml
  serviceAccessToken = "<your-service-access-token>"
  region = "US"  # or "EU"
  profilesId = "<your-profiles-project-id>"
  destinationId = "<your-redis-destination-id>"
  userIds = ["u-1001", "u-1002"]
  ```

## Run the example

```bash
bal run
```
