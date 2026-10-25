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
import ballerina/lang.array;

listener http:Listener ep0 = new (9090);

const MOCK_WRITE_KEY = "test_write_key";
const MOCK_ACCESS_TOKEN = "test_access_token";
const RUNNING_PROFILES_ID = "running_project";

// Mirrors the rudder-server gateway: the write key is the Basic auth username, the password is ignored,
// and errors are plain text.
isolated function checkWriteKey(string? authorization) returns http:Unauthorized? {
    string username = "";
    if authorization is string && authorization.startsWith("Basic ") {
        byte[]|error decoded = array:fromBase64(authorization.substring(6));
        if decoded is byte[] {
            string|error credentials = string:fromBytes(decoded);
            if credentials is string {
                int? separator = credentials.indexOf(":");
                username = separator is int ? credentials.substring(0, separator) : credentials;
            }
        }
    }
    if username == "" {
        return {body: "failed to read writekey from header", mediaType: "text/plain"};
    }
    if username != MOCK_WRITE_KEY {
        return {body: "invalid write key", mediaType: "text/plain"};
    }
    return;
}

// Mirrors the Activation and Profiles APIs: a Bearer Service Access Token, and JSON errors.
isolated function checkAccessToken(string? authorization) returns http:Unauthorized? {
    if authorization != string `Bearer ${MOCK_ACCESS_TOKEN}` {
        return {body: {'error: "Unauthorized request. Please check your access token"}};
    }
    return;
}

isolated function accepted() returns http:Ok => {body: "ok", mediaType: "text/plain"};

# Event Stream (data plane)
service / on ep0 {
    resource function post v1/identify(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload IdentifyEvent payload) returns http:Ok|http:Unauthorized {
        return checkWriteKey(authorization) ?: accepted();
    }

    // Also checks that the `AnonymousId` header is forwarded: when the event carries an `anonymousId`,
    // the header must carry the same value.
    resource function post v1/track(@http:Header {name: "Authorization"} string? authorization,
            @http:Header {name: "AnonymousId"} string? anonymousIdHeader,
            @http:Payload TrackEvent payload) returns http:Ok|http:Unauthorized|http:BadRequest {
        http:Unauthorized? unauthorized = checkWriteKey(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        string? anonymousId = payload?.anonymousId;
        if anonymousId is string && anonymousIdHeader != anonymousId {
            return <http:BadRequest>{body: "AnonymousId header does not match the event", mediaType: "text/plain"};
        }
        return accepted();
    }

    resource function post v1/page(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload PageEvent payload) returns http:Ok|http:Unauthorized {
        return checkWriteKey(authorization) ?: accepted();
    }

    resource function post v1/screen(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload ScreenEvent payload) returns http:Ok|http:Unauthorized {
        return checkWriteKey(authorization) ?: accepted();
    }

    resource function post v1/group(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload GroupEvent payload) returns http:Ok|http:Unauthorized {
        return checkWriteKey(authorization) ?: accepted();
    }

    resource function post v1/alias(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload AliasEvent payload) returns http:Ok|http:Unauthorized {
        return checkWriteKey(authorization) ?: accepted();
    }

    resource function post v1/batch(@http:Header {name: "Authorization"} string? authorization,
            @http:Header {name: "AnonymousId"} string? anonymousIdHeader, @http:Payload BatchRequest payload)
            returns http:Ok|http:Unauthorized|http:BadRequest {
        http:Unauthorized? unauthorized = checkWriteKey(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        if payload.batch.length() == 0 {
            return <http:BadRequest>{body: "empty batch payload", mediaType: "text/plain"};
        }
        // When every event carries the same `anonymousId`, the `AnonymousId` header must carry it too.
        string? sharedAnonymousId = payload.batch[0]?.anonymousId;
        boolean shared = sharedAnonymousId is string;
        foreach BatchedEvent event in payload.batch {
            shared = shared && event?.anonymousId == sharedAnonymousId;
        }
        if shared && anonymousIdHeader != sharedAnonymousId {
            return <http:BadRequest>{
                body: "AnonymousId header does not match the events",
                mediaType: "text/plain"
            };
        }
        return accepted();
    }
}

# Activation API
service /profiles/v2 on ep0 {
    resource function post activation(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload ProfilesRequest payload) returns http:Ok|http:Unauthorized|error {
        http:Unauthorized? unauthorized = checkAccessToken(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        if payload is BatchProfilesRequest {
            BatchProfilesResponse profiles = {
                profiles: from ProfileIdentifier id in payload.ids
                    select {entity: payload.entity, id, data: id.value == "u123" ? {"lifetime_value": 420} : {}}
            };
            return <http:Ok>{body: profiles};
        }
        SingleProfileRequest single = check payload.ensureType();
        Profile profile = {
            entity: single.entity,
            id: single.id,
            data: {"lifetime_value": 420, "is_churn_risk": false}
        };
        return <http:Ok>{body: profile};
    }

    resource function delete activation(@http:Header {name: "Authorization"} string? authorization,
            @http:Payload ProfilesRequest payload) returns http:Ok|http:Unauthorized {
        http:Unauthorized? unauthorized = checkAccessToken(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        int requested = payload is BatchProfilesRequest ? payload.ids.length() : 1;
        DeleteProfilesResult result = {deletedKeys: requested * 10, actualKeys: requested * 15};
        return <http:Ok>{body: result};
    }
}

# Profiles API
service /api/v2 on ep0 {
    resource function post sources/[string profilesId]/'start(
            @http:Header {name: "Authorization"} string? authorization, @http:Payload StartProfilesRunRequest payload)
            returns http:Ok|http:Unauthorized|http:Conflict {
        http:Unauthorized? unauthorized = checkAccessToken(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        if profilesId == RUNNING_PROFILES_ID {
            return <http:Conflict>{body: {message: "Profiles project is already running for the specified source ID"}};
        }
        string[] parameters = payload.parameters ?: [];
        string runId = parameters.length() > 0 ? "2cRunWithParameters" : "2cJmVZmRGZ8xLrKPgTuNqWvBdXh";
        StartProfilesRunResponse response = {runId};
        return <http:Ok>{body: response};
    }

    resource function get sources/[string profilesId]/runs/[string runId]/status(
            @http:Header {name: "Authorization"} string? authorization) returns ProfilesRunStatus|http:Unauthorized {
        http:Unauthorized? unauthorized = checkAccessToken(authorization);
        if unauthorized is http:Unauthorized {
            return unauthorized;
        }
        return {
            jobId: "job-1",
            jobRunId: runId,
            status: "finished",
            startedAt: "2024-05-31T06:48:08.228Z",
            finishedAt: "2024-05-31T07:02:11.904Z",
            tasks: [
                {
                    taskId: "t1",
                    taskRunId: "tr1",
                    startedAt: "2024-05-31T06:48:08.228Z",
                    finishedAt: "2024-05-31T06:52:00.000Z"
                }
            ]
        };
    }
}
