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
	"context"
	"flag"
	"os"

	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/sirupsen/logrus"

	config "github.com/networkservicemesh/examples/examples/universal-cnf/vppagent/cmd/config"
	vppagent "github.com/networkservicemesh/examples/examples/universal-cnf/vppagent/cmd/vppagent"
)

const (
	defaultConfigPath = "/etc/universal-cnf/config.yaml"
)

// Flags holds the command line flags as supplied with the binary invocation
type Flags struct {
	ConfigPath string
	Verify     bool
}

// Process will parse the command line flags and init the structure members
func (mf *Flags) Process() {
	flag.StringVar(&mf.ConfigPath, "file", defaultConfigPath, " full path to the configuration file")
	flag.BoolVar(&mf.Verify, "verify", false, "only verify the configuration, don't run")
	flag.Parse()
}

func main() {
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	logrus.SetOutput(os.Stdout)
	logrus.SetLevel(logrus.TraceLevel)

	mainFlags := &Flags{}
	mainFlags.Process()

	cnfConfig, err := config.NewUniversalCNFConfig(&vppagent.UniversalCNFVPPAgentBackend{})
	if err != nil {
		logrus.Fatalf("Error creating the Universal CNF Config")
	}

	if err := cnfConfig.InitConfig(mainFlags.ConfigPath); err != nil {
		logrus.Fatalf("Error processing [%s]: %v", mainFlags.ConfigPath, err)
	}

	if mainFlags.Verify {
		cnfConfig.Dump()
		os.Exit(0)
	}

	pia := config.NewProcessInitActions(cnfConfig.GetBackend(), cnfConfig.InitActions)
	defer pia.Cleanup()

	if err := pia.Process(context.Background(), cnfConfig.GetBackend()); err != nil {
		logrus.Fatalf("Error processing the init actions: %v", err)
	}

	pe := config.NewProcessEndpoints(cnfConfig.GetBackend(), cnfConfig.Endpoints)
	defer pe.Cleanup()

	if err := pe.Process(); err != nil {
		logrus.Fatalf("Error processing the new endpoints: %v", err)
	}

	<-c
}
