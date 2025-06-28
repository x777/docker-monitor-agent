# Docker Monitor Agent

Lightweight agent for monitoring Docker containers on remote servers.

## 🚀 Quick Start

### Deploy with Local Build (Recommended)

```bash
# Clone the repository
git clone https://github.com/x777/docker-monitor-agent.git
cd docker-monitor-agent

# Create environment file
cp env.example .env
# Edit .env and set your AGENT_TOKEN

# Build and deploy with Docker Compose
docker-compose up -d --build
```

### Deploy with Docker Run

```bash
# Clone and build locally
git clone https://github.com/x777/docker-monitor-agent.git
cd docker-monitor-agent

# Build the image
docker build -t docker-monitor-agent .

# Generate token and run
AGENT_TOKEN=$(openssl rand -hex 32)
docker run -d \
  --name docker-monitor-agent \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p 8080:8080 \
  -e AGENT_TOKEN=$AGENT_TOKEN \
  docker-monitor-agent

echo "Agent deployed with token: $AGENT_TOKEN"
```

### Deploy with Script

```bash
# Download deployment script
curl -O https://raw.githubusercontent.com/x777/docker-monitor-agent/main/deploy.sh
chmod +x deploy.sh

# Set token and deploy
export AGENT_TOKEN="your-secure-token"
./deploy.sh
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_TOKEN` | Required | Authentication token for the agent |
| `DOCKER_SOCKET` | `/var/run/docker.sock` | Path to Docker socket |
| `HOST` | `0.0.0.0` | Host to bind the agent to |
| `PORT` | `8080` | Port to run the agent on |

### Generate Secure Token

```bash
# Generate a secure token
openssl rand -hex 32
```

## 📊 API Endpoints

### Health Check
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/health
```

### Get Containers
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/containers
```

### Get Server Metrics
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/metrics
```

### Container Actions
```bash
# Start container
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "start"}' \
  http://localhost:8080/containers/CONTAINER_ID/action
```

## 🔍 Troubleshooting

### Check Agent Status
```bash
# Check if running
docker ps | grep docker-monitor-agent

# View logs
docker logs -f docker-monitor-agent

# Test health
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/health
```

### Common Issues

1. **Permission denied on Docker socket**:
   ```bash
   sudo chmod 666 /var/run/docker.sock
   ```

2. **Port already in use**:
   ```bash
   # Use different port
   export AGENT_PORT=8081
   docker-compose up -d
   ```

3. **Build fails**:
   ```bash
   # Check Dockerfile
   cat Dockerfile
   
   # Check requirements
   cat requirements.txt
   
   # Rebuild
   docker-compose build --no-cache
   ```

## 🛡️ Security

- Use unique, secure tokens for each server
- Restrict network access to agent ports
- Monitor agent logs for suspicious activity
- Regular security updates

## 📋 Integration

After deployment, add the server to your dashboard:
1. Agent URL: `http://SERVER_IP:8080`
2. Use the agent token you configured
3. Add through dashboard interface

## 📞 Support

- [Documentation](https://github.com/x777/docker-monitor-agent)
- [Issues](https://github.com/x777/docker-monitor-agent/issues)
- [Releases](https://github.com/x777/docker-monitor-agent/releases)