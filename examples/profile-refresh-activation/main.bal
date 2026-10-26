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

// This example refreshes the profiles of a RudderStack Profiles project and reads them: it starts a Profiles
// run, polls the run until it finishes, then fetches the refreshed profiles of a few customers from the Redis
// destination through the Activation API.

import ballerina/io;
import ballerina/lang.runtime;
import ballerinax/rudderstack;

configurable rudderstack:AuthConfig auth = ?;
configurable rudderstack:Region region = rudderstack:US;
configurable string profilesId = ?;
configurable string destinationId = ?;
configurable string[] userIds = ["u-1001", "u-1002"];
configurable decimal pollIntervalSeconds = 30;

public function main() returns error? {
    rudderstack:Client rudderstackClient = check new ({auth, region});

    // Step 1: Start a run of the Profiles project
    rudderstack:StartProfilesRunResponse run = check rudderstackClient->startProfilesRun(profilesId);
    string? startedRunId = run.runId;
    if startedRunId is () {
        return error("The Profiles API didn't return a run ID");
    }
    string runId = startedRunId;
    io:println(string `Started run ${runId}`);

    // Step 2: Poll the run until it finishes. A failed run also finishes, with `error` set
    rudderstack:ProfilesRunStatus status = check rudderstackClient->getProfilesRunStatus(profilesId, runId);
    while status.status == "running" {
        runtime:sleep(pollIntervalSeconds);
        status = check rudderstackClient->getProfilesRunStatus(profilesId, runId);
        io:println(string `Run status: ${status.status.toString()}`);
    }
    anydata runError = status?.'error;
    if runError !is () {
        return error(string `Run ${runId} failed: ${runError.toString()}`);
    }
    if status.status != "finished" {
        return error(string `Run ${runId} returned no status`);
    }

    // Step 3: Fetch the refreshed profiles of the customers
    rudderstack:BatchProfilesResponse response = check rudderstackClient->getProfiles({
        entity: "user",
        destinationId,
        ids: from string userId in userIds
            select {'type: "user_id", value: userId}
    });
    foreach rudderstack:Profile profile in response.profiles {
        io:println(string `${profile.id.value}: ${profile.data.toString()}`);
    }
}
