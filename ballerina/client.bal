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

const ACTIVATION_US_URL = "https://profiles.rudderstack.com/v2";
const ACTIVATION_EU_URL = "https://profiles-eu.rudderstack.com/v2";
const PROFILES_US_URL = "https://api.rudderstack.com/v2";
const PROFILES_EU_URL = "https://api.eu.rudderstack.com/v2";

// The data plane reads only the Basic auth username (the write key) and ignores the password,
// but the Ballerina HTTP client rejects an empty password, so a placeholder is sent instead.
const WRITE_KEY_PASSWORD = "unused";

# Region of the RudderStack workspace. Selects the Activation and Profiles API hosts.
public enum Region {
    # United States (`profiles.rudderstack.com`, `api.rudderstack.com`)
    US,
    # European Union (`profiles-eu.rudderstack.com`, `api.eu.rudderstack.com`)
    EU
}

# Credentials for the RudderStack APIs. Set the credential of each API you call.
public type AuthConfig record {|
    # Source write key, used by the Event Stream operations (`identify`, `track`, `page`, `screen`,
    # `group`, `alias` and `batch`). Sent as the HTTP Basic auth username
    string? writeKey = ();
    # Workspace Service Access Token (or, for development, a Personal Access Token), used by the Activation
    # (`getProfile`, `getProfiles`, `deleteProfile`, `deleteProfiles`) and Profiles (`startProfilesRun`,
    # `getProfilesRunStatus`) operations. Sent as a Bearer token
    string? serviceAccessToken = ();
|};

# Provides a set of configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Config"}
public type ConnectionConfig record {|
    # Credentials for the RudderStack APIs
    AuthConfig auth;
    # Region of the RudderStack workspace. Selects the Activation and Profiles API hosts
    Region region = US;
    # Overrides the Activation API URL selected by `region`
    string activationServiceUrl?;
    # Overrides the Profiles API URL selected by `region`
    string profilesServiceUrl?;
    # The HTTP version understood by the client
    http:HttpVersion httpVersion = http:HTTP_2_0;
    # Configurations related to HTTP/1.x protocol
    http:ClientHttp1Settings http1Settings = {};
    # Configurations related to HTTP/2 protocol
    http:ClientHttp2Settings http2Settings = {};
    # The maximum time to wait (in seconds) for a response before closing the connection
    decimal timeout = 30;
    # The choice of setting `forwarded`/`x-forwarded` header
    string forwarded = "disable";
    # Configurations associated with Redirection
    http:FollowRedirects followRedirects?;
    # Configurations associated with request pooling
    http:PoolConfiguration poolConfig?;
    # HTTP caching related configurations
    http:CacheConfig cache = {};
    # Specifies the way of handling compression (`accept-encoding`) header
    http:Compression compression = http:COMPRESSION_AUTO;
    # Configurations associated with the behaviour of the Circuit Breaker
    http:CircuitBreakerConfig circuitBreaker?;
    # Configurations associated with retrying
    http:RetryConfig retryConfig?;
    # Configurations associated with cookies
    http:CookieConfig cookieConfig?;
    # Configurations associated with inbound response size limits
    http:ResponseLimitConfigs responseLimits = {};
    # SSL/TLS-related options
    http:ClientSecureSocket secureSocket?;
    # Proxy server related options
    http:ProxyConfig proxy?;
    # Provides settings related to client socket configuration
    http:ClientSocketConfig socketConfig = {};
    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    boolean validation = true;
    # Enables relaxed data binding on the client side. When enabled, `nil` values are treated as optional,
    # and absent fields are handled as `nilable` types. Enabled by default.
    boolean laxDataBinding = true;
|};

# Headers of an Event Stream request.
public type EventHeaders record {|
    # Ordering key. The data plane processes requests that share this value in order. For a single event,
    # defaults to the event's `anonymousId`
    string anonymousId?;
    # Time the request was sent (ISO 8601)
    string sentAt?;
|};

