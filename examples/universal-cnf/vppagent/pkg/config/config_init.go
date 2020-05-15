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

	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
)

// SingleClient is a single client instance combining the CNF configuration and the NS Client
type SingleAction struct {
	Action    *Action
	nsmClient *client.NsmClient
}

// ProcessInitActions keeps the state of the initial setup
type ProcessInitActions struct {
	InitActions []*SingleAction
}

// NewProcessInitActions returns a new ProcessInitCommands struct
func NewProcessInitActions(backend UniversalCNFBackend, initactions []*Action,
	nsConfig *common.NSConfiguration) *ProcessInitActions {
	pia := &ProcessInitActions{}

	for _, a := range initactions {
		var nsmClient *client.NsmClient

		var err error

		if a.Client != nil {
			c := a.Client

			// Map the labels to a single comma separated string
			labels := labelStringFromMap(c.Labels)

			// Call the NS Client initiation
			nsConfig.ClientNetworkService = c.Name
			nsConfig.ClientLabels = labels
			nsConfig.Routes = c.Routes

			nsmClient, err = client.NewNSMClient(context.TODO(), nsConfig)
			if err != nil {
				logrus.Errorf("Unable to create the NSM client %v", err)
			}
		}

		pia.InitActions = append(pia.InitActions, &SingleAction{
			Action:    a,
			nsmClient: nsmClient,
		})
	}

	return pia
}

// Process iterates over the init commands and applies them
func (pia *ProcessInitActions) Process(ctx context.Context, backend UniversalCNFBackend) error {
	for _, sa := range pia.InitActions {
		if err := sa.Action.Process(ctx, backend, sa.nsmClient); err != nil {
			logrus.Errorf("Failed processing %+v", sa.Action)
			return err
		}
	}

	return nil
}

// Cleanup - cleans up before exit
func (pia *ProcessInitActions) Cleanup() {
	for _, sa := range pia.InitActions {
		if err := sa.Action.Cleanup(); err != nil {
			logrus.Errorf("Failed cleaning %+v", sa.Action)
		}
	}
}
