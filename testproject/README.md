# NHL Multi-Agent Analytics System

A cloud-native multi-agent system for analyzing NHL player and team statistics using Amazon Bedrock AgentCore and Strands Agents SDK.

## Overview

This system provides NHL analysts with intelligent data querying and prediction capabilities through a multi-agent architecture. It leverages AWS services and specialized agents to process NHL statistics and generate analytical insights.

## Architecture

- **Query Agent**: Retrieves and processes NHL data from S3 storage
- **Prediction Agent**: Generates predictions and analytical insights
- **Python Application**: Web interface built with FastAPI and Open-WebUI
- **Infrastructure**: AWS services (S3, ECS, ALB) provisioned via Terraform

## Prerequisites

- Python 3.11 or higher
- Docker and Docker Compose (for containerized deployment)
- AWS Account with appropriate permissions
- Terraform (for infrastructure provisioning)

## Quick Start

### Local Development

1. Clone the repository
2. Run the setup script:
   ```bash
   ./setup.sh
   ```
3. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```
4. Update `.env` with your AWS configuration
5. Run the application:
   ```bash
   uvicorn app.main:app --reload
   ```

### Docker Deployment

1. Update `.env` with your AWS configuration
2. Build and run with Docker Compose:
   ```bash
   docker-compose up --build
   ```

The application will be available at `http://localhost:8000`

## Project Structure

```
.
├── app/                    # Application code
├── infra/                  # Terraform infrastructure code
├── tests/                  # Test suite
├── datasets/               # NHL datasets (CSV files)
├── requirements.txt        # Python dependencies
├── Dockerfile             # Docker configuration
├── docker-compose.yml     # Docker Compose configuration
└── pytest.ini             # Pytest configuration
```

## Testing

Run the test suite:
```bash
pytest
```

Run with coverage:
```bash
pytest --cov=app --cov-report=html
```

## Infrastructure

Infrastructure is managed with Terraform. See the `infra/` directory for configuration files.

To deploy infrastructure:
```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Environment Variables

See `.env.example` for required environment variables:
- `AWS_REGION`: AWS region for resources
- `DATA_BUCKET_NAME`: S3 bucket for NHL datasets
- `ANALYSIS_BUCKET_NAME`: S3 bucket for prediction results
- `BEDROCK_MODEL_ID`: Amazon Bedrock model identifier
- `LOG_LEVEL`: Application logging level

## License

Copyright © 2024. All rights reserved.
