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

	"github.com/ligato/vpp-agent/api/configurator"
	vpp "github.com/ligato/vpp-agent/api/models/vpp"
	interfaces "github.com/ligato/vpp-agent/api/models/vpp/interfaces"
	l2 "github.com/ligato/vpp-agent/api/models/vpp/l2"

	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/connection"
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
							SocketFilename: path.Join(baseDir, conn.GetMechanism().GetSocketFilename()),
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

func (vxc *vppAgentBridgeComposite) insertVPPAgentInterface(conn *connection.Connection,
	connect bool, baseDir string) error {

	ifName := "client-" + conn.GetId()

	SocketDir := path.Dir(path.Join(baseDir, conn.GetMechanism().GetSocketFilename()))
	if err := os.MkdirAll(SocketDir, os.ModePerm); err != nil {
		return err
	}

	var bd *l2.BridgeDomain

	if connect {
		vxc.bdInterfaces = append(vxc.bdInterfaces, &l2.BridgeDomain_Interface{
			Name:                    ifName,
			BridgedVirtualInterface: false,
		})

		bd = &l2.BridgeDomain{
			Name:                "bd1",
			Flood:               false,
			UnknownUnicastFlood: false,
			Forward:             true,
			Learn:               true,
			ArpTermination:      false,
			Interfaces:          vxc.bdInterfaces,
		}
	} else {
		bd = &l2.BridgeDomain{
			Name:                "bd1",
			Flood:               false,
			UnknownUnicastFlood: false,
			Forward:             true,
			Learn:               true,
			ArpTermination:      false,
			Interfaces: []*l2.BridgeDomain_Interface{
				{
					Name:                    ifName,
					BridgedVirtualInterface: false,
				},
			},
		}
	}

	dataChange := getDataChange(conn, bd, ifName, baseDir)

	logrus.Infof("Sending DataChange to vppagent: %+v", dataChange)

	err := sendDataChangeToVppAgent(dataChange, connect)
	if err != nil {
		logrus.Error(err)
		return err
	}
	return nil
}
