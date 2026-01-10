#!/bin/bash
# Script to manage peer-observer AWS instances

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONFIG_FILE="aws-config.env"

# Function to show help
show_help() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Peer Observer - Instance Management       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     Start EC2 instances"
    echo "  stop      Stop EC2 instances"
    echo "  status    Show current instance status"
    echo "  destroy   Permanently destroy instances (with confirmation)"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 stop"
    echo "  $0 status"
    echo "  $0 destroy"
    echo ""
}

# Check if user is asking for help before loading AWS config
if [ "${1:-help}" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Function to recreate config from AWS instances
recreate_config_from_aws() {
    echo -e "${YELLOW}Attempting to recreate $CONFIG_FILE from AWS...${NC}"
    echo ""

    # Get AWS region from environment or use default
    AWS_REGION=${AWS_REGION:-us-east-1}

    # Search for instances with names containing "node" and "web"
    echo "Searching for instances with tags Name=*node* and Name=*web*..."

    # Find all node instances (e.g., peer-observer-node01, peer-observer-node02)
    NODE_INSTANCES=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:Name,Values=*node*" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
        --output text)

    # Find web instance (e.g., peer-observer-web01, should be only one)
    WEB_INSTANCES=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:Name,Values=*web*" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
        --output text)

    if [ -z "$NODE_INSTANCES" ] && [ -z "$WEB_INSTANCES" ]; then
        echo -e "${RED}✗ No instances found with names containing 'node' or 'web'${NC}"
        echo "Please create infrastructure first using create-aws-infra.sh"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}Found instances:${NC}"

    # Process node instances
    NODE_COUNT=0
    SELECTED_NODE_NAME=""
    while IFS=$'\t' read -r INSTANCE_ID NAME STATE; do
        if [ -n "$INSTANCE_ID" ]; then
            NODE_COUNT=$((NODE_COUNT + 1))
            echo "  📦 $NAME (ID: $INSTANCE_ID, State: $STATE)"

            # Get the first node instance details
            if [ $NODE_COUNT -eq 1 ]; then
                NODE_INSTANCE_ID=$INSTANCE_ID
                NODE_STATE=$STATE
                SELECTED_NODE_NAME=$NAME
            fi
        fi
    done <<< "$NODE_INSTANCES"

    # Process web instance
    WEB_COUNT=0
    while IFS=$'\t' read -r INSTANCE_ID NAME STATE; do
        if [ -n "$INSTANCE_ID" ]; then
            WEB_COUNT=$((WEB_COUNT + 1))
            echo "  🌐 $NAME (ID: $INSTANCE_ID, State: $STATE)"
            WEB_INSTANCE_ID=$INSTANCE_ID
            WEB_STATE=$STATE
        fi
    done <<< "$WEB_INSTANCES"

    echo ""

    if [ -z "$NODE_INSTANCE_ID" ] || [ -z "$WEB_INSTANCE_ID" ]; then
        echo -e "${RED}✗ Could not find both node and web instances${NC}"
        exit 1
    fi

    # Get detailed information for node instance
    echo "Fetching detailed information for instances..."

    NODE_DETAILS=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE_ID \
        --query 'Reservations[0].Instances[0].[PublicIpAddress,SecurityGroups[0].GroupId,InstanceType,KeyName]' \
        --output text)

    read NODE_IP NODE_SECURITY_GROUP NODE_INSTANCE_TYPE KEY_NAME <<< "$NODE_DETAILS"

    # Get detailed information for web instance
    WEB_DETAILS=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $WEB_INSTANCE_ID \
        --query 'Reservations[0].Instances[0].[PublicIpAddress,SecurityGroups[0].GroupId,InstanceType]' \
        --output text)

    read WEB_IP WEB_SECURITY_GROUP WEB_INSTANCE_TYPE <<< "$WEB_DETAILS"

    # Get Elastic IP allocations if they exist
    NODE_EIP_ALLOCATION=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=instance-id,Values=$NODE_INSTANCE_ID" \
        --query 'Addresses[0].AllocationId' \
        --output text 2>/dev/null || echo "")

    WEB_EIP_ALLOCATION=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=instance-id,Values=$WEB_INSTANCE_ID" \
        --query 'Addresses[0].AllocationId' \
        --output text 2>/dev/null || echo "")

    # Handle "None" values
    [ "$NODE_IP" = "None" ] && NODE_IP=""
    [ "$WEB_IP" = "None" ] && WEB_IP=""
    [ "$NODE_EIP_ALLOCATION" = "None" ] && NODE_EIP_ALLOCATION=""
    [ "$WEB_EIP_ALLOCATION" = "None" ] && WEB_EIP_ALLOCATION=""

    # Create the config file
    cat > "$CONFIG_FILE" << EOF
