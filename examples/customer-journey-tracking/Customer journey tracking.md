# Customer journey tracking

This example tracks a customer's journey through an online store with the Event Stream API: it identifies the customer, records the product page they view, then sends the add-to-cart and order events together in one batch. Every request carries the same `AnonymousId` header so that the data plane processes the customer's events in order.

## Prerequisites

- Ballerina Swan Lake 2201.12.x or later
- Push the connector to the local repository:
  ```bash
  cd ../../ballerina
  bal pack && bal push --repository=local
  ```
- Create a `Config.toml` in this directory:
  ```toml
  dataPlaneUrl = "https://<your-workspace>.dataplane.rudderstack.com"

  [auth]
  writeKey = "<your-source-write-key>"
  ```

## Run the example

```bash
bal run
```

Each call prints `ok` when RudderStack accepts the events. The events then show up in the source's **Live events** view in the RudderStack dashboard.
