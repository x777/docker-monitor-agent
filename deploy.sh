#!/bin/bash

# Docker Monitor Agent Deployment Script
# This script helps you quickly deploy the agent on a remote server

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

# Check if Docker Compose is installed
check_docker_compose() {
    # Check for docker-compose (old version)
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose (legacy) is installed"
        return 0
    fi
    
    # Check for docker compose (new version)
    if docker compose version &> /dev/null; then
        print_status "Docker Compose (new) is installed"
        return 0
    fi
    
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    print_status "You can install it with:"
    print_status "  - For new Docker versions: docker compose is included"
    print_status "  - For legacy: sudo apt-get install docker-compose"
    exit 1
}

# Generate secure token
generate_token() {
    if command -v openssl &> /dev/null; then
        AGENT_TOKEN=$(openssl rand -hex 32)
    else
        AGENT_TOKEN=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1)
    fi
    echo $AGENT_TOKEN
}

# Create environment file
create_env_file() {
    if [ ! -f .env ]; then
        print_status "Creating .env file..."
        cp env.example .env
        
        # Generate secure token
        TOKEN=$(generate_token)
        sed -i "s/your-secure-token-change-this/$TOKEN/" .env
        
        print_status "Generated secure token: $TOKEN"
        print_warning "Please save this token for dashboard configuration!"
    else
        print_status ".env file already exists"
    fi
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

# Build and deploy
deploy() {
    print_status "Building and deploying agent..."
    
    # Stop existing containers
    if command -v docker-compose &> /dev/null; then
        docker-compose down 2>/dev/null || true
        docker-compose up -d --build
    else
        docker compose down 2>/dev/null || true
        docker compose up -d --build
    fi
    
    print_status "Agent deployed successfully!"
}

# Wait for agent to be ready
wait_for_agent() {
    print_status "Waiting for agent to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080/health &> /dev/null; then
            print_status "Agent is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Agent failed to start within 60 seconds"
    print_status "Check logs with:"
    if command -v docker-compose &> /dev/null; then
        print_status "  docker-compose logs agent"
    else
        print_status "  docker compose logs agent"
    fi
    return 1
}

# Test agent
test_agent() {
    print_status "Testing agent..."
    
    # Test root endpoint
    if curl -s http://localhost:8080/ | grep -q "Docker Monitor Agent"; then
        print_status "Root endpoint: OK"
    else
        print_error "Root endpoint: FAILED"
    fi
    
    # Test health endpoint
    if curl -s http://localhost:8080/health | grep -q "status"; then
        print_status "Health endpoint: OK"
    else
        print_error "Health endpoint: FAILED"
    fi
    
    # Get token for authenticated tests
    TOKEN=$(grep AGENT_TOKEN .env | cut -d'=' -f2)
    
    # Test info endpoint
    if curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/info | grep -q "version"; then
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
    echo "  URL: http://$(hostname -I | awk '{print $1}'):8080"
    echo "  Token: $(grep AGENT_TOKEN .env | cut -d'=' -f2)"
    echo
    echo "Useful commands:"
    if command -v docker-compose &> /dev/null; then
        echo "  View logs: docker-compose logs -f agent"
        echo "  Stop agent: docker-compose down"
        echo "  Restart agent: docker-compose restart"
    else
        echo "  View logs: docker compose logs -f agent"
        echo "  Stop agent: docker compose down"
        echo "  Restart agent: docker compose restart"
    fi
    echo
    echo "To add this server to your dashboard:"
    echo "  1. Go to your dashboard"
    echo "  2. Add new server"
    echo "  3. Use the URL and token above"
}

# Main deployment process
main() {
    echo "Docker Monitor Agent Deployment Script"
    echo "====================================="
    echo
    
    check_docker
    check_docker_compose
    check_docker_socket
    create_env_file
    deploy
    wait_for_agent
    test_agent
    show_info
}

# Run main function
main "$@" 