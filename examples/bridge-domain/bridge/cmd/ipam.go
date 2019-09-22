// Copyright 2018, 2019 VMware, Inc.
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
	"math/rand"
	"time"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connectioncontext"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/local/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/local/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/networkservicemesh/networkservicemesh/sdk/prefix_pool"
	"github.com/sirupsen/logrus"
)

// IpamEndpoint the IPAM endpoint
type IpamEndpoint struct {
	PrefixPool prefix_pool.PrefixPool
	SelfIP     string
}

// Request implements the request handler
func (ice *IpamEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	/* Exclude the prefixes from the pool of available prefixes */
	excludedPrefixes, err := ice.PrefixPool.ExcludePrefixes(request.Connection.Context.IpContext.ExcludedPrefixes)
	if err != nil {
		return nil, err
	}

	/* Determine whether the pool is IPv4 or IPv6 */
	currentIPFamily := connectioncontext.IpFamily_IPV4
	if common.IsIPv6(ice.PrefixPool.GetPrefixes()[0]) {
		currentIPFamily = connectioncontext.IpFamily_IPV6
	}

	srcIP, dstIP, prefixes, err := ice.PrefixPool.Extract(request.Connection.Id,
		currentIPFamily, request.Connection.Context.IpContext.ExtraPrefixRequest...)
	if err != nil {
		return nil, err
	}

	/* Release the actual prefixes that were excluded during IPAM */
	err = ice.PrefixPool.ReleaseExcludedPrefixes(excludedPrefixes)
	if err != nil {
		return nil, err
	}

	// We'll use same DST IP for all connections
	if ice.SelfIP == "" {
		ice.SelfIP = dstIP.String()
	}

	newConnection := request.GetConnection()
	// Update source/dst IP's
	newConnection.Context.IpContext.SrcIpAddr = srcIP.String()
	newConnection.Context.IpContext.DstIpAddr = ice.SelfIP

	newConnection.Context.IpContext.ExtraPrefixes = prefixes

	err = newConnection.IsComplete()
	if err != nil {
		logrus.Errorf("New connection is not complete: %v", err)
		return nil, err
	}

	logrus.Infof("IPAM completed on connection: %v", newConnection)

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	return newConnection, nil
}

// Close implements the close handler
func (ice *IpamEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	prefix, requests, err := ice.PrefixPool.GetConnectionInformation(connection.GetId())
	logrus.Infof("Release connection prefixes network: %s extra requests: %v", prefix, requests)
	if err != nil {
		logrus.Errorf("Error: %v", err)
	}
	err = ice.PrefixPool.Release(connection.GetId())
	if err != nil {
		logrus.Error("Release error: ", err)
	}
	if endpoint.Next(ctx) != nil {
		if _, err := endpoint.Next(ctx).Close(ctx, connection); err != nil {
			return &empty.Empty{}, nil
		}
	}
	return &empty.Empty{}, nil
}

// Name returns the composite name
func (ice *IpamEndpoint) Name() string {
	return "IPAM"
}

// NewIpamEndpoint creates a IpamEndpoint
func NewIpamEndpoint(configuration *common.NSConfiguration) *IpamEndpoint {
	// ensure the env variables are processed
	if configuration == nil {
		configuration = &common.NSConfiguration{}
	}
	configuration.CompleteNSConfiguration()

	pool, err := prefix_pool.NewPrefixPool(configuration.IPAddress)
	if err != nil {
		panic(err.Error())
	}

	rand.Seed(time.Now().UTC().UnixNano())

	self := &IpamEndpoint{
		PrefixPool: pool,
		SelfIP:     "",
	}

	return self
}
