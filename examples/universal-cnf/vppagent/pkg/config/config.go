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
	"io/ioutil"
	"os/exec"

	"github.com/davecgh/go-spew/spew"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/sirupsen/logrus"
	"go.ligato.io/vpp-agent/v3/proto/ligato/vpp"
	"gopkg.in/yaml.v2"
)

// Command is a struct to describe exec.Command call arguments
type Command struct {
	Name string
	Args []string
}

// Client is a struct to describe a NS Client setup
type Client struct {
	Name   string
	Labels map[string]string
	Routes []string
	IfName string
}

func (c *Client) Process(ctx context.Context,
	backend UniversalCNFBackend, dpconfig interface{}, nsmclient *client.NsmClient) error {
	conn, err := nsmclient.ConnectRetry(ctx, c.IfName, memif.MECHANISM, "VPP interface "+c.IfName, client.ConnectionRetry, client.RequestDelay)
	if err != nil {
		logrus.Errorf("Error creating %s: %v", c.IfName, err)
		return err
	}

	err = backend.ProcessClient(dpconfig, c.IfName, conn)

	return err
}

// Action is a struct to describe exec.Command, a Client initiation or a Forwarder configuration
type Action struct {
	Command  *Command
	Client   *Client
	DPConfig *vpp.ConfigData
}

// Process executes the actions as defined
func (a *Action) Process(ctx context.Context, backend UniversalCNFBackend, nsmclient *client.NsmClient) error {
	command := a.Command
	if command != nil && len(command.Name) > 0 {
		logrus.Infof("Executing %v", command)

		out, err := exec.Command(command.Name, command.Args...).Output() // #nosec
		logrus.Infof("Result %s", out)

		if err != nil {
			logrus.Errorf("Command execution failed with: %v", err)
		}
	}

	client := a.Client
	if client != nil && nsmclient != nil {
		logrus.Infof("Running client %+v", client)

		if a.DPConfig == nil {
			a.DPConfig = &vpp.ConfigData{}
		}

		if err := client.Process(ctx, backend, a.DPConfig, nsmclient); err != nil {
			logrus.Errorf("Error running the client: %v", err)
		}
	}

	if err := backend.ProcessDPConfig(a.DPConfig); err != nil {
		logrus.Errorf("Error processing dpconfig: %+v", a.DPConfig)
	}

	return nil
}

// Cleanup the action
func (a *Action) Cleanup() error {
	return nil
}

// IPAM holds the configuration of the IP address management
type IPAM struct {
	PrefixPool string
	Routes     []string
}

// Endpoint is a struct to describe a NS Endpoint setup and the related VPP config changes
type Endpoint struct {
	Name    string
	Labels  map[string]string
	IfName  string
	Ipam    *IPAM
	Action  *Action
	NseName string
}

type UniversalCNFBackend interface {
	NewDPConfig() *vpp.ConfigData
	NewUniversalCNFBackend() error
	ProcessClient(dpconfig interface{}, ifName string, conn *connection.Connection) error
	ProcessEndpoint(dpconfig interface{}, serviceName, ifName string, conn *connection.Connection) error
	ProcessDPConfig(dpconfig interface{}) error
}

// UniversalCNFConfig hold the CNF configuration
type UniversalCNFConfig struct {
	InitActions []*Action
	Endpoints   []*Endpoint
	backend     UniversalCNFBackend
}

// NewUniversalCNFConfig creates an empty CNF configuration
func NewUniversalCNFConfig(backend UniversalCNFBackend) (*UniversalCNFConfig, error) {
	if err := backend.NewUniversalCNFBackend(); err != nil {
		logrus.Errorf("Error creating the UniversalCNFBackend: %v", err)
		return nil, err
	}

	return &UniversalCNFConfig{
		backend: backend,
	}, nil
}

// InitConfig init CNF config from a specified path (or default)
func (c *UniversalCNFConfig) InitConfig(configpath string) error {
	configYAML, err := ioutil.ReadFile(configpath)
	if err != nil {
		logrus.Fatalf("error: %v", err)
	}

	return c.InitConfigFromRawYaml(configYAML)
}

// InitConfigFromRawYaml init CNF config from a byte slice
func (c *UniversalCNFConfig) InitConfigFromRawYaml(rawyaml []byte) error {
	err := yaml.UnmarshalStrict(rawyaml, &c)
	if err != nil {
		logrus.Errorf("error: %v", err)
		return err
	}

	return nil
}

func (c *UniversalCNFConfig) GetBackend() UniversalCNFBackend {
	return c.backend
}

// Dump dumps the current state of the CNF config using spew
func (c *UniversalCNFConfig) Dump() {
	spew.Dump(c)
}
