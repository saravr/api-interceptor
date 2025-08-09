#!/bin/bash

# Script name for help text
SCRIPT_NAME=$(basename "$0")

# Colors for output (using tput for better compatibility)
if [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NC=""
fi

# Function to find Android SDK tools
find_android_tool() {
    local tool_name="$1"
    local tool_path=""
    
    # Check if tool is already in PATH
    if command -v "$tool_name" &> /dev/null; then
        echo "$(command -v $tool_name)"
        return 0
    fi
    
    # Common Android SDK locations
    local sdk_paths=(
        "$ANDROID_HOME"
        "$ANDROID_SDK_ROOT"
        "$HOME/Android/Sdk"
        "$HOME/Library/Android/sdk"
        "/usr/local/android-sdk"
        "/opt/android-sdk"
        "$HOME/android-sdk"
        "/Applications/Android Studio.app/Contents/sdk"
    )
    
    # Find the SDK path
    local sdk_path=""
    for path in "${sdk_paths[@]}"; do
        if [ -d "$path/build-tools" ]; then
            sdk_path="$path"
            break
        fi
    done
    
    if [ -z "$sdk_path" ]; then
        return 1
    fi
    
    # Find the latest build-tools version
    local latest_version=""
    if [ -d "$sdk_path/build-tools" ]; then
        latest_version=$(ls -1 "$sdk_path/build-tools" | grep -E '^[0-9]+\.' | sort -V | tail -1)
    fi
    
    if [ -n "$latest_version" ]; then
        tool_path="$sdk_path/build-tools/$latest_version/$tool_name"
        if [ -f "$tool_path" ]; then
            echo "$tool_path"
            return 0
        fi
    fi
    
    return 1
}

# Function to show usage/help
show_help() {
    printf "%s\n" "${GREEN}${BOLD}APK Network Security Modifier${NC}

${YELLOW}USAGE:${NC}
    $SCRIPT_NAME <input.apk> [options]

${YELLOW}DESCRIPTION:${NC}
    Modifies an Android APK to trust user certificates, allowing HTTPS proxy
    interception for testing. The script decompiles the APK, adds a network
    security configuration, rebuilds, aligns, and signs it.

${YELLOW}ARGUMENTS:${NC}
    <input.apk>              Path to the APK file to modify

${YELLOW}OPTIONS:${NC}
    -h, --help               Show this help message and exit
    -o, --output <file>      Specify output APK name (default: input_modified.apk)
    -k, --keystore <path>    Custom keystore path (default: ~/.android/debug.keystore)
    -p, --password <pass>    Keystore password (default: android)
    -a, --alias <alias>      Key alias (default: androiddebugkey)
    --keep-temp              Don't delete temporary working directory
    --verbose                Show detailed output

${YELLOW}EXAMPLES:${NC}
    # Basic usage
    $SCRIPT_NAME app.apk

    # With custom output name
    $SCRIPT_NAME app.apk -o app_patched.apk

    # With custom keystore
    $SCRIPT_NAME app.apk -k my.keystore -p mypass -a myalias

    # Keep temporary files for debugging
    $SCRIPT_NAME app.apk --keep-temp

${YELLOW}REQUIREMENTS:${NC}
    - apktool
    - Android SDK build-tools (for zipalign and apksigner)
    - Java JDK (for jarsigner as fallback)

${YELLOW}NOTES:${NC}
    • The modified APK will have a different signature than the original
    • You need to uninstall the original app before installing the modified version
    • After installation, configure your WiFi proxy settings and install the
      proxy's CA certificate on your device

${YELLOW}AFTER MODIFICATION:${NC}
    1. Uninstall original app: ${BLUE}adb uninstall <package_name>${NC}
    2. Install modified APK: ${BLUE}adb install <output_apk>${NC}
    3. Set WiFi proxy to your computer's IP:8080
    4. Install mitmproxy CA certificate from ${BLUE}http://mitm.it${NC}
"
}

# Function to show error and exit
show_error() {
    printf "%s\n" "${RED}Error: $1${NC}" >&2
    printf "Use '%s -h' for help\n" "$SCRIPT_NAME" >&2
    exit 1
}

# Function to find required tools
ZIPALIGN=""
APKSIGNER=""

find_tools() {
    # Find zipalign
    ZIPALIGN=$(find_android_tool "zipalign")
    if [ -z "$ZIPALIGN" ]; then
        printf "%s\n" "${YELLOW}Warning: zipalign not found in Android SDK${NC}" >&2
        printf "%s\n" "${YELLOW}Trying to find Android SDK...${NC}" >&2
        
        # Show helpful message
        printf "%s\n" "${YELLOW}Please ensure Android SDK is installed and either:${NC}" >&2
        printf "%s\n" "  1. Set ANDROID_HOME environment variable" >&2
        printf "%s\n" "  2. Install Android SDK in a standard location" >&2
        printf "%s\n" "  3. Add build-tools to PATH" >&2
        return 1
    else
        if [ "$VERBOSE" = true ]; then
            printf "%s\n" "${GREEN}Found zipalign: $ZIPALIGN${NC}"
        fi
    fi
    
    # Find apksigner
    APKSIGNER=$(find_android_tool "apksigner")
    if [ -n "$APKSIGNER" ] && [ "$VERBOSE" = true ]; then
        printf "%s\n" "${GREEN}Found apksigner: $APKSIGNER${NC}"
    fi
    
    return 0
}

# Function to check requirements
check_requirements() {
    local missing=()
    
    if ! command -v apktool &> /dev/null; then
        missing+=("apktool")
    fi
    
    # Check for Android SDK tools
    if ! find_tools; then
        missing+=("Android SDK build-tools (zipalign)")
    fi
    
    if [ -z "$APKSIGNER" ] && ! command -v jarsigner &> /dev/null; then
        missing+=("apksigner or jarsigner")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        printf "%s\n" "${RED}Missing required tools: ${missing[*]}${NC}" >&2
        printf "%s\n" "${YELLOW}Install instructions:${NC}" >&2
        printf "%s\n" "  • apktool: https://apktool.org" >&2
        printf "%s\n" "  • Android SDK: https://developer.android.com/studio" >&2
        printf "%s\n" "  • Set ANDROID_HOME to your SDK path" >&2
        printf "%s\n" "  • Java JDK: https://adoptium.net" >&2
        exit 1
    fi
}

# Default values
INPUT_APK=""
OUTPUT_APK=""
KEYSTORE="$HOME/.android/debug.keystore"
STOREPASS="android"
ALIAS="androiddebugkey"
KEEP_TEMP=false
VERBOSE=false

# Parse arguments
if [ $# -eq 0 ]; then
    show_error "No APK file specified"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output)
            OUTPUT_APK="$2"
            shift 2
            ;;
        -k|--keystore)
            KEYSTORE="$2"
            shift 2
            ;;
        -p|--password)
            STOREPASS="$2"
            shift 2
            ;;
        -a|--alias)
            ALIAS="$2"
            shift 2
            ;;
        --keep-temp)
            KEEP_TEMP=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            show_error "Unknown option: $1"
            ;;
        *)
            if [ -z "$INPUT_APK" ]; then
                INPUT_APK="$1"
            else
                show_error "Multiple input files specified. Only one APK can be processed at a time"
            fi
            shift
            ;;
    esac
