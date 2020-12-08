// Copyright 2018 VMware, Inc.
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
	"fmt"
	"io/ioutil"
	"os"
	"strconv"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

func readEndpointsConf() (*Endpoint, error) {
	endpointsFile, err := os.Open("/etc/nsminfo/endpoints")
	if err != nil {
		return nil, fmt.Errorf("failed to read annotations file: %w", err)
	}
	defer endpointsFile.Close()

	byteValue, _ := ioutil.ReadAll(endpointsFile)

	result, err := GetEndpoint(byteValue)
	if err != nil {
		return nil, fmt.Errorf("failed to get enpoint configuration: %w", err)
	}

	return &result, nil
}

func main() {
	logrus.Info("Starting nse...")
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	registrations := []endpoint.Registration{}
	switchEndpoint := NewSwitchEndpoint("link")
	configuration := common.FromEnv()

	endpointsConfig, err := readEndpointsConf()
	if err != nil {
		logrus.Fatalf("Unable to parse the endpoints file: %v", err)
	}

	configuration.EndpointNetworkService = endpointsConfig.Name
	os.Setenv("TRACER_ENABLED", strconv.FormatBool(endpointsConfig.TracerEnabled))

	for _, config := range endpointsConfig.NetworkServices {
		service := common.FromEnv()
		service.EndpointNetworkService = endpointsConfig.Name
		service.EndpointLabels = config.Labels
		service.IPAddress = config.IPAddress

		endpoints := []networkservice.NetworkServiceServer{
			endpoint.NewConnectionEndpoint(service),
			endpoint.NewIpamEndpoint(service),
			endpoint.NewCustomFuncEndpoint("podName", endpoint.CreatePodNameMutator()),
		}

		if config.Route != "" {
			routeAddr := endpoint.CreateRouteMutator([]string{config.Route})
			endpoints = append(endpoints, endpoint.NewCustomFuncEndpoint("route", routeAddr))
		}

		switchEndpoint.Childs[config.Link] = endpoint.NewCompositeEndpoint(endpoints...)
		registrations = append(registrations, endpoint.MakeRegistration(service))
	}

	nsEndpoint, err := endpoint.NewNSMEndpoint(
		context.Background(),
		configuration,
		endpoint.NewCompositeEndpoint(
			endpoint.NewMonitorEndpoint(configuration),
			switchEndpoint,
		),
		endpoint.WithRegistrations(registrations...),
	)
	if err != nil {
		logrus.Fatalf("%v", err)
	}

	defer func() {
		_ = nsEndpoint.Delete()
	}()

	if err := nsEndpoint.Start(); err != nil {
		logrus.Fatalf("Unable to start the endpoint: %v", err)
	}

	// Capture signals to cleanup before exiting
	<-c
}
