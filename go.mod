module github.com/networkservicemesh/examples

go 1.12

replace k8s.io/client-go => k8s.io/client-go v0.0.0-20190409092706-ca8df85b1798

require (
	github.com/davecgh/go-spew v1.1.1
	github.com/fsnotify/fsnotify v1.4.7
	github.com/golang/protobuf v1.3.2
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645
	github.com/ligato/vpp-agent v2.1.1+incompatible
	github.com/networkservicemesh/networkservicemesh v0.0.0-20190819074500-aa8a648ad10d
	github.com/opentracing/opentracing-go v1.1.0
	github.com/sirupsen/logrus v1.4.2
	github.com/spf13/viper v1.4.0
	google.golang.org/grpc v1.23.0
	gopkg.in/yaml.v2 v2.2.2
)
