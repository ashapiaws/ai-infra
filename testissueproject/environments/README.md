# Multi-Environment Configuration

This directory contains environment-specific Terraform variable files for deploying the EKS observability stack across different environments.

## Environment Files

| File | Environment | Description |
|------|-------------|-------------|
| `dev.tfvars` | Development | Cost-optimized configuration for development and testing |
| `staging.tfvars` | Staging | Production-like configuration for pre-production testing |
| `prod.tfvars` | Production | High-availability, security-hardened configuration |

## Usage

### Deploy to Development
```bash
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Deploy to Staging
```bash
terraform plan -var-file="environments/staging.tfvars"
terraform apply -var-file="environments/staging.tfvars"
```

### Deploy to Production
```bash
terraform plan -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

### Using Makefile (Recommended)
```bash
# Development
make dev

# Staging
make staging

# Production
make prod
```

## Environment Characteristics

### Development (`dev.tfvars`)
- **Cost Optimized**: Spot instances, smaller resources, minimal logging
- **Permissive Access**: Public endpoint access, SSH enabled
- **Simplified Monitoring**: Basic Prometheus/Grafana, AlertManager disabled
- **Auto-Shutdown**: Tagged for automatic shutdown to save costs

**Key Features:**
- t3.small instances with spot pricing
- 7-day log retention
- No encryption for simplicity
- SSH access enabled for debugging

### Staging (`staging.tfvars`)
- **Production-Like**: Similar to production but with moderate resources
- **Testing Focus**: Balanced between cost and production parity
- **Full Monitoring**: Complete observability stack enabled
- **Security**: Encryption enabled, limited access

**Key Features:**
- t3.medium instances (mix of on-demand and spot)
- 15-day log retention
- Encryption enabled
- Ingress configured for internal access

### Production (`prod.tfvars`)
- **High Availability**: Multiple AZs, larger instances, higher minimums
- **Security Hardened**: Private endpoints, no SSH, full encryption
- **Comprehensive Monitoring**: Long retention, high-frequency scraping
- **Performance Optimized**: Placement groups, larger resources

**Key Features:**
- m5.large+ instances with on-demand pricing
- 90-day log retention
- Full security controls
- WAF and SSL termination

## Customization

### Before Deployment

1. **Update VPC IDs**: Replace placeholder VPC IDs with your actual VPC IDs
   ```hcl
   vpc_id = "vpc-12345678"  # Replace with your VPC ID
   ```

2. **Configure SSH Keys** (for dev environment):
   ```hcl
   ssh_key_name = "your-key-pair"  # Replace with your key pair name
   ```

3. **Update Ingress Configuration**:
   ```hcl
   ingress = {
     enabled     = true
     host        = "grafana.yourdomain.com"  # Your domain
     tls_enabled = true
     annotations = {
       "alb.ingress.kubernetes.io/certificate-arn" = "your-cert-arn"
     }
   }
   ```

4. **Set Strong Passwords**: Use AWS Secrets Manager for production
   ```hcl
   admin_password = "YourSecurePassword123!"
   ```

### Environment-Specific Customizations

#### Development Customizations
- Enable/disable features for faster iteration
- Adjust resource limits for cost control
- Configure auto-shutdown schedules

#### Staging Customizations
- Mirror production networking setup
- Test ingress and certificate configurations
- Validate monitoring and alerting

#### Production Customizations
- Configure backup and disaster recovery
- Set up compliance logging
- Enable advanced security features

## Best Practices

### Security
- **Never commit sensitive values** like passwords or keys
- **Use AWS Secrets Manager** for production passwords
- **Rotate credentials regularly**
- **Enable encryption** for staging and production

### Cost Management
- **Use spot instances** for non-critical workloads
- **Right-size resources** based on actual usage
- **Enable auto-shutdown** for development environments
- **Monitor costs** with appropriate tags

### Monitoring
- **Adjust retention** based on compliance requirements
- **Configure alerting** for production environments
- **Set appropriate resource limits** to prevent resource exhaustion
- **Use ingress** for secure external access

### Deployment
- **Test in development** before promoting to staging
- **Validate in staging** before deploying to production
- **Use infrastructure as code** for all environments
- **Maintain environment parity** where possible

## Troubleshooting

### Common Issues

1. **VPC/Subnet Not Found**
   ```bash
   # Check your VPC ID and subnets
   terraform output subnet_discovery_info
   ```

2. **Insufficient Permissions**
   ```bash
   # Verify AWS credentials and permissions
   aws sts get-caller-identity
   ```

3. **Resource Limits**
   ```bash
   # Check AWS service quotas
   aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C
   ```

### Environment-Specific Debugging

```bash
# Check environment-specific configuration
terraform plan -var-file="environments/dev.tfvars" -detailed-exitcode

# Validate subnet discovery for specific environment
terraform apply -var-file="environments/staging.tfvars" -target=null_resource.subnet_validation
```