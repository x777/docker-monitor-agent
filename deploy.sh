#!/bin/bash

# Docker Monitor Agent Deployment Script
# This script deploys the agent on a remote server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGENT_TOKEN=${AGENT_TOKEN:-""}
AGENT_PORT=${AGENT_PORT:-"8080"}
DOCKER_IMAGE=${DOCKER_IMAGE:-"docker-monitor/docker-agent:latest"}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Docker is available"
}

# Function to check if Docker socket is accessible
check_docker_socket() {
    if [ ! -S /var/run/docker.sock ]; then
        print_error "Docker socket not found at /var/run/docker.sock"
        exit 1
    fi
    
    if [ ! -r /var/run/docker.sock ]; then
        print_warning "Docker socket is not readable. Attempting to fix permissions..."
        sudo chmod 666 /var/run/docker.sock
    fi
    
    print_success "Docker socket is accessible"
}

# Function to generate secure token
generate_token() {
    if [ -z "$AGENT_TOKEN" ]; then
        print_status "Generating secure token..."
        AGENT_TOKEN=$(openssl rand -hex 32)
        print_success "Generated token: $AGENT_TOKEN"
        print_warning "Please save this token securely!"
    else
        print_status "Using provided token"
    fi
}

# Function to check if port is available
check_port() {
    if netstat -tuln | grep -q ":$AGENT_PORT "; then
        print_warning "Port $AGENT_PORT is already in use"
        read -p "Do you want to use a different port? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter new port number: " AGENT_PORT
            check_port
        else
            print_error "Deployment cancelled"
            exit 1
        fi
    fi
}

# Function to stop existing agent
stop_existing_agent() {
    if docker ps -q --filter "name=docker-monitor-agent" | grep -q .; then
        print_status "Stopping existing agent..."
        docker stop docker-monitor-agent || true
        docker rm docker-monitor-agent || true
        print_success "Existing agent stopped"
    fi
}

# Function to deploy agent
deploy_agent() {
    print_status "Deploying Docker Monitor Agent..."
    
    # Pull latest image
    print_status "Pulling latest image..."
    docker pull $DOCKER_IMAGE
    
    # Run agent container
    print_status "Starting agent container..."
    docker run -d \
        --name docker-monitor-agent \
        --restart unless-stopped \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p $AGENT_PORT:8080 \
        -e AGENT_TOKEN=$AGENT_TOKEN \
        -e DOCKER_SOCKET=/var/run/docker.sock \
        -e HOST=0.0.0.0 \
        -e PORT=8080 \
        $DOCKER_IMAGE
    
    print_success "Agent container started"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Wait for container to start
    sleep 5
    
    # Check if container is running
    if ! docker ps --filter "name=docker-monitor-agent" --filter "status=running" | grep -q docker-monitor-agent; then
        print_error "Agent container is not running"
        docker logs docker-monitor-agent
        exit 1
    fi
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    if curl -s -f "http://localhost:$AGENT_PORT/health" > /dev/null; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
        docker logs docker-monitor-agent
        exit 1
    fi
    
    # Test authenticated endpoint
    print_status "Testing authenticated endpoint..."
    if curl -s -f -H "Authorization: Bearer $AGENT_TOKEN" "http://localhost:$AGENT_PORT/containers" > /dev/null; then
        print_success "Authentication test passed"
    else
        print_error "Authentication test failed"
        exit 1
    fi
}

# Function to display deployment info
display_info() {
    echo
    print_success "Deployment completed successfully!"
    echo
    echo "Agent Information:"
    echo "  URL: http://$(hostname -I | awk '{print $1}'):$AGENT_PORT"
    echo "  Token: $AGENT_TOKEN"
    echo "  Container: docker-monitor-agent"
    echo
    echo "Useful commands:"
    echo "  View logs: docker logs -f docker-monitor-agent"
    echo "  Stop agent: docker stop docker-monitor-agent"
    echo "  Restart agent: docker restart docker-monitor-agent"
    echo "  Remove agent: docker rm -f docker-monitor-agent"
    echo
    print_warning "Remember to save the token securely!"
    echo
}

# Main deployment process
main() {
    echo "Docker Monitor Agent Deployment"
    echo "================================"
    echo
    
    # Check prerequisites
    check_docker
    check_docker_socket
    check_port
    
    # Generate token if not provided
    generate_token
    
    # Stop existing agent if running
    stop_existing_agent
    
    # Deploy agent
    deploy_agent
    
    # Verify deployment
    verify_deployment
    
    # Display information
    display_info
}

# Run main function
main "$@" 