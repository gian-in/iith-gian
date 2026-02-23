#!/bin/bash
# Configuration
SERVER_USER="gianadmin"
SERVER_HOST="192.168.161.141"
TARGET_HOST="${SERVER_USER}@${SERVER_HOST}"
SERVER_PATH="/var/www/html"
BUILD_DIR="dist"
BUILD_LOG="build_output.log"

# Color codes for better visibility
GREEN="\e[1;32m"
BLUE="\e[1;34m"
RED="\e[1;31m"
YELLOW="\e[1;33m"
RESET="\e[0m"

echo "========================================"
echo "  IITH GIAN Production Deployment"
echo "========================================"
echo "Server: $TARGET_HOST"
echo "Path: $SERVER_PATH"
echo "========================================"
echo ""

# Confirmation prompt
read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled by user${RESET}"
    exit 0
fi

echo ""

echo -e "${BLUE}Starting build process...${RESET}"

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
    echo -e "${BLUE}Previous build cleaned${RESET}"
fi

# Run build and capture output to both terminal and log file
if yarn build 2>&1 | tee "${BUILD_LOG}" | grep -qi 'error'; then
    echo -e "${RED}Build failed! ${BLUE}Please resolve errors before deploying:${RESET}"
    grep -i 'error' "${BUILD_LOG}" | tail -10
    rm -f "${BUILD_LOG}"
    exit 1
else
    echo -e "${GREEN}Build successful!${RESET}"
    rm -f "${BUILD_LOG}"

    # Create a timestamp for the backup
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    echo -e "${BLUE}Creating backup of current deployment (${TIMESTAMP})...${RESET}"
    ssh ${TARGET_HOST} "[ -d '$SERVER_PATH' ] && [ \"\$(ls -A '$SERVER_PATH' 2>/dev/null)\" ] && cp -r '$SERVER_PATH' '$SERVER_PATH'_backup_$TIMESTAMP 2>/dev/null || echo 'No previous deployment to backup'"

    echo -e "${BLUE}Uploading build files to server...${RESET}"
    scp -r "$BUILD_DIR" "${TARGET_HOST}:/tmp/deployment_${TIMESTAMP}"

    if [ $? -eq 0 ]; then
        # echo -e "${GREEN}Build and upload completed successfully!${RESET}"
        # echo ""
        # echo -e "${YELLOW}========================================"
        # echo -e "  MANUAL DEPLOYMENT STEPS"
        # echo -e "========================================"
        # echo -e "SSH to your server and run these commands:"
        # echo -e "ssh ${TARGET_HOST}"
        # echo -e ""
        echo -e "# Clear current deployment"
        echo -e "sudo rm -rf '$SERVER_PATH'/*"
        echo -e ""
        echo -e "# Deploy new files"
        echo -e "sudo cp -r /tmp/deployment_${TIMESTAMP}/* '$SERVER_PATH'/"
        # echo -e ""
        # echo -e "# Set proper permissions"
        # echo -e "sudo chown -R www-data:www-data '$SERVER_PATH'"
        # echo -e "sudo chmod -R 755 '$SERVER_PATH'"
        # echo -e "sudo find '$SERVER_PATH' -type f -exec chmod 644 {} \;"
        # echo -e ""
        # echo -e "# Clean up temp files"
        echo -e "rm -rf /tmp/deployment_${TIMESTAMP}"
        # echo -e ""
        # echo -e "# Reload nginx (optional)"
        # echo -e "sudo nginx -t && sudo systemctl reload nginx"
        # echo -e ""
        # echo -e "========================================"
        # echo -e "After running these commands, your app will be live at:"
        # echo -e "http://$SERVER_HOST"
        # echo -e "=======================================${RESET}"
    else
        echo -e "${RED}Upload failed!${RESET}"
        exit 1
    fi
fi