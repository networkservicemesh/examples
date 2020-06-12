package config

import (
	"bytes"
	"context"
	"fmt"
	"github.com/danielvladco/k8s-vnet/pkg/nseconfig"
	"github.com/gofrs/uuid"
	"github.com/sirupsen/logrus"
	"github.com/tiswanso/examples/api/ipam/ipprovider"
	"golang.org/x/sync/errgroup"
	"google.golang.org/grpc"
	"time"
)

type IpamServiceFactory func(addr string) IpamService

type IpamService interface {
	AllocateSubnet(ucnfEndpoint *nseconfig.Endpoint) (string, error)
}

type IpamServiceImpl struct {
	IpamAllocator     ipprovider.AllocatorClient
	RegisteredSubnets chan *ipprovider.Subnet
}

func (i *IpamServiceImpl) AllocateSubnet(ucnfEndpoint *nseconfig.Endpoint) (string, error) {
	var subnet *ipprovider.Subnet
	for j := 0; j < 6; j++ {
		var err error
		subnet, err = i.IpamAllocator.AllocateSubnet(context.Background(), &ipprovider.SubnetRequest{
			Identifier: &ipprovider.Identifier{
				Fqdn:               ucnfEndpoint.CNNS.Address,
				Name:               ucnfEndpoint.CNNS.Name + uuid.Must(uuid.NewV4()).String(),
				ConnectivityDomain: ucnfEndpoint.CNNS.ConnectivityDomain,
			},
			AddrFamily: &ipprovider.IpFamily{Family: ipprovider.IpFamily_IPV4},
			PrefixLen:  uint32(ucnfEndpoint.VL3.IPAM.PrefixLength),
		})
		if err != nil {
			if j == 5 {
				return "", fmt.Errorf("ipam allocation not successful: %v", err)

			}
			logrus.Errorf("ipam allocation not successful: %v \n waiting 60 seconds before retrying \n", err)
			time.Sleep(60 * time.Second)
		} else {
			break
		}
	}
	i.RegisteredSubnets <- subnet
	return subnet.Prefix.Subnet, nil
}

func (i *IpamServiceImpl) Renew(ctx context.Context, errorHandler func(err error)) error {
	g, ctx := errgroup.WithContext(ctx)
	var subnets = make(map[string]*ipprovider.Subnet)
	for {
		select {
		case subnet := <-i.RegisteredSubnets:
			g.Go(func() error {
				for range time.Tick(time.Duration(subnet.LeaseTimeout-1) * time.Hour) {
					_, err := i.IpamAllocator.RenewSubnetLease(ctx, subnet)
					if err != nil {
						errorHandler(err)
					}

					subnets[subnet.Identifier.Name] = subnet
				}
				return nil
			})
		case <-ctx.Done():
			logrus.Info("Cleaning registered subnets")
			close(i.RegisteredSubnets)
			err := i.Cleanup(subnets)
			if err != nil {
				errorHandler(err)
			}
			return g.Wait()
		}
	}
}

func (i *IpamServiceImpl) Cleanup(subnets map[string]*ipprovider.Subnet) error {
	var errs errors
	for _, v := range subnets {
		_, err := i.IpamAllocator.FreeSubnet(context.Background(), v)
		if err != nil {
			errs = append(errs, err)
		}
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

type errors []error

func (es errors) Error() string {
	buff := bytes.NewBufferString("multiple errors: \n")
	for _, e := range es {
		_, _ = fmt.Fprintf(buff, "\t%s\n", e)
	}
	return buff.String()
}

func NewIpamService(ctx context.Context, addr string) (IpamService, error) {
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return &IpamServiceImpl{}, fmt.Errorf("unable to connect to ipam server: %v", err)
	}

	ipamAllocator := ipprovider.NewAllocatorClient(conn)
	ipamService := IpamServiceImpl{
		IpamAllocator:     ipamAllocator,
		RegisteredSubnets: make(chan *ipprovider.Subnet),
	}
	go func() {
		logrus.Info("begin the ipam leased subnet renew process")
		if err := ipamService.Renew(ctx, func(err error) {
			if err != nil {
				logrus.Error("unable to renew the subnet", err)
			}
		}); err != nil {
			logrus.Error(err)
		}
	}()
	return &ipamService, nil
}
