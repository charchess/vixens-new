#!/bin/bash
# CREATION: Script de vérification post-déploiement
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_RAW="${1}"
TIMEOUT="${2:-300}"

if [ -z "$KUBECONFIG_RAW" ]; then
    echo -e "${RED}❌ Error: KUBECONFIG_RAW not provided${NC}"
    exit 1
fi

echo -e "${GREEN}🔍 Starting post-deployment checks...${NC}"

# Create temporary kubeconfig
TMP_KUBECONFIG=$(mktemp)
echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
chmod 600 "$TMP_KUBECONFIG"

# Cleanup function
cleanup() {
    rm -f "$TMP_KUBECONFIG"
}
trap cleanup EXIT

check_command() {
    local cmd="$1"
    local description="$2"
    local timeout_val="${3:-60}"
    
    echo -e "${YELLOW}⏳ $description${NC}"
    
    if timeout "$timeout_val" bash -c "$cmd"; then
        echo -e "${GREEN}✅ $description${NC}"
        return 0
    else
        echo -e "${RED}❌ $description${NC}"
        return 1
    fi
}

# 1. Cluster connectivity
check_command "
    kubectl --kubeconfig='$TMP_KUBECONFIG' cluster-info
" "Cluster connectivity" 30

# 2. Node status
check_command "
    kubectl --kubeconfig='$TMP_KUBECONFIG' get nodes
    echo 'Checking node readiness...'
    kubectl --kubeconfig='$TMP_KUBECONFIG' get nodes -o json | jq -r '.items[].status.conditions[] | select(.type == \"Ready\") | .status' | grep -q 'True'
" "Node readiness" 60

# 3. System pods
check_command "
    echo 'Checking system pods...'
    kubectl --kubeconfig='$TMP_KUBECONFIG' -n kube-system get pods
    echo 'Waiting for system pods to be ready...'
    kubectl --kubeconfig='$TMP_KUBECONFIG' -n kube-system wait --for=condition=ready pod -l tier=control-plane --timeout=120s
" "System pods readiness" 120

# 4. API server health
check_command "
    kubectl --kubeconfig='$TMP_KUBECONFIG' get --raw /healthz
" "API server health" 10

# 5. DNS functionality
check_command "
    kubectl --kubeconfig='$TMP_KUBECONFIG' -n kube-system get pods -l k8s-app=kube-dns
" "DNS pods" 30

echo -e "${GREEN}✅ All post-deployment checks passed!${NC}"
