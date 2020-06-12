// Copyright 2019 Cisco Systems, Inc.
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
	"github.com/danielvladco/k8s-vnet/pkg/nseconfig"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
	"github.com/tiswanso/examples/examples/universal-cnf/vppagent/pkg/ucnf"
	"github.com/tiswanso/examples/examples/universal-cnf/vppagent/pkg/vppagent"
	"os"
	"strings"
)

const (
	defaultConfigPath   = "/etc/universal-cnf/config.yaml"
	defaultPluginModule = ""
)

// Flags holds the command line flags as supplied with the binary invocation
type Flags struct {
	ConfigPath string
	Verify     bool
}

type fnGetNseName func() string

// Process will parse the command line flags and init the structure members
func (mf *Flags) Process() {
	flag.StringVar(&mf.ConfigPath, "file", defaultConfigPath, " full path to the configuration file")
	flag.BoolVar(&mf.Verify, "verify", false, "only verify the configuration, don't run")
	flag.Parse()
}

type vL3CompositeEndpoint struct {
}

func (e vL3CompositeEndpoint) AddCompositeEndpoints(nsConfig *common.NSConfiguration, ucnfEndpoint *nseconfig.Endpoint) *[]networkservice.NetworkServiceServer {

	logrus.WithFields(logrus.Fields{
		"prefixPool":         nsConfig.IPAddress,
		"nsConfig.IPAddress": nsConfig.IPAddress,
	}).Infof("Creating vL3 IPAM endpoint")
	ipamEp := endpoint.NewIpamEndpoint(&common.NSConfiguration{
		IPAddress: nsConfig.IPAddress,
	})

	var nsRemoteIpList []string
	nsRemoteIpListStr, ok := os.LookupEnv("NSM_REMOTE_NS_IP_LIST")
	if ok {
		nsRemoteIpList = strings.Split(nsRemoteIpListStr, ",")
	}
	compositeEndpoints := []networkservice.NetworkServiceServer{
		ipamEp,
		newVL3ConnectComposite(nsConfig, nsConfig.IPAddress,
			&vppagent.UniversalCNFVPPAgentBackend{}, nsRemoteIpList, func() string {
				return ucnfEndpoint.NseName
			}, ucnfEndpoint.VL3.IPAM.DefaultPrefixPool),
	}

	return &compositeEndpoints
}

// exported the symbol named "CompositeEndpointPlugin"

func main() {
	// Capture signals to cleanup before exiting
	logrus.Info("starting endpoint")
	c := tools.NewOSSignalChannel()

	logrus.SetOutput(os.Stdout)
	logrus.SetLevel(logrus.TraceLevel)

	mainFlags := &Flags{}
	mainFlags.Process()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	vl3 := vL3CompositeEndpoint{}
	ucnfNse := ucnf.NewUcnfNse(mainFlags.ConfigPath, mainFlags.Verify, &vppagent.UniversalCNFVPPAgentBackend{}, vl3, ctx)
	logrus.Info("endpoint started")

	defer ucnfNse.Cleanup()
	<-c
}

/*
var (
	nsmEndpoint *endpoint.NsmEndpoint
)

func main() {

	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	composite := endpoint.NewCompositeEndpoint(
		endpoint.NewMonitorEndpoint(nil),
		endpoint.NewIpamEndpoint(nil),
		newVL3ConnectComposite(nil),
		endpoint.NewConnectionEndpoint(nil))

	nsme, err := endpoint.NewNSMEndpoint(context.TODO(), nil, composite)
	if err != nil {
		logrus.Fatalf("%v", err)
	}
	nsmEndpoint = nsme
	_ = nsmEndpoint.Start()
	logrus.Infof("Started NSE --got name %s", nsmEndpoint.GetName())
	defer func() { _ = nsmEndpoint.Delete() }()

	// Capture signals to cleanup before exiting
	<-c
}

func GetMyNseName() string {
	return nsmEndpoint.GetName()
}

*/
