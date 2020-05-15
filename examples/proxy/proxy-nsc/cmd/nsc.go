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
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/connection/mechanisms/kernel"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools/jaeger"
	"github.com/networkservicemesh/networkservicemesh/pkg/tools/spanhelper"
	"github.com/networkservicemesh/networkservicemesh/sdk/client"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
)

const (
	proxyHostEnv      = "PROXY_HOST"
	defaultProxyHost  = ":8080"
	proxyHeaderPrefix = "nsm-"
	connectTimeout    = 15 * time.Second
)

var state struct {
	sync.RWMutex
	interfaceID int
	client      *client.NsmClient
}

func nsmDirector(req *http.Request) {
	state.Lock()
	defer state.Unlock()

	// Convert the request headers to labels
	state.client.ClientLabels = make(map[string]string)

	// Ensure we always label ourselves as `app=proxy`
	state.client.ClientLabels["app"] = "proxy"

	for name, headers := range req.Header {
		name = strings.ToLower(name)
		if strings.HasPrefix(name, proxyHeaderPrefix) {
			name = strings.TrimPrefix(name, proxyHeaderPrefix)
			state.client.ClientLabels[name] = strings.ToLower(headers[0])
		}
	}

	ifname := "nsm" + strconv.Itoa(state.interfaceID)
	state.interfaceID++

	// We define a connection establish timeout to 15 seconds
	ctx, cancelOp := context.WithTimeout(context.Background(), connectTimeout)
	defer cancelOp()

	outgoing, err := state.client.Connect(ctx, ifname, kernel.MECHANISM, "Primary interface")
	if err != nil {
		// cancel request
		logrus.Errorf("Error: %v", err)
		return
	}

	ipv4Addr, _, err := net.ParseCIDR(outgoing.GetContext().GetIpContext().GetDstIpAddr())
	if err != nil {
		log.Fatal(err)
	}

	req.URL.Scheme = "http"
	req.URL.Host = ipv4Addr.String()
	req.URL.Path = "/"
	req.Host = req.URL.Host

	go func() {
		<-req.Context().Done()
		logrus.Infof("Connection goes down for: %v", outgoing)
		_ = state.client.Close(context.TODO(), outgoing)
	}()
}

func proxyHost() string {
	proxyHost, ok := os.LookupEnv(proxyHostEnv)
	if !ok {
		proxyHost = defaultProxyHost
	}

	return proxyHost
}

func main() {
	// Init the tracer
	closer := jaeger.InitJaeger("proxy-nsc")

	defer func() { _ = closer.Close() }()

	span := spanhelper.FromContext(context.Background(), "Start.Proxy.NSC")
	defer span.Finish()

	// Create the NSM client
	state.interfaceID = 0
	configuration := common.FromEnv()
	client, err := client.NewNSMClient(context.Background(), configuration)

	if err != nil {
		logrus.Fatalf("Unable to create the NSM client %v", err)
	}

	state.client = client

	// Create the reverse proxy
	reverseProxy := httputil.NewSingleHostReverseProxy(&url.URL{})
	reverseProxy.Director = nsmDirector

	logrus.Infof("Listen and Serve on %v", proxyHost())
	err = http.ListenAndServe(proxyHost(), reverseProxy)

	if err != nil {
		logrus.Errorf("Listen and serve failed with error: %v", err)
	}
}
