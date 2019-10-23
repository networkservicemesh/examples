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
	"os"
	"sync"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools/jaeger"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools/spanhelper"
	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
)

const (
	defaultVPPAgentEndpoint = "localhost:9113"
)

type nsClientBackend struct {
	workspace        string
	vppAgentEndpoint string
}

func (nscb *nsClientBackend) New() error {
	if err := Reset(nscb.vppAgentEndpoint); err != nil {
		logrus.Fatal(err)
		return err
	}

	logrus.Infof("workspace: %s", nscb.workspace)

	return nil
}

func (nscb *nsClientBackend) Connect(connection *connection.Connection) error {
	logrus.Infof("nsClientBackend received: %v", connection)

	err := CreateVppInterface(connection, nscb.workspace, nscb.vppAgentEndpoint)
	if err != nil {
		logrus.Errorf("VPPAgent failed creating the requested interface with: %v", err)
	}

	return err
}

func main() {
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	// Init the tracer
	closer := jaeger.InitJaeger("vppagent-client")

	defer func() { _ = closer.Close() }()

	span := spanhelper.FromContext(context.Background(), "Start.VPPAgent.Client")
	defer span.Finish()

	workspace, ok := os.LookupEnv(common.WorkspaceEnv)
	if !ok {
		logrus.Fatalf("Failed getting %s", common.WorkspaceEnv)
	}

	backend := &nsClientBackend{
		workspace:        workspace,
		vppAgentEndpoint: defaultVPPAgentEndpoint,
	}

	configuration := common.FromEnv()
	outgoingClient, err := client.NewNSMClient(context.TODO(), configuration)

	if err != nil {
		logrus.Fatalf("Unable to create the NSM client %v", err)
	}

	err = backend.New()
	if err != nil {
		logrus.Fatalf("Unable to create the backend %v", err)
	}

	var outgoingConnection *connection.Connection
	outgoingConnection, err = outgoingClient.ConnectRetry(context.Background(), "if1", memif.MECHANISM,
		"Primary interface", client.ConnectionRetry, client.RequestDelay)

	if err != nil {
		logrus.Fatalf("Unable to connect %v", err)
	}

	err = backend.Connect(outgoingConnection)
	if err != nil {
		logrus.Fatalf("Unable to connect %v", err)
	}

	logrus.Info("nsm client: initialization is completed successfully, wait for Ctrl+C...")

	var wg sync.WaitGroup

	wg.Add(1)

	<-c
}
