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

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"

	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// SingleEndpoint keeps the state of a single endpoint instance
type SingleEndpoint struct {
	NSConfiguration *common.NSConfiguration
	NSComposite     *networkservice.NetworkServiceServer
	Endpoint        *Endpoint
	Cleanup         func()
}

// ProcessEndpoints keeps the state of the running network service endpoints
type ProcessEndpoints struct {
	Endpoints []*SingleEndpoint
}

type CompositeEndpointAddons interface {
	AddCompositeEndpoints(*common.NSConfiguration) *[]networkservice.NetworkServiceServer
}

// NewProcessEndpoints returns a new ProcessInitCommands struct
func NewProcessEndpoints(backend UniversalCNFBackend, endpoints []*Endpoint, nsconfig *common.NSConfiguration, ceAddons CompositeEndpointAddons) *ProcessEndpoints {
	result := &ProcessEndpoints{}

	for _, e := range endpoints {

		var ipPrefix string
		if e.Ipam != nil {
			ipPrefix = e.Ipam.PrefixPool
		}
		configuration := &common.NSConfiguration{
			NsmServerSocket:    nsconfig.NsmServerSocket,
			NsmClientSocket:    nsconfig.NsmClientSocket,
			Workspace:          nsconfig.Workspace,
			AdvertiseNseName:   e.Name,
			OutgoingNscName:    nsconfig.OutgoingNscName,
			AdvertiseNseLabels: labelStringFromMap(e.Labels),
			MechanismType:      memif.MECHANISM,
			IPAddress:          ipPrefix,
		}

		// Build the list of composites
		compositeEndpoints := []networkservice.NetworkServiceServer{
			endpoint.NewMonitorEndpoint(configuration),
			endpoint.NewConnectionEndpoint(configuration),
		}
		// Invoke any additional composite endpoint constructors via the add-on interface
		addCompositeEndpoints := ceAddons.AddCompositeEndpoints(configuration)
		if addCompositeEndpoints != nil {
			compositeEndpoints = append(compositeEndpoints, *addCompositeEndpoints...)
		}

		if e.Ipam != nil {
			/*
				compositeEndpoints = append(compositeEndpoints, endpoint.NewIpamEndpoint(&common.NSConfiguration{
					IPAddress: e.Ipam.PrefixPool,
				}))
			*/

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
			NSComposite:     &composite,
			Endpoint:        e,
		})
	}

	return result
}

// Process iterates over the init commands and applies them
func (pe *ProcessEndpoints) Process() error {
	for _, e := range pe.Endpoints {
		nsEndpoint, err := endpoint.NewNSMEndpoint(context.TODO(), e.NSConfiguration, *e.NSComposite)
		if err != nil {
			logrus.Fatalf("%v", err)
			return err
		}

		_ = nsEndpoint.Start()
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
