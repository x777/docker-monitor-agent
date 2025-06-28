.PHONY: help build run test clean deploy docker-build docker-push

# Default target
help:
	@echo "Docker Monitor Agent - Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  build        - Build the agent Docker image"
	@echo "  run          - Run the agent locally"
	@echo "  test         - Run tests"
	@echo "  clean        - Clean up build artifacts"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-push  - Push Docker image to registry"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy       - Deploy agent using script"
	@echo ""

# Variables
IMAGE_NAME = docker-monitor/docker-agent
IMAGE_TAG = latest
REGISTRY = docker.io

# Development
build:
	@echo "Building agent..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

run:
	@echo "Running agent locally..."
	docker run -d \
		--name docker-monitor-agent \
		--rm \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
		-p 8080:8080 \
		-e AGENT_TOKEN=dev-token \
		$(IMAGE_NAME):$(IMAGE_TAG)

test:
	@echo "Running tests..."
	# Add test commands here when tests are implemented
	@echo "Tests not implemented yet"

clean:
	@echo "Cleaning up..."
	docker stop docker-monitor-agent 2>/dev/null || true
	docker rm docker-monitor-agent 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true

# Docker operations
docker-build:
	@echo "Building Docker image..."
	docker build -t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .
	docker tag $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):latest

docker-push:
	@echo "Pushing Docker image..."
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest

# Deployment
deploy:
	@echo "Deploying agent..."
	@if [ ! -f deploy.sh ]; then \
		echo "Error: deploy.sh not found"; \
		exit 1; \
	fi
	chmod +x deploy.sh
	./deploy.sh

# Quick deployment with custom token
deploy-with-token:
	@echo "Deploying agent with custom token..."
	@read -p "Enter agent token: " token; \
	AGENT_TOKEN=$$token ./deploy.sh

# Stop and remove agent
stop:
	@echo "Stopping agent..."
	docker stop docker-monitor-agent 2>/dev/null || true
	docker rm docker-monitor-agent 2>/dev/null || true

# View logs
logs:
	@echo "Viewing agent logs..."
	docker logs -f docker-monitor-agent

# Health check
health:
	@echo "Checking agent health..."
	@if [ -z "$$AGENT_TOKEN" ]; then \
		echo "Error: AGENT_TOKEN not set"; \
		exit 1; \
	fi
	curl -H "Authorization: Bearer $$AGENT_TOKEN" http://localhost:8080/health

# Install dependencies (for local development)
install:
	@echo "Installing Python dependencies..."
	pip install -r requirements.txt

# Format code
format:
	@echo "Formatting code..."
	black src/
	isort src/

# Lint code
lint:
	@echo "Linting code..."
	flake8 src/
	black --check src/
	isort --check-only src/ 