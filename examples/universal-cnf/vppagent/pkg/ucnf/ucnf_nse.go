package ucnf

import (
	"github.com/danielvladco/k8s-vnet/pkg/nseconfig"
	"github.com/davecgh/go-spew/spew"
	"github.com/tiswanso/examples/examples/universal-cnf/vppagent/pkg/config"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"
	"os"
)

type UcnfNse struct {
	processEndpoints *config.ProcessEndpoints
}

func (ucnf *UcnfNse) Cleanup() {
	ucnf.processEndpoints.Cleanup()
}

func NewUcnfNse(configPath string, verify bool, backend config.UniversalCNFBackend, ceAddons config.CompositeEndpointAddons) *UcnfNse {
	cnfConfig := &nseconfig.Config{}
	f, err := os.Open(configPath)
	if err != nil {
		logrus.Fatal(err)
	}
	err = nseconfig.NewConfig(yaml.NewDecoder(f), cnfConfig)
	if err != nil {
		logrus.Fatal(err)
	}

	if err := backend.NewUniversalCNFBackend(); err != nil {
		logrus.Fatal(err)
	}

	if verify {
		spew.Dump(cnfConfig)
		return nil
	}

	configuration := common.FromEnv()

	pe := config.NewProcessEndpoints(backend, cnfConfig.Endpoints, configuration, ceAddons)

	ucnfnse := &UcnfNse{
		processEndpoints: pe,
	}

	logrus.Infof("Starting endpoints")
	// defer pe.Cleanup()

	if err := pe.Process(); err != nil {
		logrus.Fatalf("Error processing the new endpoints: %v", err)
	}
	return ucnfnse
}
