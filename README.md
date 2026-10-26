# Ballerina RudderStack connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerinax-rudderstack/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerinax-rudderstack)
[![Security Scan](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/security-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/security-scan.yml)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-rudderstack/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-rudderstack.svg)](https://github.com/ballerina-platform/module-ballerinax-rudderstack/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/rudderstack.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Frudderstack)

## Overview

[RudderStack](https://www.rudderstack.com/) is a customer data platform that collects customer events from websites, apps and servers, routes them to warehouses and business tools, and builds unified customer profiles from them.

The `ballerinax/rudderstack` connector offers APIs to connect and interact with three RudderStack APIs:

- The [Event Stream (HTTP) API](https://www.rudderstack.com/docs/api/http-api/), to send `identify`, `track`, `page`, `screen`, `group`, `alias` and batched events.
- The [Activation API](https://www.rudderstack.com/docs/profiles/dev-docs/activation-api/) (Beta), to read and delete the profiles that RudderStack Profiles materialises in a Redis destination.
- The [Profiles API](https://www.rudderstack.com/docs/api/profiles-api/), to start a Profiles project run and check its status.

The APIs are served from different hosts and use different credentials. A single `rudderstack:Client` handles all three: it sends the Event Stream operations to your data plane with the source write key, and the Activation and Profiles operations to the hosts of your workspace's region with a Service Access Token.

| Operations | Credential | Host |
|---|---|---|
| `identify`, `track`, `page`, `screen`, `group`, `alias`, `batch` | Source write key (`auth.writeKey`) | Your data plane URL (`serviceUrl`) |
| `getProfile`, `getProfiles`, `deleteProfile`, `deleteProfiles` | Service Access Token (`auth.serviceAccessToken`) | `profiles.rudderstack.com` (US) or `profiles-eu.rudderstack.com` (EU) |
| `startProfilesRun`, `getProfilesRunStatus` | Service Access Token (`auth.serviceAccessToken`) | `api.rudderstack.com` (US) or `api.eu.rudderstack.com` (EU) |

Set only the credentials of the APIs you call. For example, a client that only sends events needs only the write key and the data plane URL, and a client that only reads profiles needs only the Service Access Token.

### Key features

- Send `identify`, `track`, `page`, `screen`, `group` and `alias` events, one at a time or several in one `batch` call.
- Use one client for all three APIs. It sends each operation to the right host with the right credential.
- Keep a user's events in order with the `AnonymousId` header, which the client fills in from each event's `anonymousId`.
- Read one profile (`getProfile`) or up to 100 (`getProfiles`), and delete them (`deleteProfile`, `deleteProfiles`).
- Start a Profiles project run (`startProfilesRun`) and poll it until it finishes (`getProfilesRunStatus`).
- Switch the Activation and Profiles APIs between the US and EU regions with the `region` setting.

## Setup guide

To use the RudderStack connector, you must have access to a RudderStack workspace. The Event Stream API is available on every plan, including the free plan. The Activation and Profiles APIs need RudderStack Profiles, and the Activation API also needs a Redis destination that the Profiles project syncs to.

### Step 1: Sign in to RudderStack

1. Navigate to [app.rudderstack.com](https://app.rudderstack.com) and sign in, or create an account.

### Step 2: Get the source write key and the data plane URL (Event Stream API)

1. In the left sidebar, go to **Directory** > **Sources** and select **HTTP**.

   <img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-rudderstack/main/docs/setup/resources/add-http-source.png alt="Add an HTTP source" style="border:1px solid #000000; width:80%">

2. Give the source a name and complete the setup.
3. On the source page, click **Write key** to copy the source write key.

   <img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-rudderstack/main/docs/setup/resources/copy-write-key.png alt="Copy the source write key" style="border:1px solid #000000; width:80%">

4. Copy your **Data plane URL**, which is shown at the top of the **Connections** page (for example, `https://<your-workspace>.dataplane.rudderstack.com`).

### Step 3: Generate an access token (Activation and Profiles APIs)

The Activation and Profiles APIs authenticate with a Bearer token. For development and testing, you can use a Personal Access Token. For production, use a workspace-level Service Access Token.

#### For development and testing: Personal Access Token

1. In the left sidebar, go to **Settings** > **Your Profile**. Under **Personal access tokens**, click **Generate new token**.

   <img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-rudderstack/main/docs/setup/resources/personal-access-tokens.png alt="Personal access tokens" style="border:1px solid #000000; width:80%">

2. Enter a token name, select the workspace and the scope, and click **Generate**.

   <img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-rudderstack/main/docs/setup/resources/new-personal-access-token.png alt="Create a personal access token" style="border:1px solid #000000; width:80%">

3. Copy the token. It is shown only once.

   <img src=https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-rudderstack/main/docs/setup/resources/copy-personal-access-token.png alt="Copy the personal access token" style="border:1px solid #000000; width:80%">

#### For production: Service Access Token

> Also see RudderStack's guide on [Service Access Tokens](https://www.rudderstack.com/docs/access-management/service-access-tokens/). Only workspace Admins can generate them.

1. In the left sidebar, go to **Settings** > **Access Management** > **Service Access Tokens**, and select the **Workspace** tab.
2. Click **Generate new token**, enter a name, select the workspace, and click **Next**.
3. Under **Workspace SAT access policy**, grant the permissions for the APIs you use:
   - **Activation API:** **Destination Data Access** on the Redis destination that the Profiles project syncs to.
   - **Profiles API:** **Edit** on the Profiles resource.
4. Click **Generate** and copy the token. It is shown only once, and its access policy can't be changed later.

### Step 4: Note your workspace region

The Activation and Profiles APIs have separate US and EU hosts. If your workspace is in the EU region, set `region` to `rudderstack:EU` in the connection config. The default is `rudderstack:US`.

## Quickstart

To use the `rudderstack` connector in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

```ballerina
import ballerinax/rudderstack;
```

### Step 2: Instantiate a new connector

1. Create a `Config.toml` file and configure the obtained credentials. Set only the ones for the APIs you use:

    ```toml
    writeKey = "<your-source-write-key>"
    dataPlaneUrl = "https://<your-workspace>.dataplane.rudderstack.com"
    serviceAccessToken = "<your-service-access-token>"
    ```

2. Create a `rudderstack:Client` instance. `serviceUrl` is the data plane URL, and it's required when you set `writeKey`:

    ```ballerina
    configurable string? writeKey = ();
    configurable string? dataPlaneUrl = ();
    configurable string? serviceAccessToken = ();

    final rudderstack:Client rudderstackClient = check new ({
        auth: {writeKey, serviceAccessToken}
    }, serviceUrl = dataPlaneUrl);
    ```

    > **Note:** For a workspace in the EU region, also set the region so that the Activation and Profiles operations use the EU hosts:
    >
    > ```ballerina
    > final rudderstack:Client rudderstackClient = check new ({
    >     auth: {writeKey, serviceAccessToken},
    >     region: rudderstack:EU
    > }, serviceUrl = dataPlaneUrl);
    > ```

### Step 3: Invoke the connector operation

Now, utilize the available connector operations.

#### Track an event

```ballerina
public function main() returns error? {
    string response = check rudderstackClient->track({
        userId: "u123",
        event: "Order Completed",
        properties: {"orderId": "o-1001", "revenue": 49.99, "currency": "USD"}
    });
    io:println(response); // ok
}
```

#### Get a profile

```ballerina
public function main() returns error? {
    rudderstack:Profile profile = check rudderstackClient->getProfile({
        entity: "user",
        destinationId: "<your-redis-destination-id>",
        id: {'type: "user_id", value: "u123"}
    });
    io:println(profile.data);
}
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `RudderStack` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-rudderstack/tree/main/examples/), covering the following use cases:

1. [Customer journey tracking](https://github.com/ballerina-platform/module-ballerinax-rudderstack/tree/main/examples/customer-journey-tracking): Identify a customer, record the product page they view, then send their add-to-cart and order events together in one batch.
2. [B2B signup attribution](https://github.com/ballerina-platform/module-ballerinax-rudderstack/tree/main/examples/b2b-signup-attribution): Record an anonymous visitor's landing page view with its campaign, link the visitor to the new user ID at signup, record the user's traits, and associate the user with their company.
3. [Profile refresh and activation](https://github.com/ballerina-platform/module-ballerinax-rudderstack/tree/main/examples/profile-refresh-activation): Start a Profiles run, poll it until it finishes, then fetch the refreshed profiles of a few customers through the Activation API.

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export Github Personal access token with read package permissions as follows,

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`rudderstack` package](https://central.ballerina.io/ballerinax/rudderstack/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
