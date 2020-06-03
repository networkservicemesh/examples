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

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/networkservicemesh/networkservicemesh/sdk/vppagent"
	"github.com/sirupsen/logrus"
)

func main() {
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	configuration := (&common.NSConfiguration{
		MechanismType: memif.MECHANISM,
	}).FromEnv()

	composite := endpoint.NewCompositeEndpoint(
		endpoint.NewMonitorEndpoint(configuration),
		endpoint.NewConnectionEndpoint(configuration),
		endpoint.NewIpamEndpoint(configuration),
		vppagent.NewMemifConnect(configuration),
		vppagent.NewCommit("localhost:9113", true),
	)

	nsmEndpoint, err := endpoint.NewNSMEndpoint(context.TODO(), configuration, composite)
	if err != nil {
		logrus.Panicf("%v", err)
	}

	logrus.Infof(">>>>>>>>>>> Starting the Endpoint")

	if err := nsmEndpoint.Start(); err != nil {
		logrus.Panicf("Error starting the endpoint: %v", err)
	}

	defer func() {
		if deleteErr := nsmEndpoint.Delete(); deleteErr != nil {
			logrus.Errorf("failed to delete endpoint: %v", deleteErr)
		}
	}()

	<-c
}