# AWS Infrastructure Configuration - Peer Observer
# This file is automatically regenerated from AWS instances
# Last regenerated: $(date)

# AWS Region
AWS_REGION=$AWS_REGION

# Key Pair
KEY_NAME=$KEY_NAME

# Node01 - Bitcoin Observation Node
NODE_INSTANCE_ID=$NODE_INSTANCE_ID
NODE_IP=$NODE_IP
NODE_EIP_ALLOCATION=$NODE_EIP_ALLOCATION
NODE_SECURITY_GROUP=$NODE_SECURITY_GROUP
NODE_INSTANCE_TYPE=$NODE_INSTANCE_TYPE

# Web01 - Dashboard & Monitoring
WEB_INSTANCE_ID=$WEB_INSTANCE_ID
WEB_IP=$WEB_IP
WEB_EIP_ALLOCATION=$WEB_EIP_ALLOCATION
WEB_SECURITY_GROUP=$WEB_SECURITY_GROUP
WEB_INSTANCE_TYPE=$WEB_INSTANCE_TYPE

# Last update timestamp
LAST_UPDATE="$(date)"
EOF

    echo -e "${GREEN}✓ Configuration file $CONFIG_FILE recreated successfully${NC}"
    echo ""
    echo "Configuration details:"
    echo "  Region: $AWS_REGION"
    echo "  Key: $KEY_NAME"
    echo "  Node Instance: $NODE_INSTANCE_ID"
    echo "  Web Instance: $WEB_INSTANCE_ID"
    echo ""
}

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠ Warning: $CONFIG_FILE not found${NC}"
    echo ""
    recreate_config_from_aws
fi

# Load variables from configuration file
source "$CONFIG_FILE"

# Verify required variables were loaded
if [ -z "$NODE_INSTANCE_ID" ] || [ -z "$WEB_INSTANCE_ID" ]; then
    echo -e "${YELLOW}⚠ Warning: Could not read Instance IDs from $CONFIG_FILE${NC}"
    echo ""
    recreate_config_from_aws
    # Reload configuration after recreation
    source "$CONFIG_FILE"

    # Verify again
    if [ -z "$NODE_INSTANCE_ID" ] || [ -z "$WEB_INSTANCE_ID" ]; then
        echo -e "${RED}✗ Error: Failed to load Instance IDs even after recreation${NC}"
        exit 1
    fi
fi

NODE_INSTANCE=$NODE_INSTANCE_ID
WEB_INSTANCE=$WEB_INSTANCE_ID

# Function to check AWS session validity
check_aws_session() {
    # Try to get caller identity to check if session is valid
    if ! aws sts get-caller-identity --region $AWS_REGION &>/dev/null; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ✗ AWS Session Expired${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}Your AWS session has expired.${NC}"
        echo ""
        echo "Please reauthenticate using:"
        echo ""
        echo -e "  ${GREEN}aws sso login${NC}"
        echo ""
        exit 1
    fi
}

# Check AWS session before proceeding
check_aws_session

