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

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/pkg/errors"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	local "github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/common"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
)

const (
	ifNameKey = "peerif"
)

// IfnameEndpoint is a composite to change interface's name upon request
type IfnameEndpoint struct {
}

// Init will be called upon NSM Endpoint instantiation with the proper context
func (mce *IfnameEndpoint) Init(context *endpoint.InitContext) error {
	return nil
}

// Request implements the request handler
// Consumes from ctx context.Context:
//	   Next
func (mce *IfnameEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {
	if endpoint.Next(ctx) != nil {
		incomingConnection, err := endpoint.Next(ctx).Request(ctx, request)
		if err != nil {
			endpoint.Log(ctx).Errorf("Next request failed: %v", err)
			return nil, err
		}

		endpoint.Log(ctx).Infof("Ifname UpdateConnection: %v", incomingConnection)

		ifname, ok := request.GetRequestConnection().GetLabels()[ifNameKey]
		if ok {
			incomingConnection.GetMechanism().GetParameters()[local.InterfaceNameKey] = ifname
		}

		return incomingConnection, nil
	}

	return nil, errors.New("IfnameEndpoint.Request - cannot create requested connection")
}

// Close implements the close handler
// Request implements the request handler
// Consumes from ctx context.Context:
//	   Next
func (mce *IfnameEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	endpoint.Log(ctx).Infof("Ifname DeleteConnection: %v", connection)

	if endpoint.Next(ctx) != nil {
		rv, err := endpoint.Next(ctx).Close(ctx, connection)
		return rv, err
	}

	return nil, errors.New("IfName DeleteConnection cannot close connection")
}

// Name returns the composite name
func (mce *IfnameEndpoint) Name() string {
	return "ifname"
}

// NewIfnameEndpoint creates a IfnameEndpoint
func NewIfnameEndpoint(configuration *common.NSConfiguration) *IfnameEndpoint {
	self := &IfnameEndpoint{}
	return self
}
