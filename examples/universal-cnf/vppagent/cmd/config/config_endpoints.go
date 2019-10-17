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

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/local/networkservice"

	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// SingleEndpoint keeps the state of a single endpoint instance
type SingleEndpoint struct {
	NSConfiguration *common.NSConfiguration
	NSComposite     networkservice.NetworkServiceServer
	Endpoint        *Endpoint
	Cleanup         func()
}

// ProcessEndpoints keeps the state of the running network service endpoints
type ProcessEndpoints struct {
	Endpoints []*SingleEndpoint
}

// NewProcessEndpoints returns a new ProcessInitCommands struct
func NewProcessEndpoints(backend UniversalCNFBackend, endpoints []*Endpoint,
	nsconfig *common.NSConfiguration) *ProcessEndpoints {
	result := &ProcessEndpoints{}

	for _, e := range endpoints {
		configuration := &common.NSConfiguration{
			NsmServerSocket:    nsconfig.NsmServerSocket,
			NsmClientSocket:    nsconfig.NsmClientSocket,
			Workspace:          nsconfig.Workspace,
			AdvertiseNseName:   e.Name,
			OutgoingNscName:    nsconfig.OutgoingNscName,
			AdvertiseNseLabels: labelStringFromMap(e.Labels),
			OutgoingNscLabels:  nsconfig.OutgoingNscLabels,
			MechanismType:      "mem",
			IPAddress:          nsconfig.IPAddress,
			Routes:             nil,
		}

		// Build the list of composites
		compositeEndpoints := []networkservice.NetworkServiceServer{
			endpoint.NewMonitorEndpoint(configuration),
			endpoint.NewConnectionEndpoint(configuration),
		}

		if e.Ipam != nil {
			compositeEndpoints = append(compositeEndpoints, endpoint.NewIpamEndpoint((&common.NSConfiguration{
				NsmServerSocket:    nsconfig.NsmServerSocket,
				NsmClientSocket:    nsconfig.NsmClientSocket,
				Workspace:          nsconfig.Workspace,
				AdvertiseNseName:   nsconfig.AdvertiseNseName,
				OutgoingNscName:    nsconfig.OutgoingNscName,
				AdvertiseNseLabels: nsconfig.AdvertiseNseLabels,
				OutgoingNscLabels:  nsconfig.OutgoingNscLabels,
				MechanismType:      nsconfig.MechanismType,
				IPAddress:          e.Ipam.PrefixPool,
				Routes:             nil,
			})))

			if len(e.Ipam.Routes) > 0 {
				routeAddr := makeRouteMutator(e.Ipam.Routes)
				compositeEndpoints = append(compositeEndpoints, endpoint.NewCustomFuncEndpoint("route", routeAddr))
			}
		}

		compositeEndpoints = append(compositeEndpoints, NewUniversalCNFEndpoint(backend, e, nsconfig))
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
