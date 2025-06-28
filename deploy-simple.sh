#!/bin/bash

# Simple Docker Monitor Agent Deployment Script
# This script deploys the agent using docker run (no Docker Compose required)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
AGENT_TOKEN=${AGENT_TOKEN:-$(openssl rand -hex 32)}
AGENT_PORT=${AGENT_PORT:-8080}
CONTAINER_NAME="docker-monitor-agent"

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_status "Docker is installed and running"
}

# Check Docker socket permissions
check_docker_socket() {
    if [ ! -S /var/run/docker.sock ]; then
        print_error "Docker socket not found at /var/run/docker.sock"
        exit 1
    fi
    
    # Check if current user can access docker socket
    if ! docker ps &> /dev/null; then
        print_warning "Current user cannot access Docker socket"
        print_status "Adding current user to docker group..."
        sudo usermod -aG docker $USER
        print_warning "Please log out and log back in, or run: newgrp docker"
        print_warning "Then run this script again"
        exit 1
    fi
    
    print_status "Docker socket permissions are correct"
}

# Stop existing container
stop_existing() {
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        print_status "Stopping existing agent container..."
        docker stop $CONTAINER_NAME || true
        docker rm $CONTAINER_NAME || true
    fi
}

# Build image
build_image() {
    print_status "Building agent image..."
    docker build -t docker-monitor-agent .
    print_status "Image built successfully"
}

# Deploy agent
deploy_agent() {
    print_status "Deploying agent..."
    
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p $AGENT_PORT:8080 \
        -e AGENT_TOKEN=$AGENT_TOKEN \
        -e DOCKER_SOCKET=/var/run/docker.sock \
        -e HOST=0.0.0.0 \
        -e PORT=8080 \
        docker-monitor-agent
    
    print_status "Agent deployed successfully!"
}

# Wait for agent to be ready
wait_for_agent() {
    print_status "Waiting for agent to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:$AGENT_PORT/health &> /dev/null; then
            print_status "Agent is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Agent failed to start within 60 seconds"
    print_status "Check logs with: docker logs $CONTAINER_NAME"
    return 1
}

# Test agent
test_agent() {
    print_status "Testing agent..."
    
    # Test root endpoint
    if curl -s http://localhost:$AGENT_PORT/ | grep -q "Docker Monitor Agent"; then
        print_status "Root endpoint: OK"
    else
        print_error "Root endpoint: FAILED"
    fi
    
    # Test health endpoint
    if curl -s http://localhost:$AGENT_PORT/health | grep -q "status"; then
        print_status "Health endpoint: OK"
    else
        print_error "Health endpoint: FAILED"
    fi
    
    # Test info endpoint
    if curl -s -H "Authorization: Bearer $AGENT_TOKEN" http://localhost:$AGENT_PORT/info | grep -q "version"; then
        print_status "Info endpoint: OK"
    else
        print_error "Info endpoint: FAILED"
    fi
}

# Show deployment info
show_info() {
    print_status "Deployment completed successfully!"
    echo
    echo "Agent Information:"
    echo "  URL: http://$(hostname -I | awk '{print $1}'):$AGENT_PORT"
    echo "  Token: $AGENT_TOKEN"
    echo "  Container: $CONTAINER_NAME"
    echo
    echo "Useful commands:"
    echo "  View logs: docker logs -f $CONTAINER_NAME"
    echo "  Stop agent: docker stop $CONTAINER_NAME"
    echo "  Restart agent: docker restart $CONTAINER_NAME"
    echo "  Remove agent: docker rm -f $CONTAINER_NAME"
    echo
    echo "To add this server to your dashboard:"
    echo "  1. Go to your dashboard"
    echo "  2. Add new server"
    echo "  3. Use the URL and token above"
    echo
    print_warning "Remember to save the token securely!"
}

# Main deployment process
main() {
    echo "Simple Docker Monitor Agent Deployment"
    echo "======================================"
    echo
    
    check_docker
    check_docker_socket
    stop_existing
    build_image
    deploy_agent
    wait_for_agent
    test_agent
    show_info
}

# Run main function
main "$@" 