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
	"os"
	"path"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"
	"go.ligato.io/vpp-agent/v3/proto/ligato/configurator"
	vpp "go.ligato.io/vpp-agent/v3/proto/ligato/vpp"
	interfaces "go.ligato.io/vpp-agent/v3/proto/ligato/vpp/interfaces"
	l2 "go.ligato.io/vpp-agent/v3/proto/ligato/vpp/l2"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/sirupsen/logrus"
)

func getDataChange(conn *connection.Connection, bd *l2.BridgeDomain, ifName, baseDir string) *configurator.Config {
	return &configurator.Config{
		VppConfig: &vpp.ConfigData{
			Interfaces: []*interfaces.Interface{
				{
					Name:    ifName,
					Type:    interfaces.Interface_MEMIF,
					Enabled: true,
					Link: &interfaces.Interface_Memif{
						Memif: &interfaces.MemifLink{
							Master:         true,
							SocketFilename: path.Join(baseDir, memif.ToMechanism(conn.GetMechanism()).GetSocketFilename()),
						},
					},
				},
			},
			BridgeDomains: []*l2.BridgeDomain{
				bd,
			},
		},
	}
}

func (vbc *vppAgentBridgeComposite) insertVPPAgentInterface(conn *connection.Connection,
	connect bool, baseDir string) error {
	ifName := "client-" + conn.GetId()

	SocketDir := path.Dir(path.Join(baseDir, memif.ToMechanism(conn.GetMechanism()).GetSocketFilename()))
	if err := os.MkdirAll(SocketDir, os.ModePerm); err != nil {
		return err
	}

	if connect {
		vbc.bridgeDomain.Interfaces = append(vbc.bridgeDomain.Interfaces, &l2.BridgeDomain_Interface{
			Name: ifName,
		})
	} else {
		for k, v := range vbc.bridgeDomain.Interfaces {
			if v.Name == ifName {
				vbc.bridgeDomain.Interfaces = append(vbc.bridgeDomain.Interfaces[:k], vbc.bridgeDomain.Interfaces[k+1:]...)
				break
			}
		}
	}

	err := sendDataChangeToVppAgent(getDataChange(conn, vbc.bridgeDomain, ifName, baseDir))
	if err != nil {
		logrus.Error(err)
		return err
	}

	return nil
}
