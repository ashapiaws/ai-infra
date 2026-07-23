package collector

import (
	"bufio"
	"bytes"
	"os/exec"
	"regexp"
	"strings"
	"sync"

	"github.com/prometheus/client_golang/prometheus"
	log "github.com/sirupsen/logrus"
)

var (
	// Common error patterns in dmesg
	errorPatterns = []*regexp.Regexp{
		regexp.MustCompile(`(?i)error`),
		regexp.MustCompile(`(?i)fail(ed)?`),
		regexp.MustCompile(`(?i)panic`),
		regexp.MustCompile(`(?i)oops`),
		regexp.MustCompile(`(?i)segfault`),
		regexp.MustCompile(`(?i)out of memory`),
		regexp.MustCompile(`(?i)oom`),
		regexp.MustCompile(`(?i)hung task`),
		regexp.MustCompile(`(?i)i/o error`),
		regexp.MustCompile(`(?i)hardware error`),
	}

	warningPatterns = []*regexp.Regexp{
		regexp.MustCompile(`(?i)warn(ing)?`),
		regexp.MustCompile(`(?i)deprecated`),
		regexp.MustCompile(`(?i)timeout`),
	}
)

// DmesgCollector collects and analyzes dmesg output
type DmesgCollector struct {
	mu         sync.RWMutex
	maxLines   int
	errorCount int
	warnCount  int
	lastErrors []string

	// Prometheus metrics
	errorsTotal *prometheus.Desc
	warningsTotal *prometheus.Desc
	lastCollectionTime *prometheus.Desc
}

// NewDmesgCollector creates a new dmesg collector
func NewDmesgCollector(maxLines int) *DmesgCollector {
	return &DmesgCollector{
		maxLines: maxLines,
		errorsTotal: prometheus.NewDesc(
			"node_dmesg_errors_total",
			"Total number of error patterns found in dmesg",
			nil, nil,
		),
		warningsTotal: prometheus.NewDesc(
			"node_dmesg_warnings_total",
			"Total number of warning patterns found in dmesg",
			nil, nil,
		),
		lastCollectionTime: prometheus.NewDesc(
			"node_dmesg_last_collection_timestamp_seconds",
			"Timestamp of the last dmesg collection",
			nil, nil,
		),
	}
}

// Describe implements prometheus.Collector
func (c *DmesgCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.errorsTotal
	ch <- c.warningsTotal
	ch <- c.lastCollectionTime
}

// Collect implements prometheus.Collector
func (c *DmesgCollector) Collect(ch chan<- prometheus.Metric) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	ch <- prometheus.MustNewConstMetric(
		c.errorsTotal,
		prometheus.CounterValue,
		float64(c.errorCount),
	)

	ch <- prometheus.MustNewConstMetric(
		c.warningsTotal,
		prometheus.CounterValue,
		float64(c.warnCount),
	)

	ch <- prometheus.MustNewConstMetric(
		c.lastCollectionTime,
		prometheus.GaugeValue,
		float64(prometheus.NewTimer(prometheus.ObserverFunc(func(v float64) {})).ObserveDuration().Seconds()),
	)
}

// Collect gathers dmesg data (implements the collection interface)
func (c *DmesgCollector) Collect() error {
	return c.CollectData()
}

// CollectData gathers dmesg data
func (c *DmesgCollector) CollectData() error {
	// Run dmesg command
	cmd := exec.Command("dmesg", "-T", "--level=err,warn")
	var out bytes.Buffer
	cmd.Stdout = &out
	
	if err := cmd.Run(); err != nil {
		log.Warnf("Failed to run dmesg: %v, trying without -T flag", err)
		// Fallback without timestamp flag
		cmd = exec.Command("dmesg")
		out.Reset()
		cmd.Stdout = &out
		if err := cmd.Run(); err != nil {
			return err
		}
	}

	// Parse output
	scanner := bufio.NewScanner(&out)
	var lines []string
	errorCount := 0
	warnCount := 0
	var recentErrors []string

	for scanner.Scan() {
		line := scanner.Text()
		lines = append(lines, line)

		// Check for error patterns
		for _, pattern := range errorPatterns {
			if pattern.MatchString(line) {
				errorCount++
				if len(recentErrors) < 10 {
					recentErrors = append(recentErrors, line)
				}
				break
			}
		}

		// Check for warning patterns
		for _, pattern := range warningPatterns {
			if pattern.MatchString(line) {
				warnCount++
				break
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	// Keep only recent lines
	if len(lines) > c.maxLines {
		lines = lines[len(lines)-c.maxLines:]
	}

	c.mu.Lock()
	c.errorCount = errorCount
	c.warnCount = warnCount
	c.lastErrors = recentErrors
	c.mu.Unlock()

	log.Debugf("Dmesg collection: %d errors, %d warnings", errorCount, warnCount)

	return nil
}

// GetStatus returns the current dmesg status
func (c *DmesgCollector) GetStatus() map[string]interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()

	return map[string]interface{}{
		"error_count":   c.errorCount,
		"warning_count": c.warnCount,
		"recent_errors": c.lastErrors,
		"healthy":       c.errorCount == 0,
	}
}

// IsHealthy returns true if no critical errors found
func (c *DmesgCollector) IsHealthy() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.errorCount == 0
}

// GetRecentErrors returns recent error messages
func (c *DmesgCollector) GetRecentErrors() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	
	result := make([]string, len(c.lastErrors))
	copy(result, c.lastErrors)
	return result
}
