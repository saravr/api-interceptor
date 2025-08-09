#!/usr/bin/env python3
"""
Simple Proxy Server for Modifying API Responses
Usage: mitmdump -s proxy_modifier.py -p 8080
"""

from mitmproxy import http
import json
import time
from datetime import datetime

# ============ CONFIGURATION ============
# Add your API modifications here

MODIFICATIONS = {
    "/api/users": {
        "enabled": True,
        "match_type": "path_contains",  # exact_path, path_contains, regex
        "response": {
            "status_code": 200,
            "body": {
                "results" : [
                ],
                "total" : 0,
                "limit" : "50"
            }
        }
    },
    
    # Example: Modify user data endpoint
    "/api/user/profile": {
        "enabled": True,
        "match_type": "path_contains",
        "response": {
            "status_code": 500,
            "body": {
                "error": True,
                "message": "Internal server error"
            }
        }
    },
    
    # Example: Modify with delay
    "/api/data": {
        "enabled": True,
        "match_type": "path_contains",
        "delay": 5,  # Add 5 second delay
        "response": {
            "status_code": 408,
            "body": {
                "error": True,
                "message": "Request timeout"
            }
        }
    },
    
    # Example: Return empty array
    "/api/items": {
        "enabled": True,
        "match_type": "exact_path",
        "response": {
            "status_code": 200,
            "body": []
        }
    },
    
    # Example: Modify existing response (don't replace entirely)
    "/api/config": {
        "enabled": True,
        "match_type": "path_contains",
        "modify_existing": True,  # Modify the real response instead of replacing
        "modifications": {
            "premium": False,
            "features.max_uploads": 0,
            "features.enabled": False
        }
    }
}

# ============ COLOR OUTPUT ============
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def log_request(flow):
    """Log incoming requests"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    method = flow.request.method
    url = flow.request.pretty_url
    
    # Color based on method
    if method == "GET":
        method_color = Colors.GREEN
    elif method == "POST":
        method_color = Colors.BLUE
    elif method == "DELETE":
        method_color = Colors.RED
    else:
        method_color = Colors.YELLOW
    
    print(f"{Colors.HEADER}[{timestamp}]{Colors.ENDC} "
          f"{method_color}{method:6}{Colors.ENDC} {url}")

def log_modification(path, modification_type):
    """Log when a response is modified"""
    print(f"{Colors.YELLOW}  ↳ Modified: {path} ({modification_type}){Colors.ENDC}")

# ============ HELPER FUNCTIONS ============
def set_nested_value(obj, path, value):
    """Set a nested dictionary value using dot notation"""
    keys = path.split('.')
    for key in keys[:-1]:
        if key not in obj:
            obj[key] = {}
        obj = obj[key]
    obj[keys[-1]] = value

def should_modify(flow, config):
    """Check if this request should be modified"""
    if not config.get("enabled", True):
        return False
    
    path = flow.request.path
    match_type = config.get("match_type", "path_contains")
    pattern = list(MODIFICATIONS.keys())[list(MODIFICATIONS.values()).index(config)]
    
    if match_type == "exact_path":
        return path == pattern
    elif match_type == "path_contains":
        return pattern in path
    elif match_type == "regex":
        import re
        return re.search(pattern, path) is not None
    
    return False

# ============ MAIN MODIFICATION LOGIC ============
def response(flow: http.HTTPFlow) -> None:
    """Main function that modifies responses"""
    
    # Log the request
    log_request(flow)
    
    # Check each modification rule
    for pattern, config in MODIFICATIONS.items():
        if should_modify(flow, config):
            
            # Add delay if specified
            if "delay" in config:
                time.sleep(config["delay"])
                log_modification(flow.request.path, f"delayed {config['delay']}s")
            
            # Modify existing response
            if config.get("modify_existing", False):
                try:
                    # Parse existing response
                    original = json.loads(flow.response.content)
                    
                    # Apply modifications
                    for key, value in config.get("modifications", {}).items():
                        set_nested_value(original, key, value)
                    
                    # Update response
                    flow.response.content = json.dumps(original).encode()
                    log_modification(flow.request.path, "modified existing")
                    
                except json.JSONDecodeError:
                    print(f"{Colors.RED}  ↳ Error: Could not parse JSON response{Colors.ENDC}")
            
            # Replace entire response
            elif "response" in config:
                response_config = config["response"]
                
                # Set status code
                if "status_code" in response_config:
                    flow.response.status_code = response_config["status_code"]
                
                # Set body
                if "body" in response_config:
                    body = response_config["body"]
                    if isinstance(body, (dict, list)):
                        flow.response.content = json.dumps(body).encode()
                        flow.response.headers["content-type"] = "application/json"
                    else:
                        flow.response.content = str(body).encode()
                
                # Set headers
                if "headers" in response_config:
                    for key, value in response_config["headers"].items():
                        flow.response.headers[key] = value
                
                log_modification(flow.request.path, f"replaced with {response_config.get('status_code', 200)}")
            
            break  # Only apply first matching rule

# ============ STARTUP MESSAGE ============
def start():
    """Called when the script starts"""
    print(f"""
{Colors.BOLD}{'='*50}
🚀 Proxy Modifier Started
{'='*50}{Colors.ENDC}

{Colors.GREEN}Proxy running on: 0.0.0.0:8080{Colors.ENDC}

{Colors.YELLOW}Active modifications:{Colors.ENDC}""")
    
    for path, config in MODIFICATIONS.items():
        if config.get("enabled", True):
            status = config.get("response", {}).get("status_code", 200) if "response" in config else "modify"
            print(f"  • {path} → {status}")
    
    print(f"""
{Colors.BLUE}Configure your Android device:{Colors.ENDC}
  1. WiFi Settings → Modify Network → Manual Proxy
  2. Host: [Your Computer IP]
  3. Port: 8080
  
{Colors.HEADER}Monitoring traffic...{Colors.ENDC}
{'='*50}
""")
