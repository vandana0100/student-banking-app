#!/bin/bash

################################################################################
# Module 6 Part 1: Automated Linux Deployment Script
# Pixel River Financial Bank Application - Microservice Deployment
# 
# This script automates the end-to-end deployment of the banking microservice
# application using Docker Compose. It is idempotent, parameterized, and includes
# comprehensive validation and logging.
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

################################################################################
# CONFIGURATION PARAMETERS
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
LOG_FILE="${LOG_FILE:-deployment.log}"
NGINX_LOGS_FILE="${NGINX_LOGS_FILE:-nginx-logs.txt}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-2}"
REQUIRED_PORTS=(80 3000 5000)
BASE_URL="${BASE_URL:-http://localhost}"

################################################################################
# LOGGING FUNCTIONS
################################################################################
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@" >&2
}

log_success() {
    log "SUCCESS" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################
check_command_exists() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed or not in PATH"
        return 1
    fi
    log_info "$cmd is installed: $(command -v $cmd)"
    return 0
}

check_port_available() {
    local port="$1"
    if command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "Port $port is already in use"
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "Port $port is already in use"
            return 1
        fi
    else
        log_warning "Cannot check port availability (netstat/ss not available)"
    fi
    log_info "Port $port is available"
    return 0
}

validate_prerequisites() {
    log_info "=== Validating Prerequisites ==="
    
    local errors=0
    
    # Check Docker
    if ! check_command_exists "docker"; then
        log_error "Docker is required but not installed"
        errors=$((errors + 1))
    else
        log_info "Docker version: $(docker --version)"
    fi
    
    # Check Docker Compose
    if ! check_command_exists "docker-compose"; then
        log_error "Docker Compose is required but not installed"
        errors=$((errors + 1))
    else
        log_info "Docker Compose version: $(docker-compose --version)"
    fi
    
    # Check required ports
    log_info "Checking required ports availability..."
    for port in "${REQUIRED_PORTS[@]}"; do
        check_port_available "$port" || errors=$((errors + 1))
    done
    
    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors error(s)"
        return 1
    fi
    
    log_success "All prerequisites validated successfully"
    return 0
}

validate_deployment_directory() {
    log_info "=== Validating Deployment Directory ==="
    
    cd "$SCRIPT_DIR" || {
        log_error "Failed to change to script directory: $SCRIPT_DIR"
        return 1
    }
    
    log_info "Current directory: $(pwd)"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    log_success "Docker Compose file found: $COMPOSE_FILE"
    return 0
}

################################################################################
# DEPLOYMENT FUNCTIONS
################################################################################
build_and_deploy() {
    log_info "=== Building and Deploying Services ==="
    
    # Stop and remove existing containers if they exist (idempotency)
    log_info "Cleaning up existing containers (if any)..."
    docker-compose down -v 2>/dev/null || true
    
    # Build images
    log_info "Building Docker images..."
    if docker-compose build; then
        log_success "Docker images built successfully"
    else
        log_error "Failed to build Docker images"
        return 1
    fi
    
    # Start services
    log_info "Starting services with Docker Compose..."
    if docker-compose up -d; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        return 1
    fi
    
    # Wait for services to be ready
    log_info "Waiting for services to initialize..."
    sleep 5
    
    return 0
}

