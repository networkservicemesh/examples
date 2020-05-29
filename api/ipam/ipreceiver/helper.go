package ipreceiver

import (
	"bytes"
	"fmt"
)

type validationErrors []error

func (e validationErrors) Error() string {
	b := bytes.NewBufferString("")
	for _, err := range e {
		_, _ = fmt.Fprintf(b, "\t%s", err)
	}
	return b.String()
}

func (m *IpRange) Validate() error {
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

func (m *RangeIdentifier) Validate() error {
	var errs validationErrors
	if m.GetConnectivityDomain() == "" {
		errs = append(errs, fmt.Errorf("connectivity domain is a mandatory parameter %v", m))
	}
	if m.GetFqdn() == "" {
		errs = append(errs, fmt.Errorf("fqdn is a mandatory parameter %v", m))
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

