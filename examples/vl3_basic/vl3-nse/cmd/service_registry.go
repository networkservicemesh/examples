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

const (
	POD_NAME = "podName"
	SERVICE_NAME = "service"
	PORT = "port"
	CLUSTER_NAME = "clusterName"
)

type validationErrors []error

type ServiceRegistry interface {
	RegisterWorkload(clusterName, podName, name, seviceName, connDom string, ipAddr []string, ports []int32) error
	RemoveWorkload(clusterName, podName, name, seviceName, connDom string, ipAddr []string, ports []int32) error
}

type ServiceRegistryClient interface {
	Stop()
}

type ServiceRegistryImpl struct {
	registryClient serviceregistry.RegistryClient
	connection *grpc.ClientConn
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

	workloads := []*serviceregistry.Workload{workload}
	serviceWorkload := &serviceregistry.ServiceWorkload{
		ServiceName:         seviceName,
		ConnectivityDomain:  connDom,
		Workloads:           workloads,
		Ports:               ports,
	}

	logrus.Infof("Sending workload register request: %d", serviceWorkload)
	_, err := s.registryClient.RegisterWorkload(context.Background(), serviceWorkload)
	if err != nil {
		logrus.Errorf("service registration not successful: %v", err)
	}

	return err
}

func (s *ServiceRegistryImpl) RemoveWorkload(clusterName, podName, name, seviceName, connDom string, ipAddr []string, ports []int32) error {
	workloadIdentifier := &serviceregistry.WorkloadIdentifier{
		Cluster:             clusterName,
		PodName:             podName,
		Name:                name,
	}

	workload := &serviceregistry.Workload{
		Identifier:          workloadIdentifier,
		IPAddress:           ipAddr,
	}

	workloads := []*serviceregistry.Workload{workload}
	serviceWorkload := &serviceregistry.ServiceWorkload{
		ServiceName:         seviceName,
		ConnectivityDomain:  connDom,
		Workloads:           workloads,
		Ports:               ports,
	}

	logrus.Infof("Sending workload remove request: %v", serviceWorkload)
	_, err := s.registryClient.RegisterWorkload(context.Background(), serviceWorkload)
	if err != nil {
		logrus.Errorf("service removal not successful: %v", err)
	}

	return err
}

func (s *ServiceRegistryImpl) Stop() {
	s.connection.Close()
}

func NewServiceRegistry(addr string) (ServiceRegistry, ServiceRegistryClient, error) {
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return nil, nil, fmt.Errorf("unable to connect to ipam server: %v", err)
	}

	registryClient := serviceregistry.NewRegistryClient(conn)
	serviceRegistry := ServiceRegistryImpl{registryClient: registryClient, connection: conn}

	return &serviceRegistry, &serviceRegistry, nil
}

func processPortsFromLabel(portLabel, separator string) ([]int32, error) {

	ports := strings.Split(portLabel, separator)
	servicePorts := []int32{}
	for _, port := range ports {
		portToInt, err := strconv.ParseInt(port, 10, 32)
		if err != nil {
			return nil, err
		}
		servicePorts = append(servicePorts, int32(portToInt))
	}

	return servicePorts, nil
}

func processWorkloadIps(workloadIps, separator string) []string {

	ips := strings.Split(workloadIps, separator)
	serviceIps := []string{}
	for _, ip := range ips {
		serviceIps = append(serviceIps, ip)
	}

	return serviceIps
}

func ValidateLabels(labels map[string]string) validationErrors {
	var errs validationErrors
	if labels[CLUSTER_NAME] == "" {
		errs = append(errs, fmt.Errorf("cluster name not found on labels"))
	}
	if labels[SERVICE_NAME] == "" {
		errs = append(errs, fmt.Errorf("serviceName not found on labels"))
	}
	if labels[PORT] == "" {
		errs = append(errs, fmt.Errorf("ports not found on labels"))
	}
	if labels[POD_NAME] == "" {
		errs = append(errs, fmt.Errorf("pod name not found on labels"))
	}
	if len(errs) != 0 {
		return errs
	}
	return nil
}
