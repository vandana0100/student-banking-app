#!/bin/bash

################################################################################
# Module 6 Part 2: Portable Kubernetes Deployment Script
# Pixel River Financial Bank Application - Minikube Deployment
# 
# This script builds Docker images into Minikube's Docker daemon and deploys
# all Kubernetes manifests. It is portable and works across different
# Kubernetes environments without vendor-specific constructs.
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

################################################################################
# CONFIGURATION
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/k8s"

################################################################################
# LOGGING FUNCTIONS
################################################################################
log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warning() {
    echo "[WARNING] $*"
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################
check_command_exists() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

validate_prerequisites() {
    log_info "=== Validating Prerequisites ==="
    
    local errors=0
    
    if ! check_command_exists "minikube"; then
        log_error "Minikube is required but not installed"
        errors=$((errors + 1))
    fi
    
    if ! check_command_exists "kubectl"; then
        log_error "kubectl is required but not installed"
        errors=$((errors + 1))
    fi
    
    if ! check_command_exists "docker"; then
        log_error "Docker is required but not installed"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors error(s)"
        return 1
    fi
    
    log_success "All prerequisites validated successfully"
    return 0
}

check_minikube_running() {
    log_info "Checking if Minikube is running..."
    if minikube status &> /dev/null; then
        log_success "Minikube is running"
        return 0
    else
        log_error "Minikube is not running. Please start it with: minikube start"
        return 1
    fi
}

################################################################################
# DOCKER BUILD FUNCTIONS
################################################################################
setup_minikube_docker_env() {
    log_info "=== Setting up Minikube Docker Environment ==="
    
    log_info "Configuring Docker to use Minikube's Docker daemon..."
    eval $(minikube docker-env)
    
    if [ $? -eq 0 ]; then
        log_success "Docker environment configured for Minikube"
    else
        log_error "Failed to configure Docker environment for Minikube"
        return 1
    fi
    
    return 0
}

build_image() {
    local context="$1"
    local image_name="$2"
    local dockerfile="${context}/Dockerfile"
    
    log_info "Building ${image_name} from ${context}..."
    
    if [ ! -f "$dockerfile" ]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    if docker build -t "${image_name}:latest" "$context"; then
        log_success "Successfully built ${image_name}:latest"
        return 0
    else
        log_error "Failed to build ${image_name}:latest"
        return 1
    fi
}

build_all_images() {
    log_info "=== Building Docker Images into Minikube's Docker Daemon ==="
    
    # Build backend image
    if ! build_image "${SCRIPT_DIR}/backend" "backend"; then
        return 1
    fi
    
    # Build transactions image
    if ! build_image "${SCRIPT_DIR}/transactions" "transactions"; then
        return 1
    fi
    
    # Build studentportfolio image
    if ! build_image "${SCRIPT_DIR}/studentportfolio" "studentportfolio"; then
        return 1
    fi
    
    log_success "All images built successfully"
    return 0
}

verify_images() {
    log_info "=== Verifying Images in Minikube's Docker Daemon ==="
    
    local required_images=("backend:latest" "transactions:latest" "studentportfolio:latest")
    local missing_images=()
    
    for image in "${required_images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
            log_success "Image found: $image"
        else
            log_warning "Image not found: $image"
            missing_images+=("$image")
        fi
    done
    
    if [ ${#missing_images[@]} -gt 0 ]; then
        log_warning "Some images may not be present: ${missing_images[*]}"
        return 1
    fi
    
    log_success "All required images verified"
    return 0
}

################################################################################
# KUBERNETES DEPLOYMENT FUNCTIONS
################################################################################
apply_manifests() {
    log_info "=== Applying Kubernetes Manifests ==="
    
    if [ ! -d "$K8S_DIR" ]; then
        log_error "Kubernetes manifests directory not found: $K8S_DIR"
        return 1
    fi
    
    log_info "Applying all manifests from $K8S_DIR..."
    
    # Apply manifests in order (important for dependencies)
    # 1. Secret first (needed by backend)
    if [ -f "${K8S_DIR}/backend-secret.yaml" ]; then
        log_info "Applying backend-secret.yaml..."
        kubectl apply -f "${K8S_DIR}/backend-secret.yaml"
    fi
    
    # 2. ConfigMap (needed by nginx)
    if [ -f "${K8S_DIR}/nginx-configmap.yaml" ]; then
        log_info "Applying nginx-configmap.yaml..."
        kubectl apply -f "${K8S_DIR}/nginx-configmap.yaml"
    fi
    
    # 3. MongoDB (StatefulSet and Service)
    if [ -f "${K8S_DIR}/mongo-statefulset.yaml" ]; then
        log_info "Applying mongo-statefulset.yaml..."
        kubectl apply -f "${K8S_DIR}/mongo-statefulset.yaml"
    fi
    
    if [ -f "${K8S_DIR}/mongo-service.yaml" ]; then
        log_info "Applying mongo-service.yaml..."
        kubectl apply -f "${K8S_DIR}/mongo-service.yaml"
    fi
    
    # 4. Backend (Deployment, Service, HPA)
    if [ -f "${K8S_DIR}/backend-deployment.yaml" ]; then
        log_info "Applying backend-deployment.yaml..."
        kubectl apply -f "${K8S_DIR}/backend-deployment.yaml"
    fi
    
    if [ -f "${K8S_DIR}/backend-service.yaml" ]; then
        log_info "Applying backend-service.yaml..."
        kubectl apply -f "${K8S_DIR}/backend-service.yaml"
    fi
    
    if [ -f "${K8S_DIR}/backend-hpa.yaml" ]; then
        log_info "Applying backend-hpa.yaml..."
        kubectl apply -f "${K8S_DIR}/backend-hpa.yaml"
    fi
    
    # 5. Transactions (Deployment, Service, HPA)
    if [ -f "${K8S_DIR}/transactions-deployment.yaml" ]; then
        log_info "Applying transactions-deployment.yaml..."
        kubectl apply -f "${K8S_DIR}/transactions-deployment.yaml"
    fi
    
    if [ -f "${K8S_DIR}/transactions-service.yaml" ]; then
        log_info "Applying transactions-service.yaml..."
        kubectl apply -f "${K8S_DIR}/transactions-service.yaml"
    fi
    
    if [ -f "${K8S_DIR}/transactions-hpa.yaml" ]; then
        log_info "Applying transactions-hpa.yaml..."
        kubectl apply -f "${K8S_DIR}/transactions-hpa.yaml"
    fi
    
    # 6. Student Portfolio (Deployment, Service)
    if [ -f "${K8S_DIR}/studentportfolio-deployment.yaml" ]; then
        log_info "Applying studentportfolio-deployment.yaml..."
        kubectl apply -f "${K8S_DIR}/studentportfolio-deployment.yaml"
    fi
    
    if [ -f "${K8S_DIR}/studentportfolio-service.yaml" ]; then
        log_info "Applying studentportfolio-service.yaml..."
        kubectl apply -f "${K8S_DIR}/studentportfolio-service.yaml"
    fi
    
    # 7. Nginx (Deployment, Service)
    if [ -f "${K8S_DIR}/nginx-deployment.yaml" ]; then
        log_info "Applying nginx-deployment.yaml..."
        kubectl apply -f "${K8S_DIR}/nginx-deployment.yaml"
    fi
    
    if [ -f "${K8S_DIR}/nginx-service.yaml" ]; then
        log_info "Applying nginx-service.yaml..."
        kubectl apply -f "${K8S_DIR}/nginx-service.yaml"
    fi
    
    log_success "All manifests applied successfully"
    return 0
}

restart_deployments() {
    log_info "=== Restarting Deployments to Pick Up Local Images ==="
    
    local deployments=("backend" "transactions" "studentportfolio" "nginx")
    
    for deployment in "${deployments[@]}"; do
        log_info "Restarting deployment: $deployment"
        kubectl rollout restart deployment "$deployment" || log_warning "Failed to restart $deployment (may not exist yet)"
    done
    
    log_success "Deployment restarts initiated"
    return 0
}

wait_for_pods() {
    log_info "=== Waiting for Pods to be Ready ==="
    
    log_info "Waiting for all pods to reach Ready state..."
    kubectl wait --for=condition=ready pod --all --timeout=300s || {
        log_warning "Some pods may not be ready yet. Check with: kubectl get pods"
    }
    
    log_info "Current pod status:"
    kubectl get pods
    
    return 0
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_info "=========================================="
    log_info "Starting Kubernetes Deployment"
    log_info "Pixel River Financial Bank Application"
    log_info "=========================================="
    
    # Step 1: Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed. Please fix the issues and try again."
        exit 1
    fi
    
    # Step 2: Check if Minikube is running
    if ! check_minikube_running; then
        log_error "Minikube is not running. Please start it with: minikube start"
        exit 1
    fi
    
    # Step 3: Setup Minikube Docker environment
    if ! setup_minikube_docker_env; then
        log_error "Failed to setup Minikube Docker environment"
        exit 1
    fi
    
    # Step 4: Build all images into Minikube's Docker daemon
    if ! build_all_images; then
        log_error "Failed to build Docker images"
        exit 1
    fi
    
    # Step 5: Verify images
    if ! verify_images; then
        log_warning "Image verification had issues, but continuing..."
    fi
    
    # Step 6: Apply Kubernetes manifests
    if ! apply_manifests; then
        log_error "Failed to apply Kubernetes manifests"
        exit 1
    fi
    
    # Step 7: Restart deployments to pick up local images
    if ! restart_deployments; then
        log_warning "Deployment restart had issues, but continuing..."
    fi
    
    # Step 8: Wait for pods to be ready
    wait_for_pods
    
    log_info "=========================================="
    log_success "Deployment completed successfully!"
    log_info "=========================================="
    log_info "To access the application, run:"
    log_info "  minikube service nginx"
    log_info ""
    log_info "To check pod status, run:"
    log_info "  kubectl get pods"
    log_info "=========================================="
    
    return 0
}

# Run main function
main "$@"

