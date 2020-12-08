// Copyright 2020 Samsung Electronics
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

	"github.com/golang/protobuf/ptypes/empty"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection"
	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/pkg/errors"
)

// SwitchEndpoint is a simple NetworkServiceServer composition primitive which
// forwards incoming requests into one of its child NetworkServiceServer's based
// on the specified label.
type SwitchEndpoint struct {
	Label  string
	Childs map[string]networkservice.NetworkServiceServer
}

// Request implements NetworkServiceServer interface method.
func (s *SwitchEndpoint) Request(ctx context.Context,
	request *networkservice.NetworkServiceRequest) (*connection.Connection, error) {
	e, err := s.selectEndpoint(request.Connection)
	if err == nil {
		return e.Request(ctx, request)
	}

	return nil, err
}

// Close implements NetworkServiceServer interface method.
func (s *SwitchEndpoint) Close(ctx context.Context, connection *connection.Connection) (*empty.Empty, error) {
	e, err := s.selectEndpoint(connection)
	if err == nil {
		return e.Close(ctx, connection)
	}

	return nil, err
}

func (s *SwitchEndpoint) selectEndpoint(c *connection.Connection) (networkservice.NetworkServiceServer, error) {
	result := s.Childs[c.Labels[s.Label]]
	if result == nil {
		return nil, errors.New("Couldn't match the connection")
	}

	return result, nil
}

// NewSwitchEndpoint creates a new SwitchEndpoint object.
func NewSwitchEndpoint(label string) *SwitchEndpoint {
	return &SwitchEndpoint{
		Label:  label,
		Childs: map[string]networkservice.NetworkServiceServer{},
	}
}
