module github.com/networkservicemesh/examples

go 1.12

require (
	github.com/Nordix/simple-ipam v1.0.0
	github.com/danielvladco/k8s-vnet v0.0.0-20200326075255-ab8adf273c88
	github.com/davecgh/go-spew v1.1.1
	github.com/fsnotify/fsnotify v1.4.7
	github.com/golang/protobuf v1.3.2
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645
	github.com/ligato/vpp-agent v2.3.0+incompatible
	github.com/networkservicemesh/networkservicemesh/controlplane/api v0.2.0
	github.com/networkservicemesh/networkservicemesh/pkg v0.2.0
	github.com/networkservicemesh/networkservicemesh/sdk v0.2.0
	github.com/opentracing/opentracing-go v1.1.0
	github.com/sirupsen/logrus v1.4.2
	github.com/spf13/viper v1.5.0
	google.golang.org/grpc v1.23.1
	gopkg.in/yaml.v2 v2.2.4
)

replace (
	github.com/census-instrumentation/opencensus-proto v0.1.0-0.20181214143942-ba49f56771b8 => github.com/census-instrumentation/opencensus-proto v0.0.3-0.20181214143942-ba49f56771b8
	github.com/networkservicemesh/networkservicemesh => github.com/networkservicemesh/networkservicemesh v0.0.0-20191110020756-e6a23cc4eff7
	github.com/networkservicemesh/networkservicemesh/controlplane/api => github.com/networkservicemesh/networkservicemesh/controlplane/api v0.0.0-20191110020756-e6a23cc4eff7
	github.com/networkservicemesh/networkservicemesh/pkg => github.com/networkservicemesh/networkservicemesh/pkg v0.0.0-20191110020756-e6a23cc4eff7
	// github.com/networkservicemesh/networkservicemesh/sdk => github.com/networkservicemesh/networkservicemesh/sdk v0.0.0-20191110020756-e6a23cc4eff7
	github.com/networkservicemesh/networkservicemesh/sdk => ../networkservicemesh/sdk
	github.com/networkservicemesh/networkservicemesh/utils => github.com/networkservicemesh/networkservicemesh/utils v0.0.0-20191110020756-e6a23cc4eff7
)

// replace github.com/networkservicemesh/networkservicemesh => ../networkservicemesh
