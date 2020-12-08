// Copyright 2020 Samsung Electronics
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"encoding/json"
	"fmt"
)

// Endpoint contains the information to create NSM objects.
type Endpoint struct {
	Name            string           `json:"name"`
	TracerEnabled   bool             `json:"tracerEnabled"`
	NetworkServices []NetworkService `json:"networkServices"`
}

// NetworkService contains the information to create NSM objects.
type NetworkService struct {
	Link      string `json:"link"`
	Labels    string `json:"labels"`
	IPAddress string `json:"ipAddress"`
	Route     string `json:"route"`
}

// GetEndpoint parses a stream of bytes to a Endpoint struct.
func GetEndpoint(endpointsFile []byte) (Endpoint, error) {
	var endpointsConfig Endpoint

	if err := json.Unmarshal(endpointsFile, &endpointsConfig); err != nil {
		return endpointsConfig, fmt.Errorf("failed to parse annotations file: %w", err)
	}

	return endpointsConfig, nil
}
