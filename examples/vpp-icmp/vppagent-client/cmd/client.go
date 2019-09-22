// Copyright (c) 2018 Cisco and/or its affiliates.
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

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/local/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/local/connection"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/vppagent"
	"github.com/opentracing/opentracing-go"
	"github.com/sirupsen/logrus"
)

const (
	defaultVPPAgentEndpoint = "localhost:9113"
)

func main() {
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	// Setup OpenTracing
	tracer, closer := tools.InitJaeger("nsc")
	opentracing.SetGlobalTracer(tracer)
	defer func() { _ = closer.Close() }()

	// Create Configuration Object
	configuration := &common.NSConfiguration{}

	// Create synthetic Endpoint we can use to connect vppagent as a client using memif
	composite := endpoint.NewCompositeEndpoint(
		vppagent.NewClientMemifConnect(configuration),
		vppagent.NewCommit(configuration, defaultVPPAgentEndpoint, true),
	)

	// Request the Network Service
	_, err := composite.Request(context.TODO(), &networkservice.NetworkServiceRequest{
		MechanismPreferences: []*connection.Mechanism{
			{
				Type: connection.MechanismType_MEM_INTERFACE,
			},
		},
	})

	// Error handling
	if err != nil {
		logrus.Fatalf("Error attempting to connect to Network Service: %+v", err)
	}

	// Declare victory!
	logrus.Info("nsm client: initialization is completed successfully, wait for Ctrl+C...")

	// Wait until we receive a signal like SIGTERM
	<-c
}
