# B2B signup attribution

This example records how an anonymous visitor from a marketing campaign becomes a customer of a B2B product: it records the visitor's landing page view with the campaign details, links the visitor's anonymous ID to the new user ID when they sign up, records the user's traits, and associates the user with their company.

## Prerequisites

- Ballerina Swan Lake 2201.12.x or later
- Push the connector to the local repository:
  ```bash
  cd ../../ballerina
  bal pack && bal push --repository=local
  ```
- Create a `Config.toml` in this directory:
  ```toml
  writeKey = "<your-source-write-key>"
  dataPlaneUrl = "https://<your-workspace>.dataplane.rudderstack.com"
  ```

## Run the example

```bash
bal run
```

Each call prints `ok` when RudderStack accepts the event. The events then show up in the source's **Live events** view in the RudderStack dashboard.