# Write customer events to RudderStack through the Event Stream (HTTP) API, read and delete the profiles
# that RudderStack Profiles builds through the Activation API, and trigger and monitor Profiles runs
# through the Profiles API.
#
# The three APIs are served from different hosts with different credentials. The client sends each
# operation to the right host with the right credential: the Event Stream operations to the data plane
# (`serviceUrl`) with the source write key, and the Activation and Profiles operations to the hosts of
# the configured `region` with the Service Access Token.
@display {label: "RudderStack"}
public isolated client class Client {
    private final GeneratedClient? eventStreamClient;
    private final GeneratedClient? activationClient;
    private final GeneratedClient? profilesClient;

    # Gets invoked to initialize the `connector`.
    #
    # + config - The configurations to be used when initializing the `connector`
    # + serviceUrl - Data plane URL of the RudderStack workspace (or of a self-hosted `rudder-server`), for
    #                example `https://<workspace>.dataplane.rudderstack.com`. Required with `auth.writeKey`
    # + return - An error if connector initialization failed
    public isolated function init(ConnectionConfig config, string? serviceUrl = ()) returns error? {
        string? writeKey = config.auth.writeKey;
        string? serviceAccessToken = config.auth.serviceAccessToken;
        if writeKey is () && serviceAccessToken is () {
            return error("Set `auth.writeKey`, `auth.serviceAccessToken`, or both");
        }

        GeneratedClient? eventStreamClient = ();
        if writeKey is string {
            if writeKey.trim() == "" {
                return error("`auth.writeKey` must not be empty");
            }
            if serviceUrl is () || serviceUrl.trim() == "" {
                return error("Set `serviceUrl` to the data plane URL of your workspace to use `auth.writeKey`");
            }
            http:CredentialsConfig credentials = {username: writeKey, password: WRITE_KEY_PASSWORD};
            GeneratedClient 'client = check new (toGeneratedConfig(config, credentials), serviceUrl);
            eventStreamClient = 'client;
        }

        GeneratedClient? activationClient = ();
        GeneratedClient? profilesClient = ();
        if serviceAccessToken is string {
            if serviceAccessToken.trim() == "" {
                return error("`auth.serviceAccessToken` must not be empty");
            }
            GeneratedConnectionConfig bearerConfig = toGeneratedConfig(config, {token: serviceAccessToken});
            [string, string] [activationUrl, profilesUrl] = check resolveTokenServiceUrls(config);
            GeneratedClient activation = check new (bearerConfig, activationUrl);
            GeneratedClient profiles = check new (bearerConfig, profilesUrl);
            activationClient = activation;
            profilesClient = profiles;
        }

        self.eventStreamClient = eventStreamClient;
        self.activationClient = activationClient;
        self.profilesClient = profilesClient;
    }

    private isolated function getEventStreamClient() returns GeneratedClient|error {
        GeneratedClient? 'client = self.eventStreamClient;
        if 'client is () {
            return error("The Event Stream operations need `auth.writeKey` in the connection config");
        }
        return 'client;
    }

    private isolated function getActivationClient() returns GeneratedClient|error {
        GeneratedClient? 'client = self.activationClient;
        if 'client is () {
            return error("The Activation operations need `auth.serviceAccessToken` in the connection config");
        }
        return 'client;
    }

    private isolated function getProfilesClient() returns GeneratedClient|error {
        GeneratedClient? 'client = self.profilesClient;
        if 'client is () {
            return error("The Profiles operations need `auth.serviceAccessToken` in the connection config");
        }
        return 'client;
    }

    # Identify a user and record their traits
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function identify(IdentifyEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->identify(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Record an action a user performed
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function track(TrackEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->track(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Record a web page view
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function page(PageEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->page(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Record a mobile app screen view
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function screen(ScreenEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->screen(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Associate a user with a group (company, organisation, account)
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function group(GroupEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->group(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Merge two user identities
    #
    # + payload - The event to send
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the event
    remote isolated function alias(AliasEvent payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->alias(payload, {...withAnonymousId(headers, payload?.anonymousId)});
    }

    # Send several events in one request
    #
    # + payload - The events to send. Each event sets `type`
    # + headers - The `AnonymousId` ordering header and the `SentAt` header
    # + return - `ok` when the data plane accepts the events
    remote isolated function batch(BatchRequest payload, EventHeaders headers = {}) returns string|error {
        GeneratedClient 'client = check self.getEventStreamClient();
        return 'client->batch(payload, {...headers});
    }

    # Get a profile
    #
    # + payload - The entity, the Redis destination and the identity of the profile
    # + headers - Headers to be sent with the request
    # + return - The profile. Its `data` is empty when the identity has no profile
    remote isolated function getProfile(SingleProfileRequest payload, map<string|string[]> headers = {})
            returns Profile|error {
        GeneratedClient 'client = check self.getActivationClient();
        ProfileResponse response = check 'client->getProfiles(payload, headers);
        if response is Profile {
            return response;
        }
        return error("Expected a single profile in the response");
    }

    # Get several profiles (1 to 100)
    #
    # + payload - The entity, the Redis destination and the identities of the profiles
    # + headers - Headers to be sent with the request
    # + return - The profiles, in the order of `ids`. The `data` of an identity with no profile is empty
    remote isolated function getProfiles(BatchProfilesRequest payload, map<string|string[]> headers = {})
            returns BatchProfilesResponse|error {
        GeneratedClient 'client = check self.getActivationClient();
        ProfileResponse response = check 'client->getProfiles(payload, headers);
        if response is BatchProfilesResponse {
            return response;
        }
        return error("Expected a batch of profiles in the response");
    }

    # Delete a profile from the Redis destination. The next Profiles run recreates it
    #
    # + payload - The entity, the Redis destination and the identity of the profile
    # + headers - Headers to be sent with the request
    # + return - The number of keys deleted and the number of keys that existed for the profile. An error with
    #            status `404` if the profile wasn't found
    remote isolated function deleteProfile(SingleProfileRequest payload, map<string|string[]> headers = {})
            returns DeleteProfilesResult|error {
        GeneratedClient 'client = check self.getActivationClient();
        return 'client->deleteProfiles(payload, headers);
    }

    # Delete several profiles (1 to 100) from the Redis destination. The next Profiles run recreates them
    #
    # + payload - The entity, the Redis destination and the identities of the profiles
    # + headers - Headers to be sent with the request
    # + return - The number of keys deleted and the number of keys that existed for the profiles. An error with
    #            status `404` if none of the profiles were found
    remote isolated function deleteProfiles(BatchProfilesRequest payload, map<string|string[]> headers = {})
            returns DeleteProfilesResult|error {
        GeneratedClient 'client = check self.getActivationClient();
        return 'client->deleteProfiles(payload, headers);
    }

    # Run a Profiles project
    #
    # + profilesId - ID of the Profiles project
    # + payload - Options for the run
    # + headers - Headers to be sent with the request
    # + return - The ID of the started run
    remote isolated function startProfilesRun(string profilesId, StartProfilesRunRequest payload = {},
            map<string|string[]> headers = {}) returns StartProfilesRunResponse|error {
        GeneratedClient 'client = check self.getProfilesClient();
        return 'client->startProfilesRun(profilesId, payload, headers);
    }

    # Get the status of a Profiles run
    #
    # + profilesId - ID of the Profiles project
    # + runId - Run ID returned by `startProfilesRun`
    # + headers - Headers to be sent with the request
    # + return - The status of the run, with its tasks and, for a failed run, the error
    remote isolated function getProfilesRunStatus(string profilesId, string runId,
            map<string|string[]> headers = {}) returns ProfilesRunStatus|error {
        GeneratedClient 'client = check self.getProfilesClient();
        return 'client->getProfilesRunStatus(profilesId, runId, headers);
    }
}

// Returns the Activation and Profiles API URLs: the overrides when set, otherwise the hosts of the region.
isolated function resolveTokenServiceUrls(ConnectionConfig config) returns [string, string]|error {
    boolean isEu = config.region == EU;
    string activationUrl = config.activationServiceUrl ?: (isEu ? ACTIVATION_EU_URL : ACTIVATION_US_URL);
    string profilesUrl = config.profilesServiceUrl ?: (isEu ? PROFILES_EU_URL : PROFILES_US_URL);
    if activationUrl.trim() == "" || profilesUrl.trim() == "" {
        return error("`activationServiceUrl` and `profilesServiceUrl` must not be empty");
    }
    return [activationUrl, profilesUrl];
}

// Defaults the `AnonymousId` ordering header to the event's `anonymousId`, as RudderStack recommends sending it
// with every request.
isolated function withAnonymousId(EventHeaders headers, string? anonymousId) returns EventHeaders {
    if headers?.anonymousId is () && anonymousId is string {
        EventHeaders withDefault = headers.clone();
        withDefault.anonymousId = anonymousId;
        return withDefault;
    }
    return headers;
}

// Builds the configuration of one generated client: the shared HTTP settings plus the credential of its API.
isolated function toGeneratedConfig(ConnectionConfig config, http:CredentialsConfig|http:BearerTokenConfig auth)
        returns GeneratedConnectionConfig {
    GeneratedConnectionConfig generatedConfig = {
        auth,
        httpVersion: config.httpVersion,
        http1Settings: config.http1Settings,
        http2Settings: config.http2Settings,
        timeout: config.timeout,
        forwarded: config.forwarded,
        cache: config.cache,
        compression: config.compression,
        responseLimits: config.responseLimits,
        socketConfig: config.socketConfig,
        validation: config.validation,
        laxDataBinding: config.laxDataBinding
    };
    http:FollowRedirects? followRedirects = config.followRedirects;
    if followRedirects is http:FollowRedirects {
        generatedConfig.followRedirects = followRedirects;
    }
    http:PoolConfiguration? poolConfig = config.poolConfig;
    if poolConfig is http:PoolConfiguration {
        generatedConfig.poolConfig = poolConfig;
    }
    http:CircuitBreakerConfig? circuitBreaker = config.circuitBreaker;
    if circuitBreaker is http:CircuitBreakerConfig {
        generatedConfig.circuitBreaker = circuitBreaker;
    }
    http:RetryConfig? retryConfig = config.retryConfig;
    if retryConfig is http:RetryConfig {
        generatedConfig.retryConfig = retryConfig;
    }
    http:CookieConfig? cookieConfig = config.cookieConfig;
    if cookieConfig is http:CookieConfig {
        generatedConfig.cookieConfig = cookieConfig;
    }
    http:ClientSecureSocket? secureSocket = config.secureSocket;
    if secureSocket is http:ClientSecureSocket {
        generatedConfig.secureSocket = secureSocket;
    }
    http:ProxyConfig? proxy = config.proxy;
    if proxy is http:ProxyConfig {
        generatedConfig.proxy = proxy;
    }
    return generatedConfig;
}
