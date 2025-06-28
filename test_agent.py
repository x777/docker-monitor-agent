#!/usr/bin/env python3
"""
Test script for Docker Monitor Agent
"""
import requests
import json
import sys
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

AGENT_URL = os.getenv("AGENT_URL", "http://localhost:8080")
AGENT_TOKEN = os.getenv("AGENT_TOKEN", "your-agent-token-change-in-production")

def test_endpoint(endpoint, method="GET", data=None, headers=None):
    """Test an endpoint"""
    url = f"{AGENT_URL}{endpoint}"
    
    if headers is None:
        headers = {}
    
    if "Authorization" not in headers and endpoint != "/" and endpoint != "/health":
        headers["Authorization"] = f"Bearer {AGENT_TOKEN}"
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)
        else:
            print(f"Unsupported method: {method}")
            return False
        
        print(f"{method} {endpoint} - Status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                data = response.json()
                print(f"Response: {json.dumps(data, indent=2)}")
            except:
                print(f"Response: {response.text}")
        else:
            print(f"Error: {response.text}")
        
        return response.status_code == 200
        
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        return False

def main():
    """Main test function"""
    print("Testing Docker Monitor Agent...")
    print(f"Agent URL: {AGENT_URL}")
    print(f"Agent Token: {AGENT_TOKEN}")
    print("-" * 50)
    
    # Test root endpoint
    print("\n1. Testing root endpoint:")
    test_endpoint("/")
    
    # Test health endpoint
    print("\n2. Testing health endpoint:")
    test_endpoint("/health")
    
    # Test info endpoint (requires auth)
    print("\n3. Testing info endpoint:")
    test_endpoint("/info")
    
    # Test containers endpoint (requires auth)
    print("\n4. Testing containers endpoint:")
    test_endpoint("/containers")
    
    # Test filtered containers endpoint
    print("\n5. Testing filtered containers endpoint:")
    test_endpoint("/containers?name_filter=agent")
    
    # Test monitored containers endpoint
    print("\n6. Testing monitored containers endpoint:")
    test_endpoint("/monitored-containers?names=agent,nginx")
    
    # Test monitored containers metrics endpoint
    print("\n7. Testing monitored containers metrics endpoint:")
    test_endpoint("/monitored-containers/metrics?names=agent,nginx")
    
    # Test metrics endpoint (requires auth)
    print("\n8. Testing metrics endpoint:")
    test_endpoint("/metrics")
    
    print("\n" + "-" * 50)
    print("Testing completed!")

if __name__ == "__main__":
    main() 