done

# Validate input
if [ -z "$INPUT_APK" ]; then
    show_error "No APK file specified"
fi

if [ ! -f "$INPUT_APK" ]; then
    show_error "APK file not found: $INPUT_APK"
fi

# Set default output name if not specified
if [ -z "$OUTPUT_APK" ]; then
    OUTPUT_APK="${INPUT_APK%.apk}_modified.apk"
fi

# Check requirements
check_requirements

# Set up working files
ALIGNED_APK="${OUTPUT_APK%.apk}_aligned.apk"
WORK_DIR="apk_mod_temp_$$"

# Function for logging
log() {
    printf "${GREEN}[+]${NC} %s\n" "$1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        printf "${BLUE}[v]${NC} %s\n" "$1"
    fi
}

log_warning() {
    printf "${YELLOW}[!]${NC} %s\n" "$1"
}

# Start modification process
printf "%s\n" "${GREEN}========================================${NC}"
printf "%s\n" "${GREEN}${BOLD}APK Network Security Modifier${NC}"
printf "%s\n" "${GREEN}========================================${NC}"
log "Input:  $INPUT_APK"
log "Output: $OUTPUT_APK"
if [ "$VERBOSE" = true ]; then
    log_verbose "Using zipalign: $ZIPALIGN"
    if [ -n "$APKSIGNER" ]; then
        log_verbose "Using apksigner: $APKSIGNER"
    else
        log_verbose "Using jarsigner (apksigner not found)"
    fi
fi
printf "\n"

# Step 1: Decompile APK
log "Decompiling APK..."
if [ "$VERBOSE" = true ]; then
    apktool d "$INPUT_APK" -o "$WORK_DIR" -f
else
    apktool d "$INPUT_APK" -o "$WORK_DIR" -f &> /dev/null
fi

if [ $? -ne 0 ]; then
    show_error "Failed to decompile APK"
fi
log_verbose "APK decompiled to $WORK_DIR"

# Step 2: Create network security config
log "Adding network security config..."
mkdir -p "$WORK_DIR/res/xml"
cat > "$WORK_DIR/res/xml/network_security_config.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
EOF
log_verbose "Created network_security_config.xml"

# Step 3: Modify AndroidManifest.xml
log "Modifying AndroidManifest.xml..."
MANIFEST="$WORK_DIR/AndroidManifest.xml"

# Add network security config
if ! grep -q "android:networkSecurityConfig" "$MANIFEST"; then
    sed -i.bak '/<application/s/>/ android:networkSecurityConfig="@xml\/network_security_config">/' "$MANIFEST"
    log_verbose "Added networkSecurityConfig attribute"
else
    log_verbose "networkSecurityConfig already present"
