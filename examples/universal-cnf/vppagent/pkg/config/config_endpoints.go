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

	"github.com/danielvladco/k8s-vnet/pkg/nseconfig"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"

	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// SingleEndpoint keeps the state of a single endpoint instance
type SingleEndpoint struct {
	NSConfiguration *common.NSConfiguration
	NSComposite     networkservice.NetworkServiceServer
	Endpoint        *nseconfig.Endpoint
	Cleanup         func()
}

// ProcessEndpoints keeps the state of the running network service endpoints
type ProcessEndpoints struct {
	Endpoints []*SingleEndpoint
}

type CompositeEndpointAddons interface {
	AddCompositeEndpoints(*common.NSConfiguration, *nseconfig.Endpoint) *[]networkservice.NetworkServiceServer
}

// NewProcessEndpoints returns a new ProcessInitCommands struct
func NewProcessEndpoints(backend UniversalCNFBackend, endpoints []*nseconfig.Endpoint, nsconfig *common.NSConfiguration, ceAddons CompositeEndpointAddons, ctx context.Context) *ProcessEndpoints {
	result := &ProcessEndpoints{}

	for _, e := range endpoints {

		configuration := &common.NSConfiguration{
			NsmServerSocket:        nsconfig.NsmServerSocket,
			NsmClientSocket:        nsconfig.NsmClientSocket,
			Workspace:              nsconfig.Workspace,
			EndpointNetworkService: e.Name,
			ClientNetworkService:   nsconfig.ClientNetworkService,
			EndpointLabels:         labelStringFromMap(e.Labels),
			ClientLabels:           nsconfig.ClientLabels,
			MechanismType:          memif.MECHANISM,
			IPAddress:              e.VL3.IPAM.DefaultPrefixPool,
			Routes:                 nil,
		}
		if e.VL3.IPAM.ServerAddress != "" {
			var err error
			ipamService, err := NewIpamService(ctx, e.VL3.IPAM.ServerAddress)
			if err != nil {
				logrus.Error(err)
			} else {
				configuration.IPAddress, err = ipamService.AllocateSubnet(e)
				if err != nil {
					logrus.Error(err)
				}
			}
		}
		// Build the list of composites
		compositeEndpoints := []networkservice.NetworkServiceServer{
			endpoint.NewMonitorEndpoint(configuration),
			endpoint.NewConnectionEndpoint(configuration),
		}
		// Invoke any additional composite endpoint constructors via the add-on interface
		addCompositeEndpoints := ceAddons.AddCompositeEndpoints(configuration, e)
		if addCompositeEndpoints != nil {
			compositeEndpoints = append(compositeEndpoints, *addCompositeEndpoints...)
		}

		// if the default DefaultPrefixPool is set and central ipam server address is not set then use a ipam endpoint
		if e.VL3.IPAM.DefaultPrefixPool != "" && e.VL3.IPAM.ServerAddress == "" {
			compositeEndpoints = append(compositeEndpoints, endpoint.NewIpamEndpoint(&common.NSConfiguration{
				NsmServerSocket:        nsconfig.NsmServerSocket,
				NsmClientSocket:        nsconfig.NsmClientSocket,
				Workspace:              nsconfig.Workspace,
				EndpointNetworkService: nsconfig.EndpointNetworkService,
				ClientNetworkService:   nsconfig.ClientNetworkService,
				EndpointLabels:         nsconfig.EndpointLabels,
				ClientLabels:           nsconfig.ClientLabels,
				MechanismType:          nsconfig.MechanismType,
				IPAddress:              e.VL3.IPAM.DefaultPrefixPool,
				Routes:                 nil,
			}))
		}

		if len(e.VL3.IPAM.Routes) > 0 {
			routeAddr := makeRouteMutator(e.VL3.IPAM.Routes)
			compositeEndpoints = append(compositeEndpoints, endpoint.NewCustomFuncEndpoint("route", routeAddr))
		}

		compositeEndpoints = append(compositeEndpoints, NewUniversalCNFEndpoint(backend, e))
		// Compose the Endpoint
		composite := endpoint.NewCompositeEndpoint(compositeEndpoints...)

		result.Endpoints = append(result.Endpoints, &SingleEndpoint{
			NSConfiguration: configuration,
			NSComposite:     composite,
			Endpoint:        e,
		})
	}

	return result
}

// Process iterates over the init commands and applies them
func (pe *ProcessEndpoints) Process() error {
	for _, e := range pe.Endpoints {
		nsEndpoint, err := endpoint.NewNSMEndpoint(context.TODO(), e.NSConfiguration, e.NSComposite)
		if err != nil {
			logrus.Fatalf("%v", err)
			return err
		}

		_ = nsEndpoint.Start()
		e.Endpoint.NseName = nsEndpoint.GetName()
		logrus.Infof("Started endpoint %s", nsEndpoint.GetName())
		e.Cleanup = func() { _ = nsEndpoint.Delete() }
	}

	return nil
}

// Cleanup - cleans up before exit
func (pe *ProcessEndpoints) Cleanup() {
	for _, e := range pe.Endpoints {
		e.Cleanup()
	}
}
