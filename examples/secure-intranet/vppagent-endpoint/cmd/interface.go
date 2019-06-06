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

	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/crossconnect"
	"github.com/sirupsen/logrus"
)

func (vxc *vppAgentXConnComposite) crossConnecVppInterfaces(crossConnect *crossconnect.CrossConnect,
	connect bool, baseDir string) (*crossconnect.CrossConnect, *configurator.Config, error) {

	src := crossConnect.GetLocalSource()
	srcName := "SRC-" + crossConnect.GetId()
	dst := crossConnect.GetLocalDestination()
	dstName := "DST-" + crossConnect.GetId()

	SocketDir := path.Dir(path.Join(baseDir, src.GetMechanism().GetSocketFilename()))
	if err := os.MkdirAll(SocketDir, os.ModePerm); err != nil {
		return nil, nil, err
	}

	dataChange := &configurator.Config{
		VppConfig: &vpp.ConfigData{
			Interfaces: []*interfaces.Interface{
				{
					Name:    srcName,
					Type:    interfaces.Interface_MEMIF,
					Enabled: true,
					Link: &interfaces.Interface_Memif{
						Memif: &interfaces.MemifLink{
							Master:         true,
							SocketFilename: path.Join(baseDir, src.GetMechanism().GetSocketFilename()),
						},
					},
				},
				{
					Name:    dstName,
					Type:    interfaces.Interface_MEMIF,
					Enabled: true,
					Link: &interfaces.Interface_Memif{
						Memif: &interfaces.MemifLink{
							Master:         false,
							SocketFilename: path.Join(baseDir, dst.GetMechanism().GetSocketFilename()),
						},
					},
				},
			},
			XconnectPairs: []*l2.XConnectPair{
				{
					ReceiveInterface:  srcName,
					TransmitInterface: dstName,
				},
				{
					ReceiveInterface:  dstName,
					TransmitInterface: srcName,
				},
			},
		},
	}

	logrus.Infof("Sending DataChange to vppagent: %+v", dataChange)

	err := sendDataChangeToVppAgent(dataChange, connect)
	if err != nil {
		logrus.Error(err)
		return crossConnect, dataChange, err
	}
	return crossConnect, dataChange, nil
}
