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

// This example tracks a customer's journey through an online store with the Event Stream API: it identifies
// the customer, records the product page they view, then sends the add-to-cart and order events together
// in one batch. Every request carries the same `AnonymousId` header so the data plane processes the
// customer's events in order. The client sends each single event's `anonymousId` as that header by default;
// the batch passes it explicitly.

import ballerina/io;
import ballerinax/rudderstack;

configurable string writeKey = ?;
configurable string dataPlaneUrl = ?;
configurable string userId = "u-1001";
configurable string anonymousId = "anon-7f3c9a";

public function main() returns error? {
    rudderstack:Client rudderstackClient = check new ({auth: {writeKey}}, serviceUrl = dataPlaneUrl);

    // Step 1: Identify the customer and record their traits
    string response = check rudderstackClient->identify({
        userId,
        anonymousId,
        traits: {email: "alex@example.com", firstName: "Alex", lastName: "Silva", "plan": "premium"}
    });
    io:println(string `Identified ${userId}: ${response}`);

    // Step 2: Record the product page view
    response = check rudderstackClient->page({
        userId,
        anonymousId,
        name: "Product",
        properties: {"url": "https://shop.example.com/products/sku-42", "sku": "SKU-42", "category": "Shoes"}
    });
    io:println(string `Recorded page view: ${response}`);

    // Step 3: Send the add-to-cart and order events in one batch
    response = check rudderstackClient->batch({
        batch: [
            {
                'type: "track",
                userId,
                anonymousId,
                event: "Product Added",
                properties: {"sku": "SKU-42", "price": 89.99, "quantity": 1}
            },
            {
                'type: "track",
                userId,
                anonymousId,
                event: "Order Completed",
                properties: {"orderId": "o-5001", "revenue": 89.99, "currency": "USD"}
            }
        ]
    }, {anonymousId});
    io:println(string `Sent cart and order events: ${response}`);
}
