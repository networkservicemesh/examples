package main

import (
	"context"

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
)

// RunnerEndpoint is an endpoint that
type RunnerEndpoint struct {
	script      string
	connections map[string]connection.Connection
}

// Request implements Request method from NetworkServiceServer
// Consumes from ctx context.Context:
//	   Next
func (ine *RunnerEndpoint) Request(ctx context.Context, request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {

	// if interfaceName, ok := request.GetRequestConnection().GetLabels()[interfaceNameKey]; ok {
	// 	c := request.GetConnection()
	// 	if _, ok := ine.Names[interfaceName]; !ok {
	// 		ine.Names[interfaceNameKey] = 0
	// 	} else {
	// 		count := ine.Names[interfaceNameKey] + 1
	// 		if count > maxInterfaces {
	// 			return nil, errors.Errorf("Reached the max interface count for %s", interfaceName)
	// 		}
	// 		ine.Names[interfaceNameKey] = count
	// 		interfaceName = interfaceName + strconv.Itoa(count)
	// 	}
	// 	endpoint.Log(ctx).Infof("Setting interface name to %s", interfaceName)
	// 	c.Mechanism.Parameters[mechanism.InterfaceNameKey] = interfaceName
	// }

	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Request(ctx, request)
	}

	endpoint.Log(ctx).Infof("%v endpoint completed on connection: %v", ine.Name(), request.GetConnection())
	return request.GetConnection(), nil
}

// Close implements Close method from NetworkServiceServer
// Consumes from ctx context.Context:
//	   Next
func (ine *RunnerEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	if endpoint.Next(ctx) != nil {
		return endpoint.Next(ctx).Close(ctx, connection)
	}
	return &empty.Empty{}, nil
}

// Name returns the composite name
func (ine *RunnerEndpoint) Name() string {
	return "InterfaceName"
}

// NewRunnerEndpoint create RunnerEndpoint
func NewRunnerEndpoint(script string) *RunnerEndpoint {
	return &RunnerEndpoint{
		script:      script,
		connections: map[string]connection.Connection{},
	}
}