validate_images() {
    log_info "=== Validating Built Images ==="
    
    log_info "Listing all Docker images:"
    docker images | tee -a "$LOG_FILE"
    
    local required_images=("backend" "transactions" "studentportfolio" "nginx:alpine" "mongo:6")
    local missing_images=()
    
    for image in "${required_images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image%:*}"; then
            log_success "Image found: $image"
        else
            log_warning "Image not found: $image"
            missing_images+=("$image")
        fi
    done
    
    if [ ${#missing_images[@]} -gt 0 ]; then
        log_warning "Some images may not be present: ${missing_images[*]}"
    fi
    
    return 0
}

show_running_containers() {
    log_info "=== Showing Running Containers ==="
    
    log_info "Docker containers status:"
    docker ps | tee -a "$LOG_FILE"
    
    # Extract nginx container ID
    local nginx_container_id
    nginx_container_id=$(docker ps --filter "ancestor=nginx:alpine" --format "{{.ID}}" | head -n1)
    
    if [ -z "$nginx_container_id" ]; then
        log_error "Nginx container not found"
        return 1
    fi
    
    log_success "Nginx container ID: $nginx_container_id"
    export NGINX_CONTAINER_ID="$nginx_container_id"
    
    return 0
}

perform_health_checks() {
    log_info "=== Performing Health Checks ==="
    
    local max_attempts=$((HEALTH_CHECK_TIMEOUT / HEALTH_CHECK_INTERVAL))
    local attempt=0
    local backend_healthy=false
    local transactions_healthy=false
    local nginx_healthy=false
    
    log_info "Checking service health (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."
    
    # Check backend service (port 5000)
    log_info "Checking backend service at ${BASE_URL}:5000..."
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "${BASE_URL}:5000" > /dev/null 2>&1 || \
           wget -q --spider "${BASE_URL}:5000" 2>/dev/null; then
            log_success "Backend service is healthy"
            backend_healthy=true
            break
        fi
        attempt=$((attempt + 1))
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    if [ "$backend_healthy" = false ]; then
        log_warning "Backend service health check failed or timed out"
    fi
    
    # Check transactions service (port 3000)
    log_info "Checking transactions service at ${BASE_URL}:3000..."
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "${BASE_URL}:3000" > /dev/null 2>&1 || \
           wget -q --spider "${BASE_URL}:3000" 2>/dev/null; then
            log_success "Transactions service is healthy"
            transactions_healthy=true
            break
        fi
        attempt=$((attempt + 1))
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    if [ "$transactions_healthy" = false ]; then
        log_warning "Transactions service health check failed or timed out"
    fi
    
    # Check nginx (port 80)
    log_info "Checking nginx service at ${BASE_URL}..."
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "${BASE_URL}" > /dev/null 2>&1 || \
           wget -q --spider "${BASE_URL}" 2>/dev/null; then
            log_success "Nginx service is healthy and page renders correctly"
            nginx_healthy=true
            break
        fi
        attempt=$((attempt + 1))
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    if [ "$nginx_healthy" = false ]; then
        log_error "Nginx service health check failed or timed out"
        return 1
    fi
    
    log_success "All health checks passed"
    return 0
}

install_jq() {
    log_info "=== Installing jq (if needed) ==="
    
    if check_command_exists "jq"; then
        log_info "jq is already installed"
        return 0
    fi
    
    log_info "Installing jq..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v apk &> /dev/null; then
        sudo apk add --no-cache jq
    else
        log_error "Cannot install jq: package manager not found"
        return 1
    fi
    
    if check_command_exists "jq"; then
        log_success "jq installed successfully"
        return 0
    else
        log_error "Failed to install jq"
        return 1
    fi
}

inspect_nginx_image() {
    log_info "=== Inspecting nginx:alpine Image ==="
    
    # Ensure jq is installed
    if ! install_jq; then
        log_warning "jq installation failed, continuing without JSON parsing"
    fi
    
    log_info "Running docker inspect on nginx:alpine..."
    docker inspect nginx:alpine > "$NGINX_LOGS_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Docker inspect output saved to: $NGINX_LOGS_FILE"
    else
        log_error "Failed to inspect nginx:alpine image"
        return 1
    fi
    
    # Extract and echo specified keys
    log_info "=== Extracting Key Information from nginx:alpine ==="
    
    if command -v jq &> /dev/null; then
        echo ""
        echo "=== RepoTags ==="
        jq -r '.[0].RepoTags[]' "$NGINX_LOGS_FILE" 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Could not extract RepoTags"
        
        echo ""
        echo "=== Created ==="
        jq -r '.[0].Created' "$NGINX_LOGS_FILE" 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Could not extract Created"
        
        echo ""
        echo "=== Os ==="
        jq -r '.[0].Os' "$NGINX_LOGS_FILE" 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Could not extract Os"
        
        echo ""
        echo "=== Config ==="
        jq -r '.[0].Config' "$NGINX_LOGS_FILE" 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Could not extract Config"
        
        echo ""
        echo "=== ExposedPorts ==="
        jq -r '.[0].Config.ExposedPorts' "$NGINX_LOGS_FILE" 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Could not extract ExposedPorts"
        echo ""
    else
        log_warning "jq not available, showing raw inspect output:"
        cat "$NGINX_LOGS_FILE"
    fi
    
    return 0
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_info "=========================================="
    log_info "Starting Automated Deployment"
    log_info "Pixel River Financial Bank Application"
    log_info "=========================================="
    
    # Initialize log file
    > "$LOG_FILE"
    
    # Step 1: Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed. Please fix the issues and try again."
        exit 1
    fi
    
    # Step 2: Validate deployment directory
    if ! validate_deployment_directory; then
        log_error "Deployment directory validation failed."
        exit 1
    fi
    
    # Step 3: Build and deploy
    if ! build_and_deploy; then
        log_error "Build and deployment failed."
        exit 1
    fi
    
    # Step 4: Validate images
    validate_images
    
    # Step 5: Show running containers and extract nginx ID
    if ! show_running_containers; then
        log_error "Failed to identify nginx container"
        exit 1
    fi
    
    # Step 6: Perform health checks
    if ! perform_health_checks; then
        log_error "Health checks failed"
        exit 1
    fi
    
    # Step 7: Install jq and inspect nginx image
    if ! inspect_nginx_image; then
        log_warning "Nginx image inspection had issues, but continuing..."
    fi
    
    log_info "=========================================="
    log_success "Deployment completed successfully!"
    log_info "=========================================="
    log_info "Application URL: ${BASE_URL}"
    log_info "Backend API: ${BASE_URL}:5000"
    log_info "Transactions API: ${BASE_URL}:3000"
    log_info "Log file: $LOG_FILE"
    log_info "Nginx logs: $NGINX_LOGS_FILE"
    log_info "=========================================="
    
    return 0
}

# Run main function
main "$@"

