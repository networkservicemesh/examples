package main

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/sirupsen/logrus"
	"github.com/tiswanso/examples/api/serviceregistry"

	"google.golang.org/grpc"
)

const (
	POD_NAME = "podName"
	SERVICE_NAME = "service"
	PORT = "port"
	CLUSTER_NAME = "clusterName"
)

type validationErrors []error

func NewServiceRegistry(addr string) (ServiceRegistry, ServiceRegistryClient, error) {
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return nil, nil, fmt.Errorf("unable to connect to ipam server: %w", err)
	}

	registryClient := serviceregistry.NewRegistryClient(conn)
	serviceRegistry := serviceRegistry{registryClient: registryClient, connection: conn}

	return &serviceRegistry, &serviceRegistry, nil
}


type ServiceRegistry interface {
	RegisterWorkload(ctx context.Context, workloadLabels map[string]string, connDom string, ipAddr []string) error
	RemoveWorkload(ctx context.Context, workloadLabels map[string]string, connDom string, ipAddr []string) error
}

type ServiceRegistryClient interface {
	Stop()
}

type serviceRegistry struct {
	registryClient serviceregistry.RegistryClient
	connection *grpc.ClientConn
}

func (s *serviceRegistry) RegisterWorkload(ctx context.Context, workloadLabels map[string]string, connDom string, ipAddr []string) error {
	ports, err := processPortsFromLabel(workloadLabels[PORT], ";")
	if err != nil {
		logrus.Error(err)
	}

	workloadIdentifier := &serviceregistry.WorkloadIdentifier{
		Cluster:             workloadLabels[CLUSTER_NAME],
		PodName:             workloadLabels[POD_NAME],
		Name:                workloadLabels[SERVICE_NAME],
	}

	workload := &serviceregistry.Workload{
		Identifier:          workloadIdentifier,
		IPAddress:           ipAddr,
	}

	workloads := []*serviceregistry.Workload{workload}
	serviceWorkload := &serviceregistry.ServiceWorkload{
		ServiceName:         workloadLabels[SERVICE_NAME],
		ConnectivityDomain:  connDom,
		Workloads:           workloads,
		Ports:               ports,
	}

	logrus.Infof("Sending workload register request: %v", serviceWorkload)
	_, err = s.registryClient.RegisterWorkload(ctx, serviceWorkload)
	if err != nil {
		logrus.Errorf("service registration not successful: %w", err)
	}

	return err
}

func (s *serviceRegistry) RemoveWorkload(ctx context.Context, workloadLabels map[string]string, connDom string, ipAddr []string) error {
	ports, err := processPortsFromLabel(workloadLabels[PORT], ";")
	if err != nil {
		logrus.Error(err)
	}

	workloadIdentifier := &serviceregistry.WorkloadIdentifier{
		Cluster:             workloadLabels[CLUSTER_NAME],
		PodName:             workloadLabels[POD_NAME],
		Name:                workloadLabels[SERVICE_NAME],
	}

	workload := &serviceregistry.Workload{
		Identifier:          workloadIdentifier,
		IPAddress:           ipAddr,
	}

	workloads := []*serviceregistry.Workload{workload}
	serviceWorkload := &serviceregistry.ServiceWorkload{
		ServiceName:         workloadLabels[SERVICE_NAME],
		ConnectivityDomain:  connDom,
		Workloads:           workloads,
		Ports:               ports,
	}

	logrus.Infof("Sending workload remove request: %v", serviceWorkload)
	_, err = s.registryClient.RemoveWorkload(ctx, serviceWorkload)
	if err != nil {
		logrus.Errorf("service removal not successful: %w", err)
	}

	return err
}

func (s *serviceRegistry) Stop() {
	s.connection.Close()
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
	serviceIps = append(serviceIps, ips...)

	return serviceIps
}

func ValidateInLabels(labels map[string]string) validationErrors {
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
