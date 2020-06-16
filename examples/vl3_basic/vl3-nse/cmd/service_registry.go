package main

import (
	"context"
	"fmt"
	"github.com/sirupsen/logrus"
	"github.com/tiswanso/examples/api/serviceregistry"
	"google.golang.org/grpc"
	"strconv"
	"strings"
)

type ServiceRegistry interface {
	RegisterWorkload(clusterName, podName, name, seviceName, connDom string, ipAddr []string, ports []int32) error
}

type ServiceRegistryImpl struct {
	registryClient serviceregistry.RegistryClient
}

func (s *ServiceRegistryImpl) RegisterWorkload(clusterName, podName, name, seviceName, connDom string, ipAddr []string, ports []int32) error {
	workloadIdentifier := &serviceregistry.WorkloadIdentifier{
		Cluster:             clusterName,
		PodName:             podName,
		Name:                name,
	}

	workload := &serviceregistry.Workload{
		Identifier:          workloadIdentifier,
		IPAddress:           ipAddr,
	}

	workloads := make([]*serviceregistry.Workload, 1)

	workloads[0] = workload

	serviceWorkload := &serviceregistry.ServiceWorkload{
		ServiceName:         seviceName,
		ConnectivityDomain:  connDom,
		Workloads:           workloads,
		Ports:               ports,
	}

	logrus.Infof("Sending workload register request: %v", serviceWorkload)
	_, err := s.registryClient.RegisterWorkload(context.Background(), serviceWorkload)
	if err != nil {
		logrus.Errorf("service registration not successful: %v", err)
	}

	return err
}

func NewServiceRegistry(addr string) (ServiceRegistry, error) {
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return &ServiceRegistryImpl{}, fmt.Errorf("unable to connect to ipam server: %v", err)
	}

	registryClient := serviceregistry.NewRegistryClient(conn)
	serviceRegistry := ServiceRegistryImpl{registryClient: registryClient}

	return &serviceRegistry, nil
}

func processPortsFromLabel(portLabel, separator string) ([]int32, error) {

	ports := strings.Split(portLabel, separator)
	var intPorts = make([]int32, len(ports))
	for _, port := range ports {
		portToInt, err := strconv.ParseInt(port, 10, 32)
		if err != nil {
			return nil, err
		}
		intPorts = append(intPorts, int32(portToInt))
	}

	return intPorts, nil
}

func processWorkloadIps(workloadIps, separator string) []string {

	ips := strings.Split(workloadIps, separator)
	var workloads = make([]string, len(ips))
	for _, ip := range ips {
		workloads = append(workloads, ip)
	}

	return workloads
}