fi

# Fix extractNativeLibs if needed (important for Android 6.0+)
if ! grep -q "android:extractNativeLibs" "$MANIFEST"; then
    sed -i '/<application/s/>/ android:extractNativeLibs="true">/' "$MANIFEST"
    log_verbose "Added extractNativeLibs=true"
else
    log_verbose "extractNativeLibs already present"
fi

# Step 4: Rebuild APK
log "Rebuilding APK..."
if [ "$VERBOSE" = true ]; then
    apktool b "$WORK_DIR" -o "$OUTPUT_APK" --use-aapt2
else
    apktool b "$WORK_DIR" -o "$OUTPUT_APK" --use-aapt2 &> /dev/null
fi

if [ $? -ne 0 ]; then
    show_error "Failed to rebuild APK"
fi
log_verbose "APK rebuilt successfully"

# Step 5: Align the APK
log "Aligning APK..."
if [ "$VERBOSE" = true ]; then
    "$ZIPALIGN" -v -p 4 "$OUTPUT_APK" "$ALIGNED_APK"
else
    "$ZIPALIGN" -p 4 "$OUTPUT_APK" "$ALIGNED_APK" 2> /dev/null
fi

if [ $? -ne 0 ]; then
    show_error "Failed to align APK"
fi
log_verbose "APK aligned successfully"

# Step 6: Sign the APK
log "Signing APK..."

# Check if keystore exists
if [ ! -f "$KEYSTORE" ]; then
    log_warning "Keystore not found, creating debug keystore..."
    keytool -genkey -v -keystore "$KEYSTORE" \
        -alias "$ALIAS" \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass "$STOREPASS" \
        -keypass "$STOREPASS" \
        -dname "CN=Android Debug,O=Android,C=US" &> /dev/null
fi

if [ -n "$APKSIGNER" ]; then
    log_verbose "Using apksigner"
    if [ "$VERBOSE" = true ]; then
        "$APKSIGNER" sign --ks "$KEYSTORE" \
            --ks-pass "pass:$STOREPASS" \
            --ks-key-alias "$ALIAS" \
            --key-pass "pass:$STOREPASS" \
            --out "$OUTPUT_APK" \
            "$ALIGNED_APK"
    else
        "$APKSIGNER" sign --ks "$KEYSTORE" \
            --ks-pass "pass:$STOREPASS" \
            --ks-key-alias "$ALIAS" \
            --key-pass "pass:$STOREPASS" \
            --out "$OUTPUT_APK" \
            "$ALIGNED_APK" &> /dev/null
    fi
    rm "$ALIGNED_APK"  # Clean up aligned temporary file
else
    log_verbose "Using jarsigner (fallback)"
    jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
        -keystore "$KEYSTORE" \
        -storepass "$STOREPASS" \
        "$ALIGNED_APK" "$ALIAS" &> /dev/null
    mv "$ALIGNED_APK" "$OUTPUT_APK"
fi

if [ $? -ne 0 ]; then
    show_error "Failed to sign APK"
fi

# Step 7: Verify alignment
log "Verifying APK alignment..."
if [ "$VERBOSE" = true ]; then
    "$ZIPALIGN" -c -v 4 "$OUTPUT_APK"
else
    "$ZIPALIGN" -c 4 "$OUTPUT_APK" 2> /dev/null
fi

if [ $? -eq 0 ]; then
    log_verbose "APK alignment verified"
else
    log_warning "APK alignment verification failed (may still work)"
fi

# Step 8: Clean up
if [ "$KEEP_TEMP" = false ]; then
    log "Cleaning up temporary files..."
    rm -rf "$WORK_DIR"
    rm -f "${MANIFEST}.bak"
else
    log_warning "Keeping temporary directory: $WORK_DIR"
fi

# Success message
printf "\n"
printf "%s\n" "${GREEN}========================================${NC}"
printf "%s\n" "${GREEN}${BOLD}✅ APK modification complete!${NC}"
printf "%s\n" "${GREEN}========================================${NC}"
printf "\n"
printf "%s\n" "${YELLOW}Output file:${NC} $OUTPUT_APK"
printf "\n"
printf "%s\n" "${YELLOW}Next steps:${NC}"
printf "%s\n" "  1. Uninstall original app:"
printf "%s\n" "     ${BLUE}adb uninstall <package_name>${NC}"
printf "\n"
printf "%s\n" "  2. Install modified APK:"
printf "%s\n" "     ${BLUE}adb install $OUTPUT_APK${NC}"
printf "\n"
printf "%s\n" "  3. Configure proxy in WiFi settings:"
printf "%s\n" "     • Host: Your computer's IP address"
printf "%s\n" "     • Port: 8080"
printf "\n"
printf "%s\n" "  4. Install proxy CA certificate:"
printf "%s\n" "     • Visit ${BLUE}http://mitm.it${NC} on your device"
printf "%s\n" "     • Download and install the Android certificate"
printf "\n"
printf "%s\n" "${GREEN}Happy testing! 🚀${NC}"
