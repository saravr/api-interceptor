#!/usr/bin/env python3
"""
Simple Proxy Server for Modifying API Responses
Usage: mitmdump -s proxy_modifier.py -p 8080
"""

from mitmproxy import http
import json
import os
import time
from datetime import datetime

# Load modifications from external file
def load_modifications():
    config_file = "modifications_config.json"
    if os.path.exists(config_file):
        try:
            with open(config_file, 'r') as f:
                data = json.load(f)
                print(f"[INFO] Loaded {len(data)} modification rules from {config_file}")
                return data
        except Exception as e:
            print(f"[ERROR] Failed to load {config_file}: {e}")
            return {}
    else:
        print(f"Warning: {config_file} not found, using empty config")
        return {}

MODIFICATIONS = load_modifications()

# ============ COLOR OUTPUT ============
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def log_debug(message):
    """Log debug information"""
    print(f"{Colors.BLUE}  [DEBUG] {message}{Colors.ENDC}")

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
    pattern = list(MODIFICATIONS.keys())[list(MODIFICATIONS.values()).index(config)]
    
    # Debug: Log what we're checking
    log_debug(f"Checking rule: {pattern}")
    log_debug(f"Request path: {flow.request.path}")
    log_debug(f"Query params: {dict(flow.request.query)}")
    
    if not config.get("enabled", True):
        log_debug("Rule disabled, skipping")
        return False
    
    path = flow.request.path
    match_type = config.get("match_type", "path_contains")
    log_debug(f"Match type: {match_type}")
    
    if match_type == "exact_path":
        result = path == pattern
        log_debug(f"Exact path match: {result}")
        return result
    elif match_type == "path_contains":
        result = pattern in path
        log_debug(f"Path contains match: {result}")
        return result
    elif match_type == "query_param":
        query_params = dict(flow.request.query)
        required_params = config.get("query_params", {})
        log_debug(f"Required params: {required_params}")
        
        for param, value in required_params.items():
            if param not in query_params:
                log_debug(f"Missing required param: {param}")
                return False
            if value is not None:
                if isinstance(value, list):
                    if query_params[param] not in value:
                        log_debug(f"Param {param}={query_params[param]} not in allowed values {value}")
                        return False
                else:
                    if query_params[param] != value:
                        log_debug(f"Param {param}={query_params[param]} != required {value}")
                        return False
        
        path_match = pattern in path
        log_debug(f"Query params matched, path contains check: {path_match}")
        return path_match
    
    return False

# ============ MAIN MODIFICATION LOGIC ============
def response(flow: http.HTTPFlow) -> None:
    """Main function that modifies responses"""

    # Debug: Basic info
    print(f"{Colors.BLUE}[DEBUG] Response function called for: {flow.request.path}{Colors.ENDC}")
    print(f"{Colors.BLUE}[DEBUG] Number of modification rules: {len(MODIFICATIONS)}{Colors.ENDC}")

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
