package ucnf

import (
	"github.com/networkservicemesh/examples/examples/universal-cnf/vppagent/pkg/config"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/sirupsen/logrus"
)

type UcnfNse struct {
	processEndpoints *config.ProcessEndpoints
}

func (ucnf *UcnfNse) Cleanup() {
	ucnf.processEndpoints.Cleanup()
}

func NewUcnfNse(configPath string, verify bool, backend config.UniversalCNFBackend, ceAddons config.CompositeEndpointAddons) *UcnfNse {
	cnfConfig, err := config.NewUniversalCNFConfig(backend)
	if err != nil {
		logrus.Fatalf("Error creating the Universal CNF Config")
	}

	if err := cnfConfig.InitConfig(configPath); err != nil {
		logrus.Fatalf("Error processing [%s]: %v", configPath, err)
	}

	if verify {
		cnfConfig.Dump()
		return nil
	}

	configuration := common.FromEnv()
	pia := config.NewProcessInitActions(cnfConfig.GetBackend(), cnfConfig.InitActions, configuration)
	defer pia.Cleanup()

	if err := pia.Process(cnfConfig.GetBackend()); err != nil {
		logrus.Fatalf("Error processing the init actions: %v", err)
	}

	//ceAddon, err := GetPluginCompositeEndpoints(mainFlags.CompositeEndpointPluginModule)
	//if err != nil {
	//	logrus.Errorf("Failed to get composite endpoints addon method from plugin")
	//}
	//ceAddon := CompositeEndpointPlugin

	pe := config.NewProcessEndpoints(cnfConfig.GetBackend(), cnfConfig.Endpoints, ceAddons)

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
