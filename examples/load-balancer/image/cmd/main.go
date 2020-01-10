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

package main

import (
	"bufio"
	"context"
	"os"
	"os/exec"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
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
		NewIpamEndpoint(configuration),
		newVppAgentBridgeComposite(configuration),
	)

	nsmEndpoint, err := endpoint.NewNSMEndpoint(context.TODO(), configuration, composite)
	if err != nil {
		logrus.Fatalf("%v", err)
	}

	if err := nsmEndpoint.Start(); err != nil {
		logrus.Fatalf("Unable to start the endpoint: %v", err)
	}

	scriptHook(context.TODO(), "endpoint_started")

	defer func() { _ = nsmEndpoint.Delete() }()

	<-c
}

func scriptHook(ctx context.Context, args ...string) {
	hook := os.Getenv("NSE_HOOK")
	if hook == "" {
		logrus.Debug("NSE_HOOK not set. Ignoring hook; ", args)
		return
	}

	script, err := exec.LookPath(hook)
	if err != nil {
		logrus.Error("NSE_HOOK not executable; ", hook, ", ignoring hook;", args)
		return
	}

	logrus.Info("Calling NSE_HOOK; ", args)

	cmd := exec.CommandContext(ctx, script, args...)

	stderr, err := cmd.StderrPipe()
	if err != nil {
		logrus.Error("NSE_HOOK failed to get stderr; ", args, err)
		return
	}

	if err = cmd.Start(); err != nil {
		logrus.Error("NSE_HOOK Start failed; ", args, err)
	}

	// Log all printouts to stderr
	scanner := bufio.NewScanner(stderr)
	for scanner.Scan() {
		logrus.Info("NSE_HOOK stderr; ", scanner.Text())
	}

	if err := cmd.Wait(); err != nil {
		logrus.Error("NSE_HOOK returned error; ", args, err)
	}
}