# Function to show instance status
show_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Instance Status ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Get all peer-observer instances (both node and web)
    ALL_INSTANCES=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:Name,Values=*peer-observer*" "Name=instance-state-name,Values=running,stopped,pending,stopping" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
        --output text)

    if [ -z "$ALL_INSTANCES" ]; then
        echo -e "  ${YELLOW}No peer-observer instances found${NC}"
        echo ""
        return
    fi

    # Separate instances into nodes and webs
    NODE_INSTANCES=""
    WEB_INSTANCES=""

    while IFS=$'\t' read -r INSTANCE_ID NAME STATE IP; do
        if [ -n "$INSTANCE_ID" ]; then
            if [[ "$NAME" == *"web"* ]] || [[ "$NAME" == *"Web"* ]]; then
                WEB_INSTANCES="${WEB_INSTANCES}${INSTANCE_ID}\t${NAME}\t${STATE}\t${IP}\n"
            else
                NODE_INSTANCES="${NODE_INSTANCES}${INSTANCE_ID}\t${NAME}\t${STATE}\t${IP}\n"
            fi
        fi
    done <<< "$ALL_INSTANCES"

    # Function to display instance
    display_instance() {
        local INSTANCE_ID=$1
        local NAME=$2
        local STATE=$3
        local IP=$4

        # Determine icon based on name
        if [[ "$NAME" == *"web"* ]] || [[ "$NAME" == *"Web"* ]]; then
            ICON="🌐"
            TYPE="Dashboard"
        elif [[ "$NAME" == *"node"* ]] || [[ "$NAME" == *"Node"* ]]; then
            ICON="📦"
            TYPE="Bitcoin"
        else
            ICON="🖥️"
            TYPE="Instance"
        fi

        # Color state
        if [ "$STATE" = "running" ]; then
            STATE_COLOR=$GREEN
        elif [ "$STATE" = "stopped" ]; then
            STATE_COLOR=$RED
        else
            STATE_COLOR=$YELLOW
        fi

        # Display instance info
        echo "  $ICON $NAME ($TYPE)"
        echo -e "     Instance ID: $INSTANCE_ID"
        echo -e "     State: ${STATE_COLOR}${STATE}${NC}"

        if [ "$IP" != "None" ] && [ -n "$IP" ]; then
            echo -e "     Public IP: $IP"
            echo -e "     SSH: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$IP"
        fi
        echo ""
    }

    # Display node instances first
    if [ -n "$NODE_INSTANCES" ]; then
        echo -e "$NODE_INSTANCES" | while IFS=$'\t' read -r INSTANCE_ID NAME STATE IP; do
            if [ -n "$INSTANCE_ID" ]; then
                display_instance "$INSTANCE_ID" "$NAME" "$STATE" "$IP"
            fi
        done
    fi

    # Display web instances last
    if [ -n "$WEB_INSTANCES" ]; then
        echo -e "$WEB_INSTANCES" | while IFS=$'\t' read -r INSTANCE_ID NAME STATE IP; do
            if [ -n "$INSTANCE_ID" ]; then
                display_instance "$INSTANCE_ID" "$NAME" "$STATE" "$IP"
            fi
        done
    fi
}

