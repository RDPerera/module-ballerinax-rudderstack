// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/os;
import ballerina/test;

final boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
final string serviceUrl = isLiveServer ? os:getEnv("RUDDERSTACK_DATA_PLANE_URL") : "http://localhost:9090";
final string writeKey = isLiveServer ? os:getEnv("RUDDERSTACK_WRITE_KEY") : MOCK_WRITE_KEY;
final string accessToken = isLiveServer ? os:getEnv("RUDDERSTACK_ACCESS_TOKEN") : MOCK_ACCESS_TOKEN;
final Region region = os:getEnv("RUDDERSTACK_REGION") == "EU" ? EU : US;

const MOCK_ACTIVATION_URL = "http://localhost:9090/profiles/v2";
const MOCK_PROFILES_URL = "http://localhost:9090/api/v2";

final Client rudderstack = check new (connectionConfig({writeKey, serviceAccessToken: accessToken}), serviceUrl);

// Points the Activation and Profiles APIs at the mock service unless the tests run against the live APIs.
isolated function connectionConfig(AuthConfig auth) returns ConnectionConfig {
    ConnectionConfig config = {auth, region};
    if !isLiveServer {
        config.activationServiceUrl = MOCK_ACTIVATION_URL;
        config.profilesServiceUrl = MOCK_PROFILES_URL;
    }
    return config;
}

isolated function assertStatusCode(any|error response, int statusCode) {
    if response !is http:ClientRequestError {
        string actual = response is error ? response.message() : "a success";
        test:assertFail(string `expected an HTTP ${statusCode} error, got: ${actual}`);
    }
    test:assertEquals(response.detail().statusCode, statusCode);
}

