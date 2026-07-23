package main

import (
	"context"
	"flag"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/eks-observability/node-health-checker/internal/collector"
	"github.com/eks-observability/node-health-checker/internal/health"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

var (
	metricsAddr    = flag.String("metrics-addr", ":9100", "The address to expose Prometheus metrics")
	healthAddr     = flag.String("health-addr", ":8080", "The address for health check endpoints")
	collectionInt  = flag.Duration("collection-interval", 60*time.Second, "Interval for collecting node health data")
	dmesgLines     = flag.Int("dmesg-lines", 100, "Number of recent dmesg lines to analyze")
	logLevel       = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
)

func main() {
	flag.Parse()

	// Configure logging
	level, err := log.ParseLevel(*logLevel)
	if err != nil {
		log.Fatalf("Invalid log level: %v", err)
	}
	log.SetLevel(level)
	log.SetFormatter(&log.JSONFormatter{})

	log.Info("Starting Node Health Checker")
	log.Infof("Metrics endpoint: %s", *metricsAddr)
	log.Infof("Health endpoint: %s", *healthAddr)
	log.Infof("Collection interval: %s", *collectionInt)

	// Create collectors
	dmesgCollector := collector.NewDmesgCollector(*dmesgLines)
	systemctlCollector := collector.NewSystemctlCollector()
	
	// Register Prometheus collectors
	prometheus.MustRegister(dmesgCollector)
	prometheus.MustRegister(systemctlCollector)

	// Create health checker
	healthChecker := health.NewChecker(dmesgCollector, systemctlCollector)

	// Start collection loop
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		ticker := time.NewTicker(*collectionInt)
		defer ticker.Stop()

		// Initial collection
		collectData(dmesgCollector, systemctlCollector)

		for {
			select {
			case <-ticker.C:
				collectData(dmesgCollector, systemctlCollector)
			case <-ctx.Done():
				return
			}
		}
	}()

	// Start metrics server
	metricsServer := &http.Server{
		Addr:    *metricsAddr,
		Handler: promhttp.Handler(),
	}

	go func() {
		log.Infof("Starting metrics server on %s", *metricsAddr)
		if err := metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Metrics server failed: %v", err)
		}
	}()

	// Start health server
	healthMux := http.NewServeMux()
	healthMux.HandleFunc("/healthz", healthChecker.HealthzHandler)
	healthMux.HandleFunc("/readyz", healthChecker.ReadyzHandler)
	healthMux.HandleFunc("/health/details", healthChecker.DetailsHandler)

	healthServer := &http.Server{
		Addr:    *healthAddr,
		Handler: healthMux,
	}

	go func() {
		log.Infof("Starting health server on %s", *healthAddr)
		if err := healthServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Health server failed: %v", err)
		}
	}()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Info("Shutting down gracefully...")

	// Shutdown servers
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := metricsServer.Shutdown(shutdownCtx); err != nil {
		log.Errorf("Metrics server shutdown error: %v", err)
	}

	if err := healthServer.Shutdown(shutdownCtx); err != nil {
		log.Errorf("Health server shutdown error: %v", err)
	}

	cancel()
	log.Info("Shutdown complete")
}

func collectData(dmesg *collector.DmesgCollector, systemctl *collector.SystemctlCollector) {
	log.Debug("Starting data collection")
	
	if err := dmesg.Collect(); err != nil {
		log.Errorf("Failed to collect dmesg data: %v", err)
	}
	
	if err := systemctl.Collect(); err != nil {
		log.Errorf("Failed to collect systemctl data: %v", err)
	}
	
	log.Debug("Data collection complete")
}
