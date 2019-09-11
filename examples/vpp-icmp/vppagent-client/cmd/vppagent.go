package main

import (
	"context"
	"time"

	"github.com/ligato/vpp-agent/api/configurator"

	"github.com/grpc-ecosystem/grpc-opentracing/go/otgrpc"
	"github.com/networkservicemesh/networkservicemesh/controlplane/pkg/apis/local/connection"
	"github.com/networkservicemesh/networkservicemesh/dataplane/vppagent/pkg/converter"
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

	if err != nil {
		logrus.Errorf("can't dial grpc server: %v", err)
		return err
	}
	defer func() { _ = conn.Close() }()
	client := configurator.NewConfiguratorClient(conn)

	conversionParameters := &converter.ConnectionConversionParameters{
		Name:      "SRC-" + nscConnection.GetId(),
		Terminate: true,
		Side:      converter.SOURCE,
		BaseDir:   baseDir,
	}
	dataChange, err := converter.NewMemifInterfaceConverter(nscConnection, conversionParameters).ToDataRequest(nil, true)

	if err != nil {
		logrus.Error(err)
		return err
	}
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
