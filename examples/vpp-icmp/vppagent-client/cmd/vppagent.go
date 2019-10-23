package main

import (
	"context"
	"path"
	"time"

	"github.com/ligato/vpp-agent/api/configurator"
	"github.com/ligato/vpp-agent/api/models/vpp"
	vpp_interfaces "github.com/ligato/vpp-agent/api/models/vpp/interfaces"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/memif"

	"github.com/grpc-ecosystem/grpc-opentracing/go/otgrpc"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	opentracing "github.com/opentracing/opentracing-go"
	"github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

// CreateVppInterface creates a VPP memif interface
func CreateVppInterface(nscConnection *connection.Connection, baseDir, vppAgentEndpoint string) error {
	tracer := opentracing.GlobalTracer()
	conn, err := grpc.Dial(vppAgentEndpoint, grpc.WithInsecure(),
		grpc.WithUnaryInterceptor(
			otgrpc.OpenTracingClientInterceptor(tracer, otgrpc.LogPayloads())),
		grpc.WithStreamInterceptor(
			otgrpc.OpenTracingStreamClientInterceptor(tracer)))

	defer func() { _ = conn.Close() }()

	if err != nil {
		logrus.Errorf("can't dial grpc server: %v", err)
		return err
	}

	fullyQualifiedSocketFilename := path.Join(baseDir, memif.ToMechanism(nscConnection.GetMechanism()).GetSocketFilename())
	dataChange := &configurator.Config{
		VppConfig: &vpp.ConfigData{
			Interfaces: []*vpp_interfaces.Interface{
				{
					Name:        nscConnection.Id,
					Type:        vpp_interfaces.Interface_MEMIF,
					Enabled:     true,
					IpAddresses: []string{nscConnection.GetContext().GetIpContext().GetSrcIpAddr()},
					Link: &vpp_interfaces.Interface_Memif{
						Memif: &vpp_interfaces.MemifLink{
							Master:         false,
							SocketFilename: path.Join(fullyQualifiedSocketFilename),
						},
					},
				},
			},
		},
	}

	client := configurator.NewConfiguratorClient(conn)

	logrus.Infof("Sending DataChange to vppagent: %v", dataChange)

	if _, err := client.Update(context.Background(), &configurator.UpdateRequest{Update: dataChange}); err != nil {
		logrus.Error(err)

		_, _ = client.Delete(context.Background(), &configurator.DeleteRequest{Delete: dataChange})

		return err
	}

	return nil
}

// Reset resets the vpp configuration through the vpp-agent
func Reset(vppAgentEndpoint string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)

	defer cancel()

	if err := tools.WaitForPortAvailable(ctx, "tcp", vppAgentEndpoint, 100*time.Millisecond); err != nil {
		logrus.Errorf("reset: Timed out waiting for vpp-agent port")
		return err
	}

	tracer := opentracing.GlobalTracer()
	conn, err := grpc.Dial(vppAgentEndpoint, grpc.WithInsecure(),
		grpc.WithUnaryInterceptor(
			otgrpc.OpenTracingClientInterceptor(tracer, otgrpc.LogPayloads())),
		grpc.WithStreamInterceptor(
			otgrpc.OpenTracingStreamClientInterceptor(tracer)))

	if err != nil {
		logrus.Errorf("can't dial grpc server: %v", err)
		return err
	}

	defer func() { _ = conn.Close() }()

	client := configurator.NewConfiguratorClient(conn)

	logrus.Infof("Resetting vppagent...")

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
