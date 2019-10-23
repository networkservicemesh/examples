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
	"bytes"
	"context"
	"os"
	"os/exec"

	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/sirupsen/logrus"
)

// IptablesEndpoint is a monitoring composite
type IptablesEndpoint struct {
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
	incomingConnection := request.GetConnection()
	logrus.Infof("Iptables UpdateConnection: %v", incomingConnection)
	ie.invoke()

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	return incomingConnection, nil
}

// Close implements the close handler
func (ie *IptablesEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	logrus.Infof("Iptables DeleteConnection: %v", connection)

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Close(ctx, connection)
	}

	ie.invoke()

	return &empty.Empty{}, nil
}

// Name returns the composite name
func (ie *IptablesEndpoint) Name() string {
	return "Iptables"
}

func (ie *IptablesEndpoint) invoke() {
	var out bytes.Buffer

	cmd := exec.Command(ie.script, ie.arguments...) // #nosec
	cmd.Stdout = &out
	err := cmd.Run()

	if err != nil {
		logrus.Error(err)
	}

	logrus.Infof("%v", out)
}

// NewIptablesEndpoint creates a IptablesEndpoint
func NewIptablesEndpoint() *IptablesEndpoint {
	self := &IptablesEndpoint{
		script:    getIptablesScript(),
		arguments: os.Args[1:],
	}

	return self
}