# Function to start instances
start_instances() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Starting Instances${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check current state
    NODE_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    WEB_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $WEB_INSTANCE \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    INSTANCES_TO_START=""

    if [ "$NODE_STATE" = "stopped" ]; then
        INSTANCES_TO_START="$INSTANCES_TO_START $NODE_INSTANCE"
        echo "  • Node01 is stopped, starting..."
    elif [ "$NODE_STATE" = "running" ]; then
        echo -e "  ${YELLOW}• Node01 is already running${NC}"
    else
        echo -e "  ${YELLOW}• Node01 state: $NODE_STATE${NC}"
    fi

    if [ "$WEB_STATE" = "stopped" ]; then
        INSTANCES_TO_START="$INSTANCES_TO_START $WEB_INSTANCE"
        echo "  • Web01 is stopped, starting..."
    elif [ "$WEB_STATE" = "running" ]; then
        echo -e "  ${YELLOW}• Web01 is already running${NC}"
    else
        echo -e "  ${YELLOW}• Web01 state: $WEB_STATE${NC}"
    fi

    if [ -n "$INSTANCES_TO_START" ]; then
        echo ""
        aws ec2 start-instances --region $AWS_REGION --instance-ids $INSTANCES_TO_START > /dev/null
        echo -e "${GREEN}✓ Start command sent${NC}"
        echo ""
        echo "Waiting for instances to reach 'running' state..."
        aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCES_TO_START
        echo -e "${GREEN}✓ Instances running${NC}"
        echo ""

        # Get new IPs
        echo "Fetching public IPs..."
        NODE_IP=$(aws ec2 describe-instances \
            --region $AWS_REGION \
            --instance-ids $NODE_INSTANCE \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        WEB_IP=$(aws ec2 describe-instances \
            --region $AWS_REGION \
            --instance-ids $WEB_INSTANCE \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  Instances started successfully${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  📦 Node01: $NODE_IP"
        echo "     ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$NODE_IP"
        echo ""
        echo "  🌐 Web01: $WEB_IP"
        echo "     ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$WEB_IP"
        echo ""

        # Update configuration file with new IPs
        update_config_file "$NODE_IP" "$WEB_IP"
    else
        echo ""
        echo -e "${YELLOW}No instances to start${NC}"
        echo ""
    fi
}

# Function to stop instances
stop_instances() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Stopping Instances${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check current state
    NODE_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    WEB_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $WEB_INSTANCE \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    INSTANCES_TO_STOP=""

    if [ "$NODE_STATE" = "running" ]; then
        INSTANCES_TO_STOP="$INSTANCES_TO_STOP $NODE_INSTANCE"
        echo "  • Stopping Node01..."
    elif [ "$NODE_STATE" = "stopped" ]; then
        echo -e "  ${YELLOW}• Node01 is already stopped${NC}"
    else
        echo -e "  ${YELLOW}• Node01 state: $NODE_STATE${NC}"
    fi

    if [ "$WEB_STATE" = "running" ]; then
        INSTANCES_TO_STOP="$INSTANCES_TO_STOP $WEB_INSTANCE"
        echo "  • Stopping Web01..."
    elif [ "$WEB_STATE" = "stopped" ]; then
        echo -e "  ${YELLOW}• Web01 is already stopped${NC}"
    else
        echo -e "  ${YELLOW}• Web01 state: $WEB_STATE${NC}"
    fi

    if [ -n "$INSTANCES_TO_STOP" ]; then
        echo ""
        aws ec2 stop-instances --region $AWS_REGION --instance-ids $INSTANCES_TO_STOP > /dev/null
        echo -e "${GREEN}✓ Stop command sent${NC}"
        echo ""
        echo "Waiting for instances to stop..."
        aws ec2 wait instance-stopped --region $AWS_REGION --instance-ids $INSTANCES_TO_STOP
        echo -e "${GREEN}✓ Instances stopped${NC}"
        echo ""
        echo -e "${YELLOW}ℹ Public IPs will change when instances are restarted${NC}"
        echo ""
    else
        echo ""
        echo -e "${YELLOW}No instances to stop${NC}"
        echo ""
    fi
}

# Function to update configuration file
update_config_file() {
    local NODE_IP=$1
    local WEB_IP=$2

    echo "Updating $CONFIG_FILE with new IPs..."

    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Update configuration file
    cat > "$CONFIG_FILE" << EOF
# AWS Infrastructure Configuration - Peer Observer
# This file is automatically generated by create-aws-infra.sh
# and read by manage-aws-instances.sh

# AWS Region
AWS_REGION=$AWS_REGION

# Key Pair
KEY_NAME=$KEY_NAME

# Node01 - Bitcoin Observation Node
NODE_INSTANCE_ID=$NODE_INSTANCE_ID
NODE_IP=$NODE_IP
NODE_EIP_ALLOCATION=$NODE_EIP_ALLOCATION
NODE_SECURITY_GROUP=$NODE_SECURITY_GROUP
NODE_INSTANCE_TYPE=$NODE_INSTANCE_TYPE

# Web01 - Dashboard & Monitoring
WEB_INSTANCE_ID=$WEB_INSTANCE_ID
WEB_IP=$WEB_IP
WEB_EIP_ALLOCATION=$WEB_EIP_ALLOCATION
WEB_SECURITY_GROUP=$WEB_SECURITY_GROUP
WEB_INSTANCE_TYPE=$WEB_INSTANCE_TYPE

# Last update timestamp
LAST_UPDATE="$(date)"
EOF

    echo -e "${GREEN}✓ Configuration file updated${NC}"
    echo -e "  (Backup saved as ${CONFIG_FILE}.bak)"
    echo ""
}

# Function to destroy instances permanently
destroy_instances() {
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠️  DESTROY INSTANCES (PERMANENT)  ⚠️${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}WARNING: This action will PERMANENTLY delete:${NC}"
    echo ""
    echo "  📦 Node01 (Bitcoin) - Instance ID: $NODE_INSTANCE"
    echo "  🌐 Web01 (Dashboard) - Instance ID: $WEB_INSTANCE"
    echo ""
    echo -e "${RED}⚠️  This action CANNOT be undone!${NC}"
    echo -e "${RED}⚠️  All data on these instances will be LOST!${NC}"
    echo ""

    # First confirmation
    read -p "Are you sure you want to destroy these instances? (yes/no): " confirmation1

    if [ "$confirmation1" != "yes" ]; then
        echo ""
        echo -e "${GREEN}✓ Destruction cancelled${NC}"
        echo ""
        return
    fi

    # Second confirmation with instance IDs
    echo ""
    echo -e "${YELLOW}Please type 'DESTROY' (in uppercase) to confirm:${NC}"
    read -p "> " confirmation2

    if [ "$confirmation2" != "DESTROY" ]; then
        echo ""
        echo -e "${GREEN}✓ Destruction cancelled${NC}"
        echo ""
        return
    fi

    echo ""
    echo -e "${RED}Terminating instances...${NC}"
    echo ""

    # Terminate instances
    aws ec2 terminate-instances \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE $WEB_INSTANCE > /dev/null

    echo -e "${YELLOW}✓ Termination command sent${NC}"
    echo ""
    echo "Waiting for instances to terminate..."

    aws ec2 wait instance-terminated \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE $WEB_INSTANCE

    echo ""
    echo -e "${GREEN}✓ Instances terminated${NC}"
    echo ""

    # Step 1: Release Elastic IPs
    echo -e "${BLUE}Releasing Elastic IPs...${NC}"

    if [ -n "$NODE_EIP_ALLOCATION" ]; then
        echo "  • Releasing Node Elastic IP ($NODE_EIP_ALLOCATION)..."
        aws ec2 release-address \
            --region $AWS_REGION \
            --allocation-id $NODE_EIP_ALLOCATION 2>/dev/null && \
            echo -e "${GREEN}    ✓ Node EIP released${NC}" || \
            echo -e "${YELLOW}    (Could not release Node EIP - may already be released)${NC}"
    fi

    if [ -n "$WEB_EIP_ALLOCATION" ]; then
        echo "  • Releasing Web Elastic IP ($WEB_EIP_ALLOCATION)..."
        aws ec2 release-address \
            --region $AWS_REGION \
            --allocation-id $WEB_EIP_ALLOCATION 2>/dev/null && \
            echo -e "${GREEN}    ✓ Web EIP released${NC}" || \
            echo -e "${YELLOW}    (Could not release Web EIP - may already be released)${NC}"
    fi

    echo ""

    # Step 2: Delete orphaned EBS volumes
    echo -e "${BLUE}Checking for orphaned EBS volumes...${NC}"

    # Get volumes that were attached to these instances
    ORPHANED_VOLUMES=$(aws ec2 describe-volumes \
        --region $AWS_REGION \
        --filters "Name=status,Values=available" "Name=tag:Project,Values=peer-observer" \
        --query 'Volumes[*].VolumeId' \
        --output text)

    if [ -n "$ORPHANED_VOLUMES" ]; then
        echo "  Found orphaned volumes:"
        for VOL in $ORPHANED_VOLUMES; do
            VOL_SIZE=$(aws ec2 describe-volumes \
                --region $AWS_REGION \
                --volume-ids $VOL \
                --query 'Volumes[0].Size' \
                --output text)
            echo "    • Volume: $VOL (${VOL_SIZE}GB)"
        done
        echo ""
        echo -e "${YELLOW}Do you want to delete these orphaned volumes? (yes/no):${NC}"
        read -p "> " delete_volumes

        if [ "$delete_volumes" = "yes" ]; then
            for VOL in $ORPHANED_VOLUMES; do
                echo "  • Deleting volume $VOL..."
                aws ec2 delete-volume \
                    --region $AWS_REGION \
                    --volume-id $VOL 2>/dev/null && \
                    echo -e "${GREEN}    ✓ Volume deleted${NC}" || \
                    echo -e "${YELLOW}    (Could not delete volume)${NC}"
            done
        else
            echo -e "${YELLOW}  Volumes kept. You can delete them manually later.${NC}"
        fi
    else
        echo "  No orphaned volumes found."
    fi

    echo ""

    # Step 3: Ask if user wants to clean up security groups and key pair
    echo -e "${YELLOW}Do you want to also delete security groups and key pair? (yes/no):${NC}"
    read -p "> " cleanup

    if [ "$cleanup" = "yes" ]; then
        echo ""
        echo "Cleaning up resources..."

        # Wait for network interfaces to be fully detached
        echo "Waiting for network interfaces to be detached..."
        sleep 15

        # Delete security groups with retries
        if [ -n "$NODE_SECURITY_GROUP" ]; then
            echo "Deleting Node security group..."
            for i in {1..3}; do
                if aws ec2 delete-security-group \
                    --region $AWS_REGION \
                    --group-id $NODE_SECURITY_GROUP 2>/dev/null; then
                    echo -e "${GREEN}  ✓ Node security group deleted${NC}"
                    break
                else
                    if [ $i -lt 3 ]; then
                        echo -e "${YELLOW}  Retry $i/3...${NC}"
                        sleep 5
                    else
                        echo -e "${YELLOW}  (Could not delete Node security group - may still have dependencies)${NC}"
                    fi
                fi
            done
        fi

        if [ -n "$WEB_SECURITY_GROUP" ]; then
            echo "Deleting Web security group..."
            for i in {1..3}; do
                if aws ec2 delete-security-group \
                    --region $AWS_REGION \
                    --group-id $WEB_SECURITY_GROUP 2>/dev/null; then
                    echo -e "${GREEN}  ✓ Web security group deleted${NC}"
                    break
                else
                    if [ $i -lt 3 ]; then
                        echo -e "${YELLOW}  Retry $i/3...${NC}"
                        sleep 5
                    else
                        echo -e "${YELLOW}  (Could not delete Web security group - may still have dependencies)${NC}"
                    fi
                fi
            done
        fi

        # Delete key pair
        if [ -n "$KEY_NAME" ]; then
            echo "Deleting key pair from AWS..."
            aws ec2 delete-key-pair \
                --region $AWS_REGION \
                --key-name $KEY_NAME 2>/dev/null && \
                echo -e "${GREEN}  ✓ Key pair deleted from AWS${NC}" || \
                echo -e "${YELLOW}  (Could not delete key pair)${NC}"

            echo -e "${YELLOW}Note: Local key file ~/.ssh/${KEY_NAME}.pem was NOT deleted${NC}"
            echo -e "${YELLOW}      Delete it manually if needed: rm ~/.ssh/${KEY_NAME}.pem${NC}"
        fi

        echo ""
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Infrastructure destroyed${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "The configuration file $CONFIG_FILE is still present."
    echo "You can delete it manually if needed."
    echo ""
}

# Main
case "${1:-help}" in
    start)
        start_instances
        ;;
    stop)
        stop_instances
        ;;
    status)
        show_status
        ;;
    destroy)
        destroy_instances
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}✗ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
