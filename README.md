# APK Network Security Modifier & Response Interceptor

**Modify Android APKs to intercept HTTPS traffic and test error scenarios without source code access.**

## 📚 Quick Navigation

- [🚀 Quick Start (5 minutes)](#-quick-start-5-minutes) - Get running fast
- [📋 Prerequisites](#-prerequisites) - What you need installed
- [📦 Installation](#-installation) - Detailed setup instructions
- [🎯 Basic Usage](#-basic-usage) - Common use cases
- [🔧 Advanced Configuration](#-advanced-configuration) - Customize responses
- [🐛 Troubleshooting](#-troubleshooting) - Common issues
- [📖 Complete Documentation](#-complete-documentation) - All features
- [⚠️ Security Notice](#️-security-notice) - Important warnings

---

## 🚀 Quick Start (5 minutes)

**Get your app intercepted in 5 steps:**

### 1️⃣ Install Prerequisites
```bash
# Mac users
brew install apktool android-platform-tools
brew install --cask android-commandlinetools
pip install mitmproxy

# Linux users
sudo apt install apktool adb
pip install mitmproxy
```

### 2️⃣ Clone this repository
```bash
git clone https://github.com/saravr/api-interceptor
cd api-interceptor
chmod +x modapk.sh
```

### 3️⃣ Modify Your APK
```bash
# Modify APK to accept proxy certificates
./modapk.sh -k <path-to-keystore-file> -p <keystore-password> -a <key-alias> your-app.apk

# Install modified APK
adb uninstall com.your.app.package  # Remove original
adb install your-app_modified.apk   # Install modified
```

### 4️⃣ Configure Proxy Rules
Edit `proxy_modifier.py` - change `/api/login` to your actual endpoint:
```python
def response(flow: http.HTTPFlow) -> None:
    if "/api/login" in flow.request.path:  # ← Your endpoint here
        flow.response.status_code = 401
        flow.response.content = b'{"error": "Auth failed"}'
        print(f"✅ Modified: {flow.request.path}")
```

### 5️⃣ Start Intercepting
```bash
# Terminal 1: Start proxy
mitmweb -s proxy_modifier.py -p 8080

# Terminal 2: Get your IP
ipconfig getifaddr en0  # Mac
hostname -I             # Linux
```

**On Android:**
1. WiFi Settings → Your Network → Modify → Manual Proxy
2. Enter your computer's IP and port 8080
3. Open Chrome, go to `http://mitm.it`, install Android certificate
4. Open your app - see modified responses! 🎉

---

## 📋 Prerequisites

<details>
<summary>Click to expand prerequisites</summary>

### Required Tools

| Tool | Purpose | Install Command |
|------|---------|----------------|
| **apktool** | Decompile/rebuild APKs | `brew install apktool` |
| **Android SDK** | Sign & align APKs | `brew install --cask android-commandlinetools` |
| **Python 3.8+** | Run proxy scripts | Pre-installed on most systems |
| **mitmproxy** | Intercept HTTPS | `pip install mitmproxy` |
| **adb** | Install APKs | `brew install android-platform-tools` |

### Verify Installation
```bash
apktool --version
python3 --version
mitmdump --version
adb --version
```

</details>

---

## 📦 Installation

<details>
<summary>Click to expand detailed installation</summary>

### macOS
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all tools
brew install apktool android-platform-tools
brew install --cask android-commandlinetools
pip install mitmproxy

# Set Android SDK path
echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> ~/.zshrc
source ~/.zshrc
```

### Ubuntu/Debian
```bash
# Update packages
sudo apt update

# Install tools
sudo apt install apktool adb default-jdk
pip install mitmproxy

# Add Python scripts to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Windows
```powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install tools
choco install apktool adb python
pip install mitmproxy
```

</details>

---

## 🎯 Basic Usage

### Modify APK

```bash
# Simple modification
./modapk.sh app.apk

# With options
./modapk.sh app.apk -o custom_name.apk --verbose

# Get help
./modapk.sh -h
```

### Configure Response Modifications

**Simple Error Responses:**
```python
# proxy_modifier.py
def response(flow: http.HTTPFlow) -> None:
    path = flow.request.path
    
    # Authentication error
    if "/login" in path:
        flow.response.status_code = 401
        flow.response.content = b'{"error": "Invalid credentials"}'
    
    # Server error
    elif "/api/data" in path:
        flow.response.status_code = 500
        flow.response.content = b'{"error": "Server error"}'
    
    # Empty response
    elif "/api/list" in path:
        flow.response.content = b'[]'
```

### Run Proxy

```bash
# With web interface (see all traffic)
mitmweb -s proxy_modifier.py -p 8080

# Terminal UI
mitmproxy -s proxy_modifier.py -p 8080

# Headless (background/CI)
mitmdump -s proxy_modifier.py -p 8080
```

---

## 🔧 Advanced Configuration

<details>
<summary>Click to expand advanced features</summary>

### Dynamic Rules Configuration

Create `proxy_rules.json`:
```json
{
  "enabled": true,
  "rules": [
    {
      "path": "/api/login",
      "status": 401,
      "response": {"error": "Authentication failed"}
    },
    {
      "path": "/api/users",
      "status": 200,
      "response": {"users": [], "total": 0}
    },
    {
      "path": "/api/timeout",
      "delay": 30,
      "status": 504,
      "response": "Gateway Timeout"
    }
  ]
}
```

Use with dynamic script:
```python
# dynamic_proxy.py
import json

def response(flow):
    with open('proxy_rules.json') as f:
        rules = json.load(f)
    
    for rule in rules['rules']:
        if rule['path'] in flow.request.path:
            flow.response.status_code = rule['status']
            flow.response.content = json.dumps(rule['response']).encode()
            break
```

### Response Modification Patterns

```python
# Advanced modifications
def response(flow: http.HTTPFlow) -> None:
    import time, random, json
    
    # Simulate network delay
    if "/slow" in flow.request.path:
        time.sleep(5)
        flow.response.status_code = 504
    
    # Random failures (chaos testing)
    elif "/unreliable" in flow.request.path:
        if random.random() > 0.5:
            flow.response.status_code = 503
    
    # Modify existing response
    elif "/profile" in flow.request.path:
        data = json.loads(flow.response.content)
        data['premium'] = False
        data['credits'] = 0
        flow.response.content = json.dumps(data).encode()
    
    # Rate limiting
    elif "/limited" in flow.request.path:
        flow.response.status_code = 429
        flow.response.headers["Retry-After"] = "3600"
```

### Custom Network Security Config

For stubborn apps with certificate pinning:
```xml
<!-- network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
    <domain-config>
        <domain includeSubdomains="true">yourdomain.com</domain>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </domain-config>
</network-security-config>
```

</details>

---

## 🐛 Troubleshooting

<details>
<summary>Click to expand troubleshooting guide</summary>

### Common Issues

| Problem | Solution |
|---------|----------|
| **"zipalign not found"** | `export ANDROID_HOME="$HOME/Library/Android/sdk"` |
| **"TLS handshake failed"** | Visit `http://mitm.it` on Android, install certificate |
| **"INSTALL_FAILED_INVALID_APK"** | Run: `zipalign -v 4 app.apk app_aligned.apk` |
| **No traffic in proxy** | Check WiFi proxy settings, disable mobile data |
| **App won't connect** | App may detect modification, try emulator |

### Debug Commands

```bash
# Check proxy connection
curl -x http://localhost:8080 http://example.com

# Verify Android proxy
adb shell settings get global http_proxy

# Set proxy via ADB
adb shell settings put global http_proxy 192.168.1.100:8080

# Check installed certificates
adb shell ls /data/misc/user/0/cacerts-added/

# View app package name
adb shell dumpsys package | grep -A1 "Package \["
```

### Certificate Issues

```bash
# Manually install certificate
adb push ~/.mitmproxy/mitmproxy-ca-cert.cer /sdcard/
# Then: Settings → Security → Install from storage

# For Android 11+
# Settings → Security → Encryption & credentials → Install certificate → CA certificate
```

</details>

---

## 📖 Complete Documentation

<details>
<summary>Click to expand full documentation</summary>

### Script Options

#### modapk.sh Options
```bash
Usage: ./modapk.sh <input.apk> [options]

Options:
  -h, --help               Show help message
  -o, --output <file>      Output APK name (default: input_modified.apk)
  -k, --keystore <path>    Custom keystore (default: ~/.android/debug.keystore)
  -p, --password <pass>    Keystore password (default: android)
  -a, --alias <alias>      Key alias (default: androiddebugkey)
  --keep-temp              Keep temporary files for debugging
  --verbose                Show detailed output
```

#### Proxy Interfaces

**mitmweb** - Web Interface
- URL: http://localhost:8081
- Best for: Visual inspection, debugging
- Features: Search, filters, replay requests

**mitmproxy** - Terminal UI
- Navigation: Arrow keys, Enter to inspect
- Best for: Quick terminal-based inspection
- Features: Filters, inline editing

**mitmdump** - Headless
- Best for: Automation, CI/CD, logging
- Features: Scriptable, low resource usage

### API Response Testing Scenarios

```python
# Complete testing scenarios
from mitmproxy import http
import json
import time
import random

class ResponseModifier:
    def __init__(self):
        self.request_count = {}
    
    def response(self, flow: http.HTTPFlow) -> None:
        path = flow.request.path
        
        # === ERROR RESPONSES ===
        
        # 400 - Bad Request
        if "/api/validate" in path:
            flow.response.status_code = 400
            flow.response.content = json.dumps({
                "errors": [
                    {"field": "email", "message": "Invalid format"},
                    {"field": "age", "message": "Must be positive"}
                ]
            }).encode()
        
        # 401 - Unauthorized
        elif "/api/secure" in path:
            flow.response.status_code = 401
            flow.response.headers["WWW-Authenticate"] = "Bearer"
            flow.response.content = b'{"error": "Token expired"}'
        
        # 403 - Forbidden
        elif "/api/admin" in path:
            flow.response.status_code = 403
            flow.response.content = b'{"error": "Insufficient permissions"}'
        
        # 404 - Not Found
        elif "/api/user/999" in path:
            flow.response.status_code = 404
            flow.response.content = b'{"error": "User not found"}'
        
        # 429 - Rate Limited
        elif "/api/limited" in path:
            self.request_count[path] = self.request_count.get(path, 0) + 1
            if self.request_count[path] > 3:
                flow.response.status_code = 429
                flow.response.headers["X-RateLimit-Limit"] = "3"
                flow.response.headers["X-RateLimit-Remaining"] = "0"
                flow.response.headers["Retry-After"] = "60"
        
        # 500 - Server Error
        elif "/api/crash" in path:
            flow.response.status_code = 500
            flow.response.content = b'{"error": "Internal server error", "trace": "NullPointerException at line 42"}'
        
        # 503 - Service Unavailable
        elif "/api/maintenance" in path:
            flow.response.status_code = 503
            flow.response.headers["Retry-After"] = "300"
            flow.response.content = b'{"error": "Service under maintenance"}'
        
        # === SPECIAL SCENARIOS ===
        
        # Timeout simulation
        elif "/api/timeout" in path:
            time.sleep(35)  # Most apps timeout at 30s
        
        # Partial response (connection dropped)
        elif "/api/partial" in path:
            flow.response.content = b'{"data": [1, 2, 3'  # Incomplete JSON
        
        # Large response
        elif "/api/huge" in path:
            data = [{"id": i, "data": "x" * 1000} for i in range(10000)]
            flow.response.content = json.dumps(data).encode()
        
        # Slow response (byte by byte)
        elif "/api/drip" in path:
            # This simulates a very slow connection
            original = flow.response.content
            flow.response.stream = lambda chunks: self.drip_response(original, chunks)
        
        # Redirect loop
        elif "/api/redirect" in path:
            flow.response.status_code = 302
            flow.response.headers["Location"] = "/api/redirect"
        
        # Invalid content-type
        elif "/api/wrong-type" in path:
            flow.response.headers["Content-Type"] = "text/html"
            # But the body is JSON
        
        # Corrupted encoding
        elif "/api/corrupt" in path:
            flow.response.headers["Content-Encoding"] = "gzip"
            # But the content is not gzipped
    
    def drip_response(self, content, chunks):
        """Simulate very slow response"""
        import time
        for byte in content:
            time.sleep(0.1)  # 100ms per byte
            yield bytes([byte])

addons = [ResponseModifier()]
```

### Testing Patterns

#### Pattern 1: Progressive Degradation
```python
# Test how app handles degrading service
class ProgressiveDegradation:
    def __init__(self):
        self.health = 100
    
    def response(self, flow):
        self.health -= 5  # Degrade by 5% each request
        
        if self.health > 50:
            pass  # Normal response
        elif self.health > 25:
            time.sleep(2)  # Slow
        elif self.health > 0:
            flow.response.status_code = 503  # Errors
        else:
            flow.kill()  # Connection drops
```

#### Pattern 2: Chaos Engineering
```python
# Random failures for resilience testing
import random

def response(flow):
    chaos = random.random()
    
    if chaos < 0.1:  # 10% complete failure
        flow.response.status_code = 500
    elif chaos < 0.2:  # 10% timeout
        time.sleep(30)
    elif chaos < 0.3:  # 10% malformed
        flow.response.content = b'not json'
    # 70% normal
```

#### Pattern 3: State-based Testing
```python
# Different responses based on state
class StatefulTester:
    def __init__(self):
        self.logged_in = False
        self.request_count = 0
    
    def response(self, flow):
        self.request_count += 1
        
        if "/login" in flow.request.path:
            if self.request_count < 3:
                flow.response.status_code = 401
            else:
                self.logged_in = True
                flow.response.status_code = 200
        
        elif not self.logged_in:
            flow.response.status_code = 403
```

### Integration Examples

#### With Jest/Mocha Tests
```javascript
// test-with-proxy.js
describe('Error Handling', () => {
    beforeAll(async () => {
        // Start proxy with error rules
        await exec('./start-proxy.sh error-rules.json');
    });
    
    it('handles 401 gracefully', async () => {
        const result = await app.login('user', 'pass');
        expect(result.error).toBe('Invalid credentials');
        expect(app.isLoggedIn).toBe(false);
    });
    
    it('retries on 503', async () => {
        const result = await app.fetchData();
        expect(app.retryCount).toBeGreaterThan(0);
    });
});
```

#### With CI/CD Pipeline
```yaml
# .github/workflows/error-testing.yml
name: Error Response Testing

on: [push, pull_request]

jobs:
  test-error-handling:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          pip install mitmproxy
          sudo apt-get install apktool adb
      
      - name: Modify APK
        run: ./modapk.sh app-release.apk
      
      - name: Start Android emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 29
          script: |
            # Install modified APK
            adb install app-release_modified.apk
            
            # Start proxy
            mitmdump -s proxy_modifier.py -p 8080 &
            
            # Configure proxy
            adb shell settings put global http_proxy 10.0.2.2:8080
            
            # Run tests
            adb shell am instrument -w com.app.test/androidx.test.runner.AndroidJUnitRunner
```

#### With Docker
```dockerfile
# Dockerfile
FROM python:3.9-slim

RUN pip install mitmproxy
COPY proxy_modifier.py /app/
COPY proxy_rules.json /app/

WORKDIR /app
EXPOSE 8080 8081

CMD ["mitmdump", "-s", "proxy_modifier.py", "-p", "8080"]
```

```bash
# Run proxy in Docker
docker build -t android-proxy .
docker run -p 8080:8080 -p 8081:8081 android-proxy
```

### Performance Testing

```python
# performance_test.py
from mitmproxy import http
import time
import json

class PerformanceTester:
    def __init__(self):
        self.latencies = []
    
    def response(self, flow: http.HTTPFlow):
        # Add artificial latency
        latency = len(flow.response.content) / 1000  # 1ms per KB
        time.sleep(latency)
        
        # Track performance
        self.latencies.append({
            'path': flow.request.path,
            'method': flow.request.method,
            'latency': latency,
            'size': len(flow.response.content),
            'status': flow.response.status_code
        })
        
        # Every 100 requests, save stats
        if len(self.latencies) % 100 == 0:
            with open('performance.json', 'w') as f:
                json.dump(self.latencies, f)
```

</details>

---

## ⚠️ Security Notice

**Important Security Information:**

- ✅ **DO**: Use only on apps you own or have permission to test
- ✅ **DO**: Use for development and QA testing
- ✅ **DO**: Keep modified APKs secure and private
- ❌ **DON'T**: Distribute modified APKs
- ❌ **DON'T**: Use on production apps without permission
- ❌ **DON'T**: Use for malicious purposes
- ❌ **DON'T**: Test apps with sensitive personal data

**Note:** Modified APKs will have different signatures, and some features may not work:
- Google Play Services
- In-app purchases  
- App-specific signature verification
- SafetyNet/Play Integrity checks

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## Caution

Contains code generated by AI.

## 🙏 Acknowledgments

- [apktool](https://apktool.org/) - APK decompilation/recompilation
- [mitmproxy](https://mitmproxy.org/) - HTTPS interception framework
- Android SDK Tools - APK signing and alignment

---

**Need Help?** [Create an Issue](https://github.com/YOUR_REPO/issues) | [Discussions](https://github.com/YOUR_REPO/discussions)

**Found this useful?** Give it a ⭐ on GitHub!
