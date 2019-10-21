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
	"net"

	"github.com/Nordix/simple-ipam/pkg/ipam"
	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// IpamEndpoint a comment
type IpamEndpoint struct {
	ipam   *ipam.IPAM
	SelfIP net.IP
}

// Request implements the request handler
func (ice *IpamEndpoint) Request(
	ctx context.Context, request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {
	srcIP, err := ice.ipam.Allocate()
	if err != nil {
		return nil, err
	}

	newConnection := request.GetConnection()
	// Update source/dst IP's
	newConnection.Context.IpContext.SrcIpAddr = (&net.IPNet{
		IP:   srcIP,
		Mask: ice.ipam.CIDR.Mask,
	}).String()
	newConnection.Context.IpContext.DstIpAddr = (&net.IPNet{
		IP:   ice.SelfIP,
		Mask: ice.ipam.CIDR.Mask,
	}).String()

	err = newConnection.IsComplete()
	if err != nil {
		logrus.Errorf("New connection is not complete: %v", err)
		return nil, err
	}

	logrus.Infof("ipam completed on connection: %v", newConnection)

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	return newConnection, nil
}

// Close implements the close handler
func (ice *IpamEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	addr, _, err := net.ParseCIDR(connection.Context.IpContext.SrcIpAddr)
	if err == nil {
		ice.ipam.Free(addr)
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
	ipam, err := ipam.New(configuration.IPAddress)
	if err != nil {
		panic(err.Error())
	}

	selfIP, err := ipam.Allocate()
	if err != nil {
		panic(err.Error())
	}

	return &IpamEndpoint{
		ipam:   ipam,
		SelfIP: selfIP,
	}
}
