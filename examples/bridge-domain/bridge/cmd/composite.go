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

	"github.com/golang/protobuf/ptypes/empty"
	l2 "github.com/ligato/vpp-agent/api/models/vpp/l2"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

type vppAgentBridgeComposite struct {
	endpoint.BaseCompositeEndpoint
	workspace    string
	bdInterfaces []*l2.BridgeDomain_Interface
}

func (vbc *vppAgentBridgeComposite) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	if vbc.GetNext() == nil {
		logrus.Fatal("Should have Next set")
	}

	incoming, err := vbc.GetNext().Request(ctx, request)
	if err != nil {
		logrus.Error(err)
		return nil, err
	}

	err = vbc.insertVPPAgentInterface(incoming, true, vbc.workspace)
	if err != nil {
		logrus.Error(err)
		return nil, err
	}

	return incoming, nil
}

func (vbc *vppAgentBridgeComposite) Close(ctx context.Context, conn *connection.Connection) (*empty.Empty, error) {
	// remove from connections
	err := vbc.insertVPPAgentInterface(conn, false, vbc.workspace)
	if err != nil {
		logrus.Error(err)
		return &empty.Empty{}, err
	}

	if vbc.GetNext() != nil {
		vbc.GetNext().Close(ctx, conn)
	}

	return &empty.Empty{}, nil
}

// vppAgentBridgeComposite creates a new VPP Agent composite
func newVppAgentBridgeComposite(configuration *common.NSConfiguration) *vppAgentBridgeComposite {
	// ensure the env variables are processed
	if configuration == nil {
		configuration = &common.NSConfiguration{}
	}
	configuration.CompleteNSConfiguration()

	logrus.Infof("vppAgentBridgeComposite")

	newVppAgentBridgeComposite := &vppAgentBridgeComposite{
		workspace: configuration.Workspace,
	}
	_ = resetVppAgent()

	return newVppAgentBridgeComposite
}
