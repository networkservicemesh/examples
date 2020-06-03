// Copyright 2019 VMware, Inc.
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

	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
	"go.ligato.io/vpp-agent/v3/proto/ligato/configurator"
	"go.ligato.io/vpp-agent/v3/proto/ligato/vpp"
	l2 "go.ligato.io/vpp-agent/v3/proto/ligato/vpp/l2"
)

type vppAgentBridgeComposite struct {
	workspace    string
	bridgeDomain *l2.BridgeDomain
}

func (vbc *vppAgentBridgeComposite) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {
	err := vbc.insertVPPAgentInterface(request.GetConnection(), true, vbc.workspace)
	if err != nil {
		logrus.Error(err)
		return nil, err
	}

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	return request.GetConnection(), nil
}

func (vbc *vppAgentBridgeComposite) CreateBridgeDomain() {
	dataChange := &configurator.Config{
		VppConfig: &vpp.ConfigData{
			BridgeDomains: []*l2.BridgeDomain{vbc.bridgeDomain},
		},
	}

	_ = sendDataChangeToVppAgent(dataChange)
}

func (vbc *vppAgentBridgeComposite) Close(ctx context.Context, conn *connection.Connection) (*empty.Empty, error) {
	// remove from connections
	err := vbc.insertVPPAgentInterface(conn, false, vbc.workspace)
	if err != nil {
		logrus.Error(err)
		return &empty.Empty{}, err
	}

	if endpoint.Next(ctx) != nil {
		if _, err := endpoint.Next(ctx).Close(ctx, conn); err != nil {
			return &empty.Empty{}, nil
		}
	}

	return &empty.Empty{}, nil
}

// Name returns the composite name
func (vbc *vppAgentBridgeComposite) Name() string {
	return "VPP Agent Bridge"
}

// vppAgentBridgeComposite creates a new VPP Agent composite
func newVppAgentBridgeComposite(configuration *common.NSConfiguration) *vppAgentBridgeComposite {
	bridgeDomain := &l2.BridgeDomain{
		Name:                "brd",
		Flood:               true,
		UnknownUnicastFlood: true,
		Forward:             true,
		Learn:               true,
		MacAge:              120,
		Interfaces:          make([]*l2.BridgeDomain_Interface, 0),
	}

	newVppAgentBridgeComposite := &vppAgentBridgeComposite{
		workspace:    configuration.Workspace,
		bridgeDomain: bridgeDomain,
	}

	_ = resetVppAgent()

	newVppAgentBridgeComposite.CreateBridgeDomain()

	return newVppAgentBridgeComposite
}
