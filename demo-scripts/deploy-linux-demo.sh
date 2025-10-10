#!/bin/bash
#
# Elite Golf Cookbook - Linux Demo Deployment Script
# Quick deployment for customer POC demonstrations
#

set -e

echo "============================================"
echo "Elite Golf Club - Chef POC Demo Deployment"
echo "============================================"
echo ""

# Configuration
CUSTOMER_NAME="${1:-Demo Customer Corp}"
DEMO_PORT="${2:-8080}"
CHEF_MODE="${3:-client}"

echo "Configuration:"
echo "- Customer: $CUSTOMER_NAME"
echo "- Demo Port: $DEMO_PORT"
echo "- Chef Mode: $CHEF_MODE"
echo ""

# Create demo node configuration
echo "Creating demo configuration..."
cat > /tmp/golf-demo-node.json << EOF
{
  "golf_app": {
    "lab_mode": true,
    "customer_name": "$CUSTOMER_NAME",
    "port": $DEMO_PORT,
    "enable_ssl": false,
    "quick_setup": true,
    "compliance_mode": true,
    "audit_logging": true
  },
  "run_list": ["recipe[elite-golf-cookbook::lab_demo]"]
}
EOF

echo "Demo configuration created at /tmp/golf-demo-node.json"
echo ""

# Check if Chef is installed
if ! command -v chef-client &> /dev/null; then
    echo "Chef Client not found. Installing..."
    curl -L https://omnitruck.chef.io/install.sh | sudo bash
    echo "Chef Client installed successfully!"
    echo ""
fi

# Run Chef in appropriate mode
case $CHEF_MODE in
    "zero")
        echo "Starting Chef Zero server for demo..."
        chef-zero --port 8889 --daemon
        
        echo "Uploading cookbook..."
        knife cookbook upload elite-golf-cookbook --chef-repo-path $(dirname $(pwd)) --server-url http://localhost:8889
        
        echo "Running Chef Client against Chef Zero..."
        sudo chef-client --server-url http://localhost:8889 --json-attributes /tmp/golf-demo-node.json
        ;;
    "solo")
        echo "Running Chef Solo..."
        sudo chef-solo --json-attributes /tmp/golf-demo-node.json --cookbook-path $(dirname $(pwd))
        ;;
    "client"|*)
        echo "Running Chef Client in local mode..."
        sudo chef-client --local-mode --json-attributes /tmp/golf-demo-node.json --cookbook-path $(dirname $(pwd))
        ;;
esac

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "============================================"
echo "POC Deployment Complete!"
echo "============================================"
echo ""
echo "Access your demo at:"
echo "- Main Application: http://$SERVER_IP:$DEMO_PORT"
echo "- Health Check:     http://$SERVER_IP:$DEMO_PORT/health"
echo "- Metrics API:      http://$SERVER_IP:$DEMO_PORT/metrics.json"
echo "- Demo Config:      http://$SERVER_IP:$DEMO_PORT/demo-config.txt"
echo ""
echo "Customer: $CUSTOMER_NAME"
echo "Platform: $(uname -s) $(uname -r)"
echo "Chef Version: $(chef-client --version)"
echo ""
echo "Demo is ready for customer presentation!"
echo "============================================"