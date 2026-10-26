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

// This example records how an anonymous visitor from a marketing campaign becomes a customer of a B2B product:
// it records the visitor's landing page view with the campaign details, links the visitor's anonymous ID to the
// new user ID when they sign up, records the user's traits, and associates the user with their company.

import ballerina/io;
import ballerinax/rudderstack;

configurable rudderstack:AuthConfig auth = ?;
configurable string dataPlaneUrl = ?;

// Sample identities of the visitor and their company.
final string anonymousId = "anon-5d21e8";
final string userId = "u-2001";
final string companyId = "acme-inc";

public function main() returns error? {
    rudderstack:Client rudderstackClient = check new ({auth}, serviceUrl = dataPlaneUrl);

    // Step 1: Record the anonymous visitor's landing page view, with the campaign that brought them
    string response = check rudderstackClient->page({
        anonymousId,
        name: "Pricing",
        properties: {"url": "https://example.com/pricing", "referrer": "https://news.example.org"},
        context: {campaign: {name: "q4-launch", 'source: "newsletter", medium: "email"}}
    });
    io:println(string `Recorded landing page view: ${response}`);

    // Step 2: The visitor signs up. Link their anonymous ID to the new user ID
    response = check rudderstackClient->alias({userId, previousId: anonymousId});
    io:println(string `Linked ${anonymousId} to ${userId}: ${response}`);

    // Step 3: Record the new user's traits
    response = check rudderstackClient->identify({
        userId,
        traits: {email: "priya@acme.example", name: "Priya Raman", "role": "Engineering Manager"}
    });
    io:println(string `Identified ${userId}: ${response}`);

    // Step 4: Associate the user with their company
    response = check rudderstackClient->group({
        userId,
        groupId: companyId,
        traits: {name: "Acme Inc.", "plan": "business", "employees": 240}
    });
    io:println(string `Added ${userId} to ${companyId}: ${response}`);
}
