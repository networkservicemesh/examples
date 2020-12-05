// Copyright 2020 VMware, Inc.
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
	"context"
	"strconv"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	mechanism "github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/common"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/pkg/errors"
)

const (
	interfaceNameKey = mechanism.InterfaceNameKey
	maxInterfaces    = 10000
)

// InterfaceNameEndpoint is an endpoint that
type InterfaceNameEndpoint struct {
	Names map[string]int
}

// Request implements Request method from NetworkServiceServer
// Consumes from ctx context.Context:
//	   Next
func (ine *InterfaceNameEndpoint) Request(ctx context.Context, request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	if interfaceName, ok := request.GetRequestConnection().GetLabels()[interfaceNameKey]; ok {
		c := request.GetConnection()
		if _, ok := ine.Names[interfaceName]; !ok {
			ine.Names[interfaceNameKey] = 0
		} else {
			count := ine.Names[interfaceNameKey] + 1
			if count > maxInterfaces {
				return nil, errors.Errorf("Reached the max interface count for %s", interfaceName)
			}
			ine.Names[interfaceNameKey] = count
			interfaceName = interfaceName + strconv.Itoa(count)
		}
		endpoint.Log(ctx).Infof("Setting interface name to %s", interfaceName)
		c.Mechanism.Parameters[mechanism.InterfaceNameKey] = interfaceName
	}

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	endpoint.Log(ctx).Infof("%v endpoint completed on connection: %v", ine.Name(), request.GetConnection())
	return request.GetConnection(), nil
}

// Close implements Close method from NetworkServiceServer
// Consumes from ctx context.Context:
//	   Next
func (ine *InterfaceNameEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Close(ctx, connection)
	}
	return &empty.Empty{}, nil
}

// Name returns the composite name
func (ine *InterfaceNameEndpoint) Name() string {
	return "InterfaceName"
}

// NewInterfaceNameEndpoint create InterfaceNameEndpoint
func NewInterfaceNameEndpoint() *InterfaceNameEndpoint {
	return &InterfaceNameEndpoint{
		Names: map[string]int{},
	}
}
