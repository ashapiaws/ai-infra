package collector

import (
	"bufio"
	"bytes"
	"os/exec"
	"strings"
	"sync"

	"github.com/prometheus/client_golang/prometheus"
	log "github.com/sirupsen/logrus"
)

// ServiceStatus represents the status of a systemd service
type ServiceStatus struct {
	Name        string
	LoadState   string
	ActiveState string
	SubState    string
	Description string
}

// SystemctlCollector collects systemd service information
type SystemctlCollector struct {
	mu              sync.RWMutex
	services        map[string]*ServiceStatus
	failedServices  []string
	criticalServices []string

	// Prometheus metrics
	servicesTotal *prometheus.Desc
	servicesFailed *prometheus.Desc
	servicesActive *prometheus.Desc
	lastCollectionTime *prometheus.Desc
}

// NewSystemctlCollector creates a new systemctl collector
func NewSystemctlCollector() *SystemctlCollector {
	return &SystemctlCollector{
		services: make(map[string]*ServiceStatus),
		criticalServices: []string{
			"kubelet",
			"containerd",
			"docker",
			"sshd",
			"systemd-journald",
			"dbus",
		},
		servicesTotal: prometheus.NewDesc(
			"node_systemd_services_total",
			"Total number of systemd services",
			nil, nil,
		),
		servicesFailed: prometheus.NewDesc(
			"node_systemd_services_failed",
			"Number of failed systemd services",
			nil, nil,
		),
		servicesActive: prometheus.NewDesc(
			"node_systemd_services_active",
			"Number of active systemd services",
			nil, nil,
		),
		lastCollectionTime: prometheus.NewDesc(
			"node_systemd_last_collection_timestamp_seconds",
			"Timestamp of the last systemctl collection",
			nil, nil,
		),
	}
}

// Describe implements prometheus.Collector
func (c *SystemctlCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.servicesTotal
	ch <- c.servicesFailed
	ch <- c.servicesActive
	ch <- c.lastCollectionTime
}

// Collect implements prometheus.Collector
func (c *SystemctlCollector) Collect(ch chan<- prometheus.Metric) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	totalServices := len(c.services)
	failedCount := len(c.failedServices)
	activeCount := 0

	for _, svc := range c.services {
		if svc.ActiveState == "active" {
			activeCount++
		}
	}

	ch <- prometheus.MustNewConstMetric(
		c.servicesTotal,
		prometheus.GaugeValue,
		float64(totalServices),
	)

	ch <- prometheus.MustNewConstMetric(
		c.servicesFailed,
		prometheus.GaugeValue,
		float64(failedCount),
	)

	ch <- prometheus.MustNewConstMetric(
		c.servicesActive,
		prometheus.GaugeValue,
		float64(activeCount),
	)

	ch <- prometheus.MustNewConstMetric(
		c.lastCollectionTime,
		prometheus.GaugeValue,
		float64(prometheus.NewTimer(prometheus.ObserverFunc(func(v float64) {})).ObserveDuration().Seconds()),
	)
}

// Collect gathers systemctl service information (implements the collection interface)
func (c *SystemctlCollector) Collect() error {
	return c.CollectData()
}

// CollectData gathers systemctl service information
func (c *SystemctlCollector) CollectData() error {
	// Get list of all services
	cmd := exec.Command("systemctl", "list-units", "--type=service", "--all", "--no-pager", "--no-legend")
	var out bytes.Buffer
	cmd.Stdout = &out

	if err := cmd.Run(); err != nil {
		return err
	}

	services := make(map[string]*ServiceStatus)
	var failedServices []string

	scanner := bufio.NewScanner(&out)
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Fields(line)
		
		if len(fields) < 4 {
			continue
		}

		serviceName := fields[0]
		loadState := fields[1]
		activeState := fields[2]
		subState := fields[3]
		description := ""
		if len(fields) > 4 {
			description = strings.Join(fields[4:], " ")
		}

		status := &ServiceStatus{
			Name:        serviceName,
			LoadState:   loadState,
			ActiveState: activeState,
			SubState:    subState,
			Description: description,
		}

		services[serviceName] = status

		// Track failed services
		if activeState == "failed" || subState == "failed" {
			failedServices = append(failedServices, serviceName)
		}
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	// Check critical services
	for _, criticalSvc := range c.criticalServices {
		if status, exists := services[criticalSvc+".service"]; exists {
			if status.ActiveState != "active" {
				log.Warnf("Critical service %s is not active: %s/%s", 
					criticalSvc, status.ActiveState, status.SubState)
			}
		}
	}

	c.mu.Lock()
	c.services = services
	c.failedServices = failedServices
	c.mu.Unlock()

	log.Debugf("Systemctl collection: %d total services, %d failed", 
		len(services), len(failedServices))

	return nil
}

// GetStatus returns the current systemctl status
func (c *SystemctlCollector) GetStatus() map[string]interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()

	criticalStatus := make(map[string]string)
	for _, svcName := range c.criticalServices {
		fullName := svcName + ".service"
		if status, exists := c.services[fullName]; exists {
			criticalStatus[svcName] = status.ActiveState + "/" + status.SubState
		} else {
			criticalStatus[svcName] = "not-found"
		}
	}

	return map[string]interface{}{
		"total_services":    len(c.services),
		"failed_services":   c.failedServices,
		"critical_services": criticalStatus,
		"healthy":           len(c.failedServices) == 0 && c.areCriticalServicesHealthy(),
	}
}

// IsHealthy returns true if all critical services are running
func (c *SystemctlCollector) IsHealthy() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	
	return len(c.failedServices) == 0 && c.areCriticalServicesHealthy()
}

// areCriticalServicesHealthy checks if all critical services are active
func (c *SystemctlCollector) areCriticalServicesHealthy() bool {
	for _, svcName := range c.criticalServices {
		fullName := svcName + ".service"
		if status, exists := c.services[fullName]; exists {
			if status.ActiveState != "active" {
				return false
			}
		}
	}
	return true
}

// GetFailedServices returns list of failed services
func (c *SystemctlCollector) GetFailedServices() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	
	result := make([]string, len(c.failedServices))
	copy(result, c.failedServices)
	return result
}
