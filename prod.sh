#!/bin/bash

# Production deployment script for IITH GIAN React/Vite application
# Usage: ./prod.sh

SERVER_USER="gianadmin"
SERVER_HOST="192.168.161.141"
SERVER_PATH="/var/www/html"
BUILD_DIR="dist"
BACKUP_DIR="/var/www/html_backup_$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists yarn; then
        print_error "yarn is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists scp; then
        print_error "scp is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists ssh; then
        print_error "ssh is not installed or not in PATH"
        exit 1
    fi
    
    print_success "All prerequisites are available"
}

clean_build() {
    print_status "Cleaning previous build..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_success "Previous build cleaned"
    else
        print_status "No previous build found"
    fi
}

install_dependencies() {
    print_status "Installing/updating dependencies..."
    yarn install --frozen-lockfile
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

build_project() {
    print_status "Building the project..."
    yarn build
    
    if [ $? -eq 0 ] && [ -d "$BUILD_DIR" ]; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi
}

test_connection() {
    print_status "Testing SSH connection to $SERVER_USER@$SERVER_HOST..."
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$SERVER_USER@$SERVER_HOST" echo "Connection successful" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "SSH connection successful"
    else
        print_error "Cannot connect to server. Please check:"
        print_error "  - Server credentials (user: $SERVER_USER, host: $SERVER_HOST)"
        print_error "  - SSH key authentication is set up"
        print_error "  - Server is accessible"
        exit 1
    fi
}

create_backup() {
    print_status "Creating backup on server..."
    ssh "$SERVER_USER@$SERVER_HOST" "
        if [ -d '$SERVER_PATH' ] && [ \"\$(ls -A '$SERVER_PATH' 2>/dev/null)\" ]; then
            sudo cp -r '$SERVER_PATH' '$BACKUP_DIR' 2>/dev/null || {
                echo 'Backup failed - insufficient permissions or path does not exist'
                exit 1
            }
            echo 'Backup created at $BACKUP_DIR'
        else
            echo 'No existing deployment found, skipping backup'
        fi
    "
    
    if [ $? -eq 0 ]; then
        print_success "Backup completed"
    else
        print_warning "Backup may have failed, but continuing deployment"
    fi
}

deploy_files() {
    print_status "Deploying files to $SERVER_USER@$SERVER_HOST:$SERVER_PATH..."
    
    # Create a temporary directory with the build contents
    TEMP_DIR=$(mktemp -d)
    cp -r "$BUILD_DIR"/* "$TEMP_DIR"/
    
    # Create temporary directory on server in user's home directory
    REMOTE_TEMP_DIR="/tmp/deployment_$(date +%Y%m%d_%H%M%S)"
    
    # Copy files to temporary directory on server first
    scp -r "$TEMP_DIR"/* "$SERVER_USER@$SERVER_HOST:$REMOTE_TEMP_DIR/"
    
    if [ $? -eq 0 ]; then
        print_success "Files uploaded to temporary directory"
        
        # Clear existing files and move from temp directory using sudo
        print_status "Moving files to web directory with proper permissions..."
        ssh "$SERVER_USER@$SERVER_HOST" "
            # Clear existing content
            sudo rm -rf '$SERVER_PATH'/* 2>/dev/null || echo 'Note: Directory was empty or already cleared'
            
            # Move files from temp to web directory
            sudo cp -r '$REMOTE_TEMP_DIR'/* '$SERVER_PATH'/ 2>/dev/null || {
                echo 'Error: Failed to move files to web directory'
                exit 1
            }
            
            # Clean up temp directory
            rm -rf '$REMOTE_TEMP_DIR'
            
            echo 'Files moved successfully'
        "
        
        if [ $? -eq 0 ]; then
            print_success "Files deployed successfully"
        else
            print_error "Failed to move files to web directory"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        print_error "Failed to upload files to server"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clean up local temporary directory
    rm -rf "$TEMP_DIR"
}

set_permissions() {
    print_status "Setting proper permissions on server..."
    ssh "$SERVER_USER@$SERVER_HOST" "
        sudo chown -R www-data:www-data '$SERVER_PATH' 2>/dev/null || {
            echo 'Warning: Could not set www-data ownership'
        }
        sudo chmod -R 755 '$SERVER_PATH' 2>/dev/null || {
            echo 'Warning: Could not set file permissions'
        }
        sudo find '$SERVER_PATH' -type f -exec chmod 644 {} \; 2>/dev/null || {
            echo 'Warning: Could not set individual file permissions'
        }
    "
    
    print_success "Permissions set"
}

reload_nginx() {
    print_status "Reloading nginx configuration..."
    ssh "$SERVER_USER@$SERVER_HOST" "
        sudo nginx -t && sudo systemctl reload nginx 2>/dev/null || {
            echo 'Warning: Could not reload nginx - please check manually'
        }
    "
    
    print_success "Nginx reload attempted"
}

verify_deployment() {
    print_status "Verifying deployment..."
    
    ssh "$SERVER_USER@$SERVER_HOST" "[ -f '$SERVER_PATH/index.html' ]"
    
    if [ $? -eq 0 ]; then
        print_success "Deployment verification passed"
        print_success "Application should be available at: http://$SERVER_HOST"
    else
        print_error "Deployment verification failed - index.html not found"
        exit 1
    fi
}

main() {
    echo "========================================"
    echo "  IITH GIAN Production Deployment"
    echo "========================================"
    echo "Server: $SERVER_USER@$SERVER_HOST"
    echo "Path: $SERVER_PATH"
    echo "========================================"
    echo ""
    
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
    
    echo ""
    
    check_prerequisites
    test_connection
    clean_build
    install_dependencies
    build_project
    create_backup
    deploy_files
    set_permissions
    reload_nginx
    verify_deployment
    
    echo ""
    print_success "========================================"
    print_success "  Deployment completed successfully!"
    print_success "========================================"
    print_success "Your application is now live at:"
    print_success "  http://$SERVER_HOST"
    print_success "========================================"
    
    if [ -n "$BACKUP_DIR" ]; then
        print_status "Backup created at: $BACKUP_DIR"
    fi
}

trap 'echo -e "\n${RED}[ERROR]${NC} Deployment interrupted by user"; exit 1' INT

main "$@"