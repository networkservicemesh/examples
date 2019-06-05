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

package config

import (
	"context"
	"fmt"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/connectioncontext"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// UniversalCNFEndpoint is a Universal CNF Endpoint composite implementation
type UniversalCNFEndpoint struct {
	endpoint.BaseCompositeEndpoint
	endpoint  *Endpoint
	backend   UniversalCNFBackend
	nsmClient *client.NsmClient
}

// Request implements the request handler
func (uce *UniversalCNFEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	if uce.GetNext() == nil {
		err := fmt.Errorf("universal CNF needs next")
		logrus.Errorf("%v", err)
		return nil, err
	}

	conn, err := uce.GetNext().Request(ctx, request)
	if err != nil {
		logrus.Errorf("Next request failed: %v", err)
		return nil, err
	}

	if uce.endpoint.Action == nil {
		uce.endpoint.Action = &Action{}
	}

	action := uce.endpoint.Action

	if action.DPConfig == nil {
		action.DPConfig = uce.backend.NewDPConfig()
	}

	if err := uce.backend.ProcessEndpoint(action.DPConfig, uce.endpoint.IfName, conn); err != nil {
		logrus.Errorf("Failed to process: %+v", uce.endpoint.Action)
		return nil, err
	}

	if err := action.Process(uce.backend, uce.nsmClient); err != nil {
		logrus.Errorf("Failed to process: %+v", uce.endpoint.Action)
		return nil, err
	}
	return conn, nil
}

// Close implements the close handler
func (uce *UniversalCNFEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	logrus.Infof("Universal CNF DeleteConnection: %v", connection)

	if uce.GetNext() != nil {
		return uce.GetNext().Close(ctx, connection)
	}
	return &empty.Empty{}, nil
}

// Name returns the composite name
func (uce *UniversalCNFEndpoint) Name() string {
	return "Universal CNF"
}

// NewUniversalCNFEndpoint creates a MonitorEndpoint
func NewUniversalCNFEndpoint(backend UniversalCNFBackend, endpoint *Endpoint) *UniversalCNFEndpoint {

	var nsmClient *client.NsmClient
	var err error

	if endpoint.Action != nil && endpoint.Action.Client != nil {
		c := endpoint.Action.Client

		// Map the labels to a single comma separated string
		labels := labelStringFromMap(c.Labels)

		// Call the NS Client initiation
		nsConfig := &common.NSConfiguration{
			OutgoingNscName:   c.Name,
			OutgoingNscLabels: labels,
		}
		nsmClient, err = client.NewNSMClient(context.TODO(), nsConfig)
		if err != nil {
			logrus.Errorf("Unable to create the NSM client %v", err)
		}
	}

	self := &UniversalCNFEndpoint{
		endpoint:  endpoint,
		backend:   backend,
		nsmClient: nsmClient,
	}

	return self
}

func makeRouteMutator(routes []string) endpoint.ConnectionMutator {
	return func(c *connection.Connection) error {
		for _, r := range routes {
			c.Context.Routes = append(c.Context.Routes, &connectioncontext.Route{
				Prefix: r,
			})
		}
		return nil
	}
}
