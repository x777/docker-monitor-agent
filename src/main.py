from fastapi import FastAPI, APIRouter, HTTPException, Depends, status, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, List
import uvicorn
import os
from dotenv import load_dotenv

from docker_client import DockerClient

# Load environment variables
load_dotenv()

# Configuration
AGENT_TOKEN = os.getenv("AGENT_TOKEN", "your-agent-token-change-in-production")
DOCKER_SOCKET = os.getenv("DOCKER_SOCKET", "/var/run/docker.sock")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8080"))

# Initialize Docker client
try:
    docker_client = DockerClient(DOCKER_SOCKET)
    print(f"Docker client initialized successfully")
except Exception as e:
    print(f"Failed to initialize Docker client: {e}")
    docker_client = None

# Create FastAPI app
app = FastAPI(
    title="Docker Monitor Agent",
    description="Lightweight agent for monitoring Docker containers",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Новый роутер с префиксом /api
router = APIRouter(prefix="/api")

@router.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Docker Monitor Agent",
        "version": "1.0.0",
        "status": "running",
        "docker_available": docker_client is not None
    }


async def verify_token(authorization: Optional[str] = Header(None)):
    """Verify agent token"""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header required"
        )
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format"
        )
    
    token = authorization.replace("Bearer ", "")
    if token != AGENT_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    return token


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        if docker_client is None:
            return {
                "status": "unhealthy",
                "docker": "not_available",
                "message": "Docker client not initialized"
            }
        
        # Test Docker connection
        docker_client.client.ping()
        return {
            "status": "healthy", 
            "docker": "connected",
            "message": "Agent is healthy and Docker is connected"
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "docker": "connection_failed",
            "message": f"Docker connection failed: {str(e)}"
        }


@router.get("/containers")
async def get_containers(
    name_filter: Optional[str] = None, 
    token: str = Depends(verify_token)
):
    """Get all containers with optional name filtering"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        containers = docker_client.get_containers(name_filter=name_filter)
        return {"containers": containers}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get containers: {str(e)}"
        )


@router.get("/containers/{container_id}/metrics")
async def get_container_metrics(container_id: str, token: str = Depends(verify_token)):
    """Get metrics for specific container"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        metrics = docker_client.get_container_metrics(container_id)
        return metrics
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get container metrics: {str(e)}"
        )


@router.get("/metrics")
async def get_server_metrics(token: str = Depends(verify_token)):
    """Get server-level metrics"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        metrics = docker_client.get_server_metrics()
        return metrics
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get server metrics: {str(e)}"
        )


@router.post("/containers/{container_id}/action")
async def perform_container_action(container_id: str, action_data: dict, token: str = Depends(verify_token)):
    """Perform action on container"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    action = action_data.get("action")
    if not action:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Action is required"
        )
    
    try:
        result = docker_client.perform_container_action(container_id, action)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to perform action: {str(e)}"
        )


@router.get("/containers/{container_id}/logs")
async def get_container_logs(container_id: str, tail: int = 100, token: str = Depends(verify_token)):
    """Get container logs"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        logs = docker_client.get_container_logs(container_id, tail)
        return {"logs": logs}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get logs: {str(e)}"
        )


@router.get("/info")
async def get_docker_info(token: str = Depends(verify_token)):
    """Get Docker daemon information"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        info = docker_client.get_docker_info()
        return info
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get Docker info: {str(e)}"
        )


@router.get("/monitored-containers")
async def get_monitored_containers(
    names: str = Query(..., description="Comma-separated container names or patterns"),
    token: str = Depends(verify_token)
):
    """Get specific containers for monitoring"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        # Parse container names from query parameter
        container_names = [name.strip() for name in names.split(',') if name.strip()]
        
        containers = []
        for name_pattern in container_names:
            filtered_containers = docker_client.get_containers(name_filter=name_pattern)
            containers.extend(filtered_containers)
        
        # Remove duplicates by container ID
        unique_containers = {}
        for container in containers:
            unique_containers[container['id']] = container
        
        return {
            "containers": list(unique_containers.values()),
            "monitored_patterns": container_names,
            "total_found": len(unique_containers)
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get monitored containers: {str(e)}"
        )


@router.get("/monitored-containers/metrics")
async def get_monitored_containers_metrics(
    names: str = Query(..., description="Comma-separated container names or patterns"),
    token: str = Depends(verify_token)
):
    """Get metrics for specific monitored containers"""
    if docker_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker client not available"
        )
    
    try:
        # Parse container names from query parameter
        container_names = [name.strip() for name in names.split(',') if name.strip()]
        
        all_metrics = []
        for name_pattern in container_names:
            containers = docker_client.get_containers(name_filter=name_pattern)
            for container in containers:
                metrics = docker_client.get_container_metrics(container['id'])
                metrics['name'] = container['name']
                metrics['status'] = container['status']
                all_metrics.append(metrics)
        
        return {
            "containers_metrics": all_metrics,
            "monitored_patterns": container_names,
            "total_containers": len(all_metrics)
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get monitored containers metrics: {str(e)}"
        )

# В самом конце файла:
app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=HOST,
        port=PORT,
        reload=False
    ) 