module github.com/tiswanso/examples

go 1.14

require (
	github.com/Nordix/simple-ipam v1.0.0
	github.com/danielvladco/k8s-vnet v0.3.3
	github.com/davecgh/go-spew v1.1.1
	github.com/fsnotify/fsnotify v1.4.7
	github.com/gofrs/uuid v3.2.0+incompatible
	github.com/golang/protobuf v1.3.5
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645
	github.com/networkservicemesh/networkservicemesh/controlplane/api v0.3.0
	github.com/networkservicemesh/networkservicemesh/pkg v0.3.0
	github.com/networkservicemesh/networkservicemesh/sdk v0.3.0
	github.com/opentracing/opentracing-go v1.1.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.4.2
	github.com/spf13/viper v1.5.0
	go.ligato.io/vpp-agent/v3 v3.1.0
	golang.org/x/sync v0.0.0-20190423024810-112230192c58
	google.golang.org/grpc v1.27.1
	gopkg.in/yaml.v2 v2.2.8
)

replace (
	github.com/census-instrumentation/opencensus-proto v0.1.0-0.20181214143942-ba49f56771b8 => github.com/census-instrumentation/opencensus-proto v0.0.3-0.20181214143942-ba49f56771b8
	github.com/networkservicemesh/networkservicemesh/controlplane => github.com/tiswanso/networkservicemesh/controlplane v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/controlplane/api => github.com/tiswanso/networkservicemesh/controlplane/api v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/forwarder/api => github.com/tiswanso/networkservicemesh/forwarder/api v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/k8s => github.com/tiswanso/networkservicemesh/k8s v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/k8s/pkg/apis => github.com/tiswanso/networkservicemesh/k8s/pkg/apis v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/pkg => github.com/tiswanso/networkservicemesh/pkg v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/sdk => github.com/tiswanso/networkservicemesh/sdk v0.2.0-vl3
	github.com/networkservicemesh/networkservicemesh/utils => github.com/tiswanso/networkservicemesh/utils v0.2.0-vl3
)
