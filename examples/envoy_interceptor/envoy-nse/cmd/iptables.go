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
	"fmt"
	"os"
	"os/exec"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

// IptablesEndpoint is a monitoring composite
type IptablesEndpoint struct {
	endpoint.BaseCompositeEndpoint
	script    string
	arguments []string
}

const (
	iptablesScriptEnv     = "IPTABLES_SCRIPT"
	defaultIptablesScript = "/usr/bin/iptables.sh"
)

func getIptablesScript() string {
	if script, ok := os.LookupEnv(iptablesScriptEnv); ok {
		return script
	}
	return defaultIptablesScript
}

// Request implements the request handler
func (ie *IptablesEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	if ie.GetNext() == nil {
		err := fmt.Errorf("iptables needs next")
		logrus.Errorf("%v", err)
		return nil, err
	}

	incomingConnection, err := ie.GetNext().Request(ctx, request)
	if err != nil {
		logrus.Errorf("Next request failed: %v", err)
		return nil, err
	}

	logrus.Infof("Iptables UpdateConnection: %v", incomingConnection)
	ie.invoke()

	return incomingConnection, nil
}

// Close implements the close handler
func (ie *IptablesEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	logrus.Infof("Iptables DeleteConnection: %v", connection)
	if ie.GetNext() != nil {
		return ie.GetNext().Close(ctx, connection)
	}
	ie.invoke()
	return &empty.Empty{}, nil
}

func (ie *IptablesEndpoint) invoke() {
	out, err := exec.Command(ie.script, ie.arguments...).Output()
	logrus.Infof("%s", out)
	if err != nil {
		logrus.Error(err)
	}
}

// NewIptablesEndpoint creates a IptablesEndpoint
func NewIptablesEndpoint(configuration *common.NSConfiguration) *IptablesEndpoint {
	// ensure the env variables are processed
	if configuration == nil {
		configuration = &common.NSConfiguration{}
	}
	configuration.CompleteNSConfiguration()

	self := &IptablesEndpoint{
		script:    getIptablesScript(),
		arguments: os.Args[1:],
	}

	return self
}
