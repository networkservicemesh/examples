package main

import (
	"github.com/sirupsen/logrus"

	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/utils"

)

var version string

func main() {
	logrus.Info("Starting nsc-sidecar...")
	logrus.Infof("Version: %v", version)
	utils.PrintAllEnv(logrus.StandardLogger())
	clientApp := NewNSMClientApp(common.FromEnv())
	clientApp.Run()
}
