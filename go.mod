module github.com/networkservicemesh/examples

go 1.12

require (
	github.com/Nordix/simple-ipam v1.0.0
	github.com/davecgh/go-spew v1.1.1
	github.com/fsnotify/fsnotify v1.4.7
	github.com/golang/protobuf v1.3.2
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645
	github.com/ligato/vpp-agent v2.5.1+incompatible
	github.com/networkservicemesh/networkservicemesh/controlplane/api v0.3.0
	github.com/networkservicemesh/networkservicemesh/pkg v0.3.0
	github.com/networkservicemesh/networkservicemesh/sdk v0.3.0
	github.com/networkservicemesh/networkservicemesh/utils v0.3.0
	github.com/opentracing/opentracing-go v1.1.0
	github.com/pkg/errors v0.8.1
	github.com/sirupsen/logrus v1.4.2
	github.com/spf13/viper v1.5.0
	google.golang.org/grpc v1.27.0
	gopkg.in/yaml.v2 v2.2.4
)

replace (
	github.com/census-instrumentation/opencensus-proto v0.1.0-0.20181214143942-ba49f56771b8 => github.com/census-instrumentation/opencensus-proto v0.0.3-0.20181214143942-ba49f56771b8
	github.com/networkservicemesh/networkservicemesh => github.com/networkservicemesh/networkservicemesh v0.0.0-20200207071630-fec0e0d83d6d
	github.com/networkservicemesh/networkservicemesh/controlplane/api => github.com/networkservicemesh/networkservicemesh/controlplane/api v0.0.0-20200207071630-fec0e0d83d6d
	github.com/networkservicemesh/networkservicemesh/pkg => github.com/networkservicemesh/networkservicemesh/pkg v0.0.0-20200207071630-fec0e0d83d6d
	github.com/networkservicemesh/networkservicemesh/sdk => github.com/networkservicemesh/networkservicemesh/sdk v0.0.0-20200207071630-fec0e0d83d6d
	github.com/networkservicemesh/networkservicemesh/utils => github.com/networkservicemesh/networkservicemesh/utils v0.0.0-20200207071630-fec0e0d83d6d
)
