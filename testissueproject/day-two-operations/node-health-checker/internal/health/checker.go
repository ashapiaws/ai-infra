package health

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/eks-observability/node-health-checker/internal/collector"
	log "github.com/sirupsen/logrus"
)

// Checker provides health check endpoints
type Checker struct {
	dmesgCollector     *collector.DmesgCollector
	systemctlCollector *collector.SystemctlCollector
	startTime          time.Time
}

// NewChecker creates a new health checker
func NewChecker(dmesg *collector.DmesgCollector, systemctl *collector.SystemctlCollector) *Checker {
	return &Checker{
		dmesgCollector:     dmesg,
		systemctlCollector: systemctl,
		startTime:          time.Now(),
	}
}

// HealthzHandler handles /healthz requests (liveness probe)
func (c *Checker) HealthzHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

// ReadyzHandler handles /readyz requests (readiness probe)
func (c *Checker) ReadyzHandler(w http.ResponseWriter, r *http.Request) {
	dmesgHealthy := c.dmesgCollector.IsHealthy()
	systemctlHealthy := c.systemctlCollector.IsHealthy()

	if dmesgHealthy && systemctlHealthy {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ready"))
		return
	}

	w.WriteHeader(http.StatusServiceUnavailable)
	response := map[string]interface{}{
		"status":            "not ready",
		"dmesg_healthy":     dmesgHealthy,
		"systemctl_healthy": systemctlHealthy,
	}

	if !dmesgHealthy {
		response["dmesg_errors"] = c.dmesgCollector.GetRecentErrors()
	}

	if !systemctlHealthy {
		response["failed_services"] = c.systemctlCollector.GetFailedServices()
	}

	json.NewEncoder(w).Encode(response)
}

// DetailsHandler provides detailed health information
func (c *Checker) DetailsHandler(w http.ResponseWriter, r *http.Request) {
	dmesgStatus := c.dmesgCollector.GetStatus()
	systemctlStatus := c.systemctlCollector.GetStatus()

	response := map[string]interface{}{
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"uptime":    time.Since(c.startTime).String(),
		"dmesg":     dmesgStatus,
		"systemctl": systemctlStatus,
		"overall_healthy": dmesgStatus["healthy"].(bool) && 
			systemctlStatus["healthy"].(bool),
	}

	w.Header().Set("Content-Type", "application/json")
	
	if response["overall_healthy"].(bool) {
		w.WriteHeader(http.StatusOK)
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
	}

	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Errorf("Failed to encode health details: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}
