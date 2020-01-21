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

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connectioncontext"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// UniversalCNFEndpoint is a Universal CNF Endpoint composite implementation
type UniversalCNFEndpoint struct {
	endpoint  *Endpoint
	backend   UniversalCNFBackend
	nsmClient *client.NsmClient
}

// Request implements the request handler
func (uce *UniversalCNFEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {
	conn := request.GetConnection()

	if uce.endpoint.Action == nil {
		uce.endpoint.Action = &Action{}
	}

	action := uce.endpoint.Action

	if action.DPConfig == nil {
		action.DPConfig = uce.backend.NewDPConfig()
	}

	if err := uce.backend.ProcessEndpoint(action.DPConfig, uce.endpoint.Name, uce.endpoint.IfName, conn); err != nil {
		logrus.Errorf("Failed to process: %+v", uce.endpoint.Action)
		return nil, err
	}

	if err := action.Process(ctx, uce.backend, uce.nsmClient); err != nil {
		logrus.Errorf("Failed to process: %+v", uce.endpoint.Action)
		return nil, err
	}

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	return request.GetConnection(), nil
}

// Close implements the close handler
func (uce *UniversalCNFEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	logrus.Infof("Universal CNF DeleteConnection: %v", connection)

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Close(ctx, connection)
	}

	return &empty.Empty{}, nil
}

// Name returns the composite name
func (uce *UniversalCNFEndpoint) Name() string {
	return "Universal CNF"
}

// NewUniversalCNFEndpoint creates a MonitorEndpoint
func NewUniversalCNFEndpoint(backend UniversalCNFBackend, endpoint *Endpoint,
	nsConfig *common.NSConfiguration) *UniversalCNFEndpoint {
	var nsmClient *client.NsmClient

	var err error

	if endpoint.Action != nil && endpoint.Action.Client != nil {
		c := endpoint.Action.Client

		// Map the labels to a single comma separated string
		labels := labelStringFromMap(c.Labels)

		// Call the NS Client initiation
		nsConfig.ClientNetworkService = c.Name
		nsConfig.ClientLabels = labels
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
	return func(ctx context.Context, c *connection.Connection) error {
		for _, r := range routes {
			c.GetContext().GetIpContext().DstRoutes = append(c.GetContext().GetIpContext().DstRoutes, &connectioncontext.Route{
				Prefix: r,
			})
		}

		return nil
	}
}
