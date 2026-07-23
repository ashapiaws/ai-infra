# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git make

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o node-health-checker ./cmd

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    util-linux \
    systemd

# Create non-root user
RUN addgroup -g 1000 healthchecker && \
    adduser -D -u 1000 -G healthchecker healthchecker

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/node-health-checker .

# Change ownership
RUN chown -R healthchecker:healthchecker /app

# Note: This container needs to run in privileged mode or with specific capabilities
# to access dmesg and systemctl on the host

EXPOSE 8080 9100

USER healthchecker

ENTRYPOINT ["/app/node-health-checker"]
