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
	"fmt"

	"github.com/fsnotify/fsnotify"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

const (
	aclRules = "aclRules"
)

var viperConfig *viper.Viper

func initConfig() {
	viperConfig = viper.New()
	viperConfig.SetConfigName("config")
	viperConfig.AddConfigPath("/etc/vppagent-acl-filter/")

	if err := viperConfig.ReadInConfig(); err == nil {
		viperConfig.WatchConfig()
		viperConfig.OnConfigChange(func(e fsnotify.Event) {
			fmt.Println("Config file changed:", e.Name)
		})
	} else {
		logrus.Errorf("Error reading the config file: %s \n", err)
	}

	logrus.Infof("ACL filter config finished")
}

func getAclRulesConfig() map[string]string {
	return viperConfig.GetStringMapString(aclRules)
}
