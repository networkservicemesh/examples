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
	"time"

	"go.ligato.io/vpp-agent/v3/proto/ligato/configurator"

	"github.com/grpc-ecosystem/grpc-opentracing/go/otgrpc"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/opentracing/opentracing-go"
	"github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

const (
	defaultVPPAgentEndpoint = "localhost:9113"
	contextTimeOut          = 120 * time.Second
	portAvailableTimeOut    = 100 * time.Millisecond
)

func resetVppAgent() error {
	ctx, cancel := context.WithTimeout(context.Background(), contextTimeOut)
	defer cancel()

	if err := tools.WaitForPortAvailable(ctx, "tcp", defaultVPPAgentEndpoint, portAvailableTimeOut); err != nil {
		return err
	}

	conn, err := grpc.Dial(defaultVPPAgentEndpoint, grpc.WithInsecure())
	if err != nil {
		logrus.Errorf("can't dial grpc server: %v", err)
		return err
	}

	defer func() { _ = conn.Close() }()

	client := configurator.NewConfiguratorServiceClient(conn)

	logrus.Infof("Resetting vppagent..., with: %v", &configurator.Config{})

	_, err = client.Update(context.Background(), &configurator.UpdateRequest{
		Update:     &configurator.Config{},
		FullResync: true,
	})

	if err != nil {
		logrus.Errorf("failed to reset vppagent: %s", err)
	}

	logrus.Infof("Finished resetting vppagent...")

	return nil
}

// SendDataChangeToVppAgent send the udpate to the VPP-Agent
func sendDataChangeToVppAgent(dataChange *configurator.Config) error {
	ctx, cancel := context.WithTimeout(context.Background(), contextTimeOut)
	defer cancel()

	if err := tools.WaitForPortAvailable(ctx, "tcp", defaultVPPAgentEndpoint, portAvailableTimeOut); err != nil {
		logrus.Error(err)
		return err
	}

	tracer := opentracing.GlobalTracer()
	conn, err := grpc.Dial(defaultVPPAgentEndpoint, grpc.WithInsecure(),
		grpc.WithUnaryInterceptor(
			otgrpc.OpenTracingClientInterceptor(tracer, otgrpc.LogPayloads())),
		grpc.WithStreamInterceptor(
			otgrpc.OpenTracingStreamClientInterceptor(tracer)))

	if err != nil {
		logrus.Errorf("can't dial grpc server: %v", err)
		return err
	}

	defer func() { _ = conn.Close() }()

	client := configurator.NewConfiguratorServiceClient(conn)

	logrus.Infof("Sending DataChange to vppagent: %v", dataChange)

	if _, err = client.Update(ctx, &configurator.UpdateRequest{
		Update: dataChange,
	}); err != nil {
		logrus.Error(err)
		_, err = client.Delete(ctx, &configurator.DeleteRequest{
			Delete: dataChange,
		})
	}

	return err
}