// ---------------------------------------------------------------- Event Stream

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testIdentify() returns error? {
    string response = check rudderstack->identify({
        userId: "u123",
        traits: {email: "alex@example.com", firstName: "Alex", "plan": "enterprise"}
    });
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testTrack() returns error? {
    string response = check rudderstack->track({
        anonymousId: "anon-42",
        event: "Order Completed",
        properties: {"orderId": "o-1001", "revenue": 49.99, "currency": "USD"},
        context: {library: {name: "ballerinax/rudderstack", version: "1.0.0"}}
    }, {anonymousId: "anon-42"});
    test:assertEquals(response, "ok");
}

// The mock service rejects a `track` event whose `anonymousId` doesn't match the `AnonymousId` header.
@test:Config {
    groups: ["mock_tests"]
}
isolated function testTrackDefaultsAnonymousIdHeader() returns error? {
    string response = check rudderstack->track({anonymousId: "anon-43", event: "Product Viewed"});
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testPage() returns error? {
    string response = check rudderstack->page({
        userId: "u123",
        name: "Pricing",
        properties: {"url": "https://example.com/pricing", "title": "Pricing"}
    });
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testScreen() returns error? {
    string response = check rudderstack->screen({userId: "u123", name: "Home", properties: {"tab": "feed"}});
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testGroup() returns error? {
    string response = check rudderstack->group({
        userId: "u123",
        groupId: "acme",
        traits: {name: "Acme Inc.", "industry": "Manufacturing", "employees": 250}
    });
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testAlias() returns error? {
    string response = check rudderstack->alias({userId: "u123", previousId: "anon-42"});
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testBatch() returns error? {
    string response = check rudderstack->batch({
        batch: [
            {'type: "identify", userId: "u123", traits: {email: "alex@example.com"}},
            {'type: "track", userId: "u123", event: "Product Viewed", properties: {"sku": "SKU-1"}},
            {'type: "page", userId: "u123", name: "Checkout"}
        ]
    });
    test:assertEquals(response, "ok");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testInvalidWriteKey() returns error? {
    Client invalidClient = check new (connectionConfig({writeKey: "invalid_write_key"}), serviceUrl);
    string|error response = invalidClient->track({userId: "u123", event: "Signed Up"});
    assertStatusCode(response, 401);
    if response is http:ClientRequestError {
        // The data plane terminates its plain-text error bodies with a newline.
        test:assertEquals(response.detail().body.toString().trim(), "invalid write key");
    }
}

// The mock service rejects a batch whose events share an `anonymousId` that doesn't match the `AnonymousId` header.
@test:Config {
    groups: ["mock_tests"]
}
isolated function testBatchForwardsAnonymousIdHeader() returns error? {
    string response = check rudderstack->batch({
        batch: [
            {'type: "track", anonymousId: "anon-44", event: "Product Added"},
            {'type: "track", anonymousId: "anon-44", event: "Order Completed"}
        ]
    }, {anonymousId: "anon-44"});
    test:assertEquals(response, "ok");
}

// ---------------------------------------------------------------- Activation

@test:Config {
    groups: ["mock_tests"]
}
isolated function testGetProfile() returns error? {
    Profile profile = check rudderstack->getProfile({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        id: {'type: "user_id", value: "u123"}
    });
    test:assertEquals(profile.id.value, "u123");
    test:assertEquals(profile.data["lifetime_value"], 420);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testGetProfiles() returns error? {
    BatchProfilesResponse response = check rudderstack->getProfiles({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        ids: [{'type: "user_id", value: "u123"}, {'type: "email", value: "alex@example.com"}]
    });
    test:assertEquals(response.profiles.length(), 2);
    test:assertEquals(response.profiles[1].id.value, "alex@example.com");
    test:assertEquals(response.profiles[1].data.length(), 0);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testDeleteProfile() returns error? {
    DeleteProfilesResult response = check rudderstack->deleteProfile({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        id: {'type: "user_id", value: "u123"}
    });
    test:assertEquals(response.deletedKeys, 10);
    test:assertEquals(response.actualKeys, 15);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testDeleteProfiles() returns error? {
    DeleteProfilesResult response = check rudderstack->deleteProfiles({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        ids: [{'type: "user_id", value: "u123"}, {'type: "user_id", value: "u456"}]
    });
    test:assertEquals(response.deletedKeys, 20);
    test:assertEquals(response.actualKeys, 30);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testInvalidAccessToken() returns error? {
    Client invalidClient = check new (connectionConfig({serviceAccessToken: "invalid_token"}), serviceUrl);
    Profile|error response = invalidClient->getProfile({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        id: {'type: "user_id", value: "u123"}
    });
    assertStatusCode(response, 401);
}

// The live account has no Redis destination, so a `400 Invalid destinationId` (rather than a `401`)
// shows that the token is accepted and the request reached the Activation API.
@test:Config {
    groups: ["live_tests"]
}
isolated function testLiveGetProfileAuthentication() returns error? {
    if !isLiveServer {
        return;
    }
    Profile|error response = rudderstack->getProfile({
        entity: "user",
        destinationId: "unknown_destination",
        id: {'type: "user_id", value: "u123"}
    });
    assertStatusCode(response, 400);
}

// As above, for the other Activation operations.
@test:Config {
    groups: ["live_tests"]
}
isolated function testLiveActivationOperationsAuthentication() returns error? {
    if !isLiveServer {
        return;
    }
    BatchProfilesResponse|error profiles = rudderstack->getProfiles({
        entity: "user",
        destinationId: "unknown_destination",
        ids: [{'type: "user_id", value: "u123"}]
    });
    assertStatusCode(profiles, 400);
    DeleteProfilesResult|error deleted = rudderstack->deleteProfile({
        entity: "user",
        destinationId: "unknown_destination",
        id: {'type: "user_id", value: "u123"}
    });
    assertStatusCode(deleted, 400);
    deleted = rudderstack->deleteProfiles({
        entity: "user",
        destinationId: "unknown_destination",
        ids: [{'type: "user_id", value: "u123"}]
    });
    assertStatusCode(deleted, 400);
}

// ---------------------------------------------------------------- Profiles

@test:Config {
    groups: ["mock_tests"]
}
isolated function testStartProfilesRun() returns error? {
    StartProfilesRunResponse response = check rudderstack->startProfilesRun("2aProfilesProjectId");
    test:assertEquals(response.runId, "2cJmVZmRGZ8xLrKPgTuNqWvBdXh");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testStartProfilesRunWithParameters() returns error? {
    StartProfilesRunResponse response = check rudderstack->startProfilesRun("2aProfilesProjectId",
        {parameters: ["--model_refs models/id_graph_users"]});
    // The mock service returns a different run ID when it receives the parameters.
    test:assertEquals(response.runId, "2cRunWithParameters");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testStartProfilesRunConflict() returns error? {
    StartProfilesRunResponse|error response = rudderstack->startProfilesRun(RUNNING_PROFILES_ID);
    assertStatusCode(response, 409);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testGetProfilesRunStatus() returns error? {
    ProfilesRunStatus response = check rudderstack->getProfilesRunStatus("2aProfilesProjectId",
        "2cJmVZmRGZ8xLrKPgTuNqWvBdXh");
    test:assertEquals(response.status, "finished");
    test:assertEquals(response.jobRunId, "2cJmVZmRGZ8xLrKPgTuNqWvBdXh");
    test:assertEquals((response.tasks ?: []).length(), 1);
}

// An unknown run returns `404` (rather than `401`), which shows that the token is accepted.
@test:Config {
    groups: ["live_tests"]
}
isolated function testLiveGetProfilesRunStatusAuthentication() returns error? {
    if !isLiveServer {
        return;
    }
    ProfilesRunStatus|error response = rudderstack->getProfilesRunStatus("unknown_project", "unknown_run");
    assertStatusCode(response, 404);
}

// Starting a run of a project the token has no access to returns `403` (rather than `401`), which shows that
// the token is accepted.
@test:Config {
    groups: ["live_tests"]
}
isolated function testLiveStartProfilesRunAuthentication() returns error? {
    if !isLiveServer {
        return;
    }
    StartProfilesRunResponse|error response = rudderstack->startProfilesRun("unknown_project");
    assertStatusCode(response, 403);
}

// ---------------------------------------------------------------- Connection config

@test:Config {
    groups: ["mock_tests"]
}
isolated function testRegionServiceUrls() returns error? {
    test:assertEquals(check resolveTokenServiceUrls({auth: {}}),
        ["https://profiles.rudderstack.com/v2", "https://api.rudderstack.com/v2"]);
    test:assertEquals(check resolveTokenServiceUrls({auth: {}, region: EU}),
        ["https://profiles-eu.rudderstack.com/v2", "https://api.eu.rudderstack.com/v2"]);
    test:assertEquals(check resolveTokenServiceUrls({
        auth: {},
        region: EU,
        activationServiceUrl: "http://localhost:9090/profiles/v2",
        profilesServiceUrl: "http://localhost:9090/api/v2"
    }), ["http://localhost:9090/profiles/v2", "http://localhost:9090/api/v2"]);
    [string, string]|error empty = resolveTokenServiceUrls({auth: {}, activationServiceUrl: ""});
    test:assertTrue(empty is error);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testInitWithoutCredentials() {
    Client|error result = new ({auth: {}});
    if result !is error {
        test:assertFail("expected an error when no credential is set");
    }
    test:assertEquals(result.message(), "Set `auth.writeKey`, `auth.serviceAccessToken`, or both");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testInitWithEmptyCredentials() {
    Client|error result = new ({auth: {writeKey: " "}});
    test:assertTrue(result is error && result.message() == "`auth.writeKey` must not be empty");
    result = new ({auth: {serviceAccessToken: ""}});
    test:assertTrue(result is error && result.message() == "`auth.serviceAccessToken` must not be empty");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testInitWithWriteKeyWithoutServiceUrl() {
    Client|error result = new ({auth: {writeKey}});
    if result !is error {
        test:assertFail("expected an error when the write key is set without `serviceUrl`");
    }
    test:assertEquals(result.message(),
        "Set `serviceUrl` to the data plane URL of your workspace to use `auth.writeKey`");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testInitWithAccessTokenOnly() returns error? {
    Client tokenOnlyClient = check new (connectionConfig({serviceAccessToken: accessToken}));
    Profile|error profile = tokenOnlyClient->getProfile({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        id: {'type: "user_id", value: "u123"}
    });
    if !isLiveServer {
        test:assertTrue(profile is Profile);
    }
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testEventStreamWithoutWriteKey() returns error? {
    Client tokenOnlyClient = check new (connectionConfig({serviceAccessToken: accessToken}), serviceUrl);
    string|error response = tokenOnlyClient->identify({userId: "u123"});
    if response !is error {
        test:assertFail("expected an error when the write key is missing");
    }
    test:assertEquals(response.message(), "The Event Stream operations need `auth.writeKey` in the connection config");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testActivationAndProfilesWithoutAccessToken() returns error? {
    Client writeKeyOnlyClient = check new (connectionConfig({writeKey}), serviceUrl);
    Profile|error profiles = writeKeyOnlyClient->getProfile({
        entity: "user",
        destinationId: "2aBcDeFgHiJkLmNoPqRsTuVwXyZ",
        id: {'type: "user_id", value: "u123"}
    });
    test:assertTrue(profiles is error
        && profiles.message() == "The Activation operations need `auth.serviceAccessToken` in the connection config");
    ProfilesRunStatus|error status = writeKeyOnlyClient->getProfilesRunStatus("2aProfilesProjectId", "run");
    test:assertTrue(status is error
        && status.message() == "The Profiles operations need `auth.serviceAccessToken` in the connection config");
}
