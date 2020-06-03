package ipprovider

import (
	"bytes"
	"fmt"
	"net"

	"github.com/pkg/errors"
)

type validationErrors []error

func (e validationErrors) Error() string {
	b := bytes.NewBufferString("")
	for _, err := range e {
		_, _ = fmt.Fprintf(b, "\t%s", err)
	}
	return b.String()
}

func (m *Identifier) Validate() error {
	var errs validationErrors
	if m.GetConnectivityDomain() == "" {
		errs = append(errs, errors.Errorf("connectivity domain is a mandatory parameter %v", m))
	}
	if m.GetFqdn() == "" {
		errs = append(errs, errors.Errorf("fqdn is a mandatory parameter %v", m))
	}
	if m.GetName() == "" {
		errs = append(errs, errors.Errorf("name is a mandatory parameter %v", m))
	}
	if len(errs) != 0 {
		return errs
	}
	return nil
}

func (m *SubnetRequest) Validate() error {
	var errs validationErrors
	err := m.GetIdentifier().Validate()
	if err != nil {
		errs = append(errs, err)
	}
	switch m.GetAddrFamily().GetFamily() {
	case IpFamily_IPV4:
		if m.GetPrefixLen() > 32 || m.GetPrefixLen() < 2 {
			errs = append(errs, errors.New("invalid prefix length for IPv4 - should be positive integer >=2 and <=32"))
		}
	case IpFamily_IPV6:
		if m.GetPrefixLen() > 128 || m.GetPrefixLen() < 2 {
			errs = append(errs, errors.New("invalid prefix length for IPv4 - should be positive integer >=2 and <=32"))
		}
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

func (m *Subnet) Validate() error {
	var errs validationErrors
	err := m.GetIdentifier().Validate()
	if err != nil {
		errs = append(errs, err)
	}
	err = m.GetPrefix().Validate()
	if err != nil {
		errs = append(errs, err)
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

func (m *IpPrefix) Validate() error {
	ip, _, err := net.ParseCIDR(m.GetSubnet())
	if err != nil {
		return errors.Errorf("subnetcalculator is not valid: %v", err)
	}
	isIpV4 := ip.To4() != nil
	if m.GetAddrFamily().GetFamily() == IpFamily_IPV6 && isIpV4 {
		return errors.Errorf("IPv4 subnetcalculator given for IPv6 address family: %v", m)
	}
	if m.GetAddrFamily().GetFamily() == IpFamily_IPV4 && !isIpV4 {
		return errors.Errorf("IPv6 subnetcalculator given for IPv4 address family: %v", m)
	}
	return nil
}

func (m *IpPrefix) ToIpNet() *net.IPNet {
	_, ipNet, _ := net.ParseCIDR(m.GetSubnet())
	return ipNet
}

func (m *IpFamily) GetFamilyString() string {
	return m.Family.String()
}
