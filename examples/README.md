# Examples

The `ballerinax/rudderstack` connector provides practical examples illustrating usage in various scenarios.

| Example | Description |
|---------|-------------|
| [`customer-journey-tracking`](./customer-journey-tracking) | Identifies a customer, records the product page they view, then sends their add-to-cart and order events together in one batch through the Event Stream API |
| [`b2b-signup-attribution`](./b2b-signup-attribution) | Records an anonymous visitor's landing page view with its campaign, links the visitor to the new user ID at signup, records the user's traits, and associates the user with their company |
| [`profile-refresh-activation`](./profile-refresh-activation) | Starts a Profiles run, polls it until it finishes, then fetches the refreshed profiles of a few customers through the Activation API |

## Prerequisites

1. Get the credentials as described in the [setup guide](../ballerina/README.md#setup-guide): a source write key and the data plane URL for the Event Stream examples, and a Service Access Token for the Profiles example.

2. Build and push the connector to your local Ballerina repository:

    ```bash
    cd ../ballerina
    bal pack && bal push --repository=local
    ```

3. For each example, create a `Config.toml` in the example directory with the required credentials, as described in the example's own guide.

## Running an example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the examples with the local module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
