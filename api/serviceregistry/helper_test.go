package serviceregistry

import (
	"fmt"
	"testing"
)

func Test(t *testing.T) {
	var svc = ServiceWorkload{
		ServiceName:        "test",
		ConnectivityDomain: "tesst",
		Workloads: []*Workload{
			{
				Identifier: &WorkloadIdentifier{
					Cluster: "cluster0",
					PodName: "pod",
					Name:    "workload",
				},
				IPAddress: []string{"172.100.220.1/24"},
			},
		},
		Ports: []int32{1200, 1300},
	}
	err := svc.Validate()
	if err != nil {
		fmt.Print(err)
		t.Fail()
	}
}
