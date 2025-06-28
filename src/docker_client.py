import docker
import psutil
import time
from typing import List, Dict, Optional
from datetime import datetime
import os


class DockerClient:
    def __init__(self, docker_socket: str = "/var/run/docker.sock"):
        """Initialize Docker client"""
        self.client = docker.from_env()
        self.docker_socket = docker_socket
        
        # Test connection
        try:
            self.client.ping()
        except Exception as e:
            raise Exception(f"Failed to connect to Docker daemon: {e}")
    
    def get_containers(self, name_filter: Optional[str] = None) -> List[Dict]:
        """Get all containers (running and stopped) with optional name filtering"""
        containers = []
        
        try:
            for container in self.client.containers.list(all=True):
                container_name = container.name
                
                # Apply name filter if provided
                if name_filter:
                    # Support wildcard matching (simple pattern)
                    if name_filter.startswith('*') and name_filter.endswith('*'):
                        # *pattern* - contains pattern
                        pattern = name_filter[1:-1]
                        if pattern.lower() not in container_name.lower():
                            continue
                    elif name_filter.startswith('*'):
                        # *pattern - ends with pattern
                        pattern = name_filter[1:]
                        if not container_name.lower().endswith(pattern.lower()):
                            continue
                    elif name_filter.endswith('*'):
                        # pattern* - starts with pattern
                        pattern = name_filter[:-1]
                        if not container_name.lower().startswith(pattern.lower()):
                            continue
                    else:
                        # exact match or contains
                        if name_filter.lower() not in container_name.lower():
                            continue
                
                container_info = {
                    "id": container.id,
                    "name": container.name,
                    "image": container.image.tags[0] if container.image.tags else container.image.id,
                    "status": container.status,
                    "created": container.attrs["Created"],
                    "ports": self._format_ports(container.attrs["NetworkSettings"]["Ports"]),
                    "labels": container.attrs["Config"]["Labels"] or {},
                    "restart_count": container.attrs["RestartCount"],
                    "state": container.attrs["State"]
                }
                containers.append(container_info)
        except Exception as e:
            print(f"Error getting containers: {e}")
            return []
        
        return containers
    
    def _format_ports(self, ports: Dict) -> List[str]:
        """Format port mappings"""
        formatted_ports = []
        if ports:
            for container_port, host_bindings in ports.items():
                if host_bindings:
                    for binding in host_bindings:
                        formatted_ports.append(f"{binding['HostIp']}:{binding['HostPort']}->{container_port}")
                else:
                    formatted_ports.append(container_port)
        return formatted_ports
    
    def get_container_metrics(self, container_id: str) -> Dict:
        """Get detailed metrics for a specific container"""
        try:
            container = self.client.containers.get(container_id)
            stats = container.stats(stream=False)
            
            # Calculate CPU percentage
            cpu_delta = stats["cpu_stats"]["cpu_usage"]["total_usage"] - stats["precpu_stats"]["cpu_usage"]["total_usage"]
            system_delta = stats["cpu_stats"]["system_cpu_usage"] - stats["precpu_stats"]["system_cpu_usage"]
            cpu_percent = 0.0
            if system_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * len(stats["cpu_stats"]["cpu_usage"]["percpu_usage"]) * 100.0
            
            # Memory usage
            memory_usage = stats["memory_stats"]["usage"]
            memory_limit = stats["memory_stats"]["limit"]
            memory_percent = (memory_usage / memory_limit) * 100.0 if memory_limit > 0 else 0.0
            
            # Network stats
            network_rx = 0
            network_tx = 0
            if "networks" in stats:
                for network in stats["networks"].values():
                    network_rx += network.get("rx_bytes", 0)
                    network_tx += network.get("tx_bytes", 0)
            
            # Uptime
            uptime_seconds = int(time.time() - container.attrs["State"]["StartedAt"])
            
            return {
                "cpu_percent": round(cpu_percent, 2),
                "memory_percent": round(memory_percent, 2),
                "memory_usage": memory_usage,
                "memory_limit": memory_limit,
                "network_rx": network_rx,
                "network_tx": network_tx,
                "restart_count": container.attrs["RestartCount"],
                "uptime_seconds": uptime_seconds,
                "timestamp": datetime.utcnow().isoformat()
            }
        except Exception as e:
            print(f"Error getting container metrics for {container_id}: {e}")
            return {
                "cpu_percent": 0.0,
                "memory_percent": 0.0,
                "memory_usage": 0,
                "memory_limit": 0,
                "network_rx": 0,
                "network_tx": 0,
                "restart_count": 0,
                "uptime_seconds": 0,
                "timestamp": datetime.utcnow().isoformat()
            }
    
    def get_server_metrics(self) -> Dict:
        """Get server-level metrics"""
        try:
            # System metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # Docker containers count
            running_containers = len(self.client.containers.list())
            total_containers = len(self.client.containers.list(all=True))
            
            return {
                "cpu_percent": round(cpu_percent, 2),
                "memory_percent": round(memory.percent, 2),
                "memory_usage": memory.used,
                "memory_total": memory.total,
                "disk_usage_percent": round(disk.percent, 2),
                "disk_usage": disk.used,
                "disk_total": disk.total,
                "running_containers": running_containers,
                "total_containers": total_containers,
                "timestamp": datetime.utcnow().isoformat()
            }
        except Exception as e:
            print(f"Error getting server metrics: {e}")
            return {
                "cpu_percent": 0.0,
                "memory_percent": 0.0,
                "memory_usage": 0,
                "memory_total": 0,
                "disk_usage_percent": 0.0,
                "disk_usage": 0,
                "disk_total": 0,
                "running_containers": 0,
                "total_containers": 0,
                "timestamp": datetime.utcnow().isoformat()
            }
    
    def perform_container_action(self, container_id: str, action: str) -> Dict:
        """Perform action on container"""
        try:
            container = self.client.containers.get(container_id)
            
            if action == "start":
                container.start()
                return {"success": True, "message": f"Container {container_id} started successfully"}
            elif action == "stop":
                container.stop()
                return {"success": True, "message": f"Container {container_id} stopped successfully"}
            elif action == "restart":
                container.restart()
                return {"success": True, "message": f"Container {container_id} restarted successfully"}
            elif action == "pause":
                container.pause()
                return {"success": True, "message": f"Container {container_id} paused successfully"}
            elif action == "unpause":
                container.unpause()
                return {"success": True, "message": f"Container {container_id} unpaused successfully"}
            else:
                return {"success": False, "message": f"Unknown action: {action}"}
        except Exception as e:
            return {"success": False, "message": f"Failed to perform action: {str(e)}"}
    
    def get_container_logs(self, container_id: str, tail: int = 100) -> str:
        """Get container logs"""
        try:
            container = self.client.containers.get(container_id)
            logs = container.logs(tail=tail, timestamps=True).decode('utf-8')
            return logs
        except Exception as e:
            return f"Error getting logs: {str(e)}"
    
    def get_docker_info(self) -> Dict:
        """Get Docker daemon information"""
        try:
            info = self.client.info()
            return {
                "version": info.get("ServerVersion", "Unknown"),
                "containers": info.get("Containers", 0),
                "images": info.get("Images", 0),
                "driver": info.get("Driver", "Unknown"),
                "kernel_version": info.get("KernelVersion", "Unknown"),
                "operating_system": info.get("OperatingSystem", "Unknown"),
                "architecture": info.get("Architecture", "Unknown")
            }
        except Exception as e:
            return {"error": f"Failed to get Docker info: {str(e)}"} 