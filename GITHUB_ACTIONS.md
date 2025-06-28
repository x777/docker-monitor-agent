# GitHub Actions for Docker Monitor Agent

This document describes the CI/CD pipeline for the Docker Monitor Agent repository.

## Workflows

### 1. CI Pipeline (`ci.yml`)

**Triggers:**
- Push to any branch
- Pull requests

**Steps:**
1. **Checkout** - Clone the repository
2. **Setup Python** - Install Python 3.12
3. **Install dependencies** - Install Python packages
4. **Lint** - Run code formatting checks
5. **Test** - Run unit tests
6. **Build** - Build Docker image
7. **Security scan** - Scan for vulnerabilities

### 2. Release Pipeline (`release.yml`)

**Triggers:**
- Push tags (v*)

**Steps:**
1. **Build** - Build Docker image with tag
2. **Test** - Run integration tests
3. **Push to registry** - Push to Docker Hub
4. **Create release** - Create GitHub release

### 3. Security Pipeline (`security.yml`)

**Triggers:**
- Weekly (scheduled)
- Manual trigger

**Steps:**
1. **Dependency scan** - Scan for vulnerable dependencies
2. **Container scan** - Scan Docker image
3. **Code scan** - Static code analysis
4. **Report** - Generate security report

## Setup Instructions

### 1. Repository Secrets

Add these secrets to your GitHub repository:

```bash
# Docker Hub credentials
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password

# Security scanning
SONAR_TOKEN=your-sonarqube-token
TRIVY_TOKEN=your-trivy-token
```

### 2. Environment Variables

Set these in your repository settings:

```bash
# Docker image configuration
IMAGE_NAME=docker-monitor/docker-agent
REGISTRY=docker.io

# Security thresholds
VULNERABILITY_THRESHOLD=HIGH
COVERAGE_THRESHOLD=80
```

### 3. Branch Protection

Enable branch protection for `main`:
- Require status checks to pass
- Require branches to be up to date
- Require pull request reviews
- Restrict pushes to matching branches

## Manual Workflows

### Build and Test Locally

```bash
# Install dependencies
make install

# Run tests
make test

# Build image
make build

# Run locally
make run
```

### Deploy to Test Environment

```bash
# Set environment variables
export AGENT_TOKEN="test-token"
export AGENT_PORT="8081"

# Deploy
make deploy
```

### Release Process

1. **Update version** in `src/main.py`
2. **Create tag:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. **Monitor release pipeline**
4. **Verify deployment**

## Monitoring

### Pipeline Status

- **Green** - All checks passed
- **Yellow** - Tests passed, warnings present
- **Red** - Tests failed, manual intervention required

### Notifications

- **Slack** - Pipeline status updates
- **Email** - Security alerts
- **GitHub** - Release notifications

## Troubleshooting

### Common Issues

1. **Docker build fails:**
   - Check Dockerfile syntax
   - Verify dependencies in requirements.txt
   - Check for missing files

2. **Tests fail:**
   - Run tests locally first
   - Check test environment setup
   - Verify test dependencies

3. **Security scan fails:**
   - Update vulnerable dependencies
   - Fix security issues in code
   - Review security thresholds

### Debug Commands

```bash
# Check pipeline logs
gh run list
gh run view <run-id>

# Re-run failed workflow
gh run rerun <run-id>

# Download artifacts
gh run download <run-id>
```

## Best Practices

1. **Keep dependencies updated**
2. **Write comprehensive tests**
3. **Use semantic versioning**
4. **Document changes**
5. **Monitor security alerts**
6. **Review pipeline performance**

## Security Considerations

1. **Never commit secrets**
2. **Use least privilege access**
3. **Regular security updates**
4. **Monitor for vulnerabilities**
5. **Audit dependencies regularly** 