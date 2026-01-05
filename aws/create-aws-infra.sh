#!/bin/bash
# Complete script to create peer-observer infrastructure on AWS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Peer Observer - AWS Infrastructure Setup ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Configuration - ADJUST THESE VALUES
AWS_REGION="us-east-1"
KEY_NAME="peer-observer-key"
INSTANCE_TYPE_NODE="t3.large"      # 2 vCPU, 8 GB RAM
INSTANCE_TYPE_WEB="t3.medium"      # 2 vCPU, 4 GB RAM
BITCOIN_VOLUME_SIZE=1000           # GB for blockchain
WEB_VOLUME_SIZE=100                # GB for webserver

echo -e "${YELLOW}Configuration:${NC}"
echo "  Region: $AWS_REGION"
echo "  Key Pair: $KEY_NAME"
echo "  Node Instance: $INSTANCE_TYPE_NODE (Bitcoin volume: ${BITCOIN_VOLUME_SIZE}GB)"
echo "  Web Instance: $INSTANCE_TYPE_WEB (Volume: ${WEB_VOLUME_SIZE}GB)"
echo ""

# Verify AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ Error: AWS CLI not installed${NC}"
    echo "Install with: brew install awscli"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

# Verify credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ Error: AWS credentials not configured${NC}"
    echo "Configure with: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: $ACCOUNT_ID${NC}"

# Key Pair Selection
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  SSH Key Pair Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ask user preference
echo "What would you like to do?"
echo "  1) Use an existing key pair"
echo "  2) Create a new key pair"
echo ""
read -p "Select option (1/2): " KEY_OPTION

case "$KEY_OPTION" in
    1)
        # List existing key pairs
        echo ""
        echo "Checking for existing key pairs in AWS..."
        EXISTING_KEYS=$(aws ec2 describe-key-pairs --region $AWS_REGION --query 'KeyPairs[*].KeyName' --output text 2>/dev/null || echo "")

        if [ -z "$EXISTING_KEYS" ]; then
            echo -e "${RED}✗ No existing key pairs found${NC}"
            echo "Creating a new one..."
            KEY_OPTION=2
        else
            echo -e "${GREEN}Found existing key pairs:${NC}"
            echo "$EXISTING_KEYS" | tr '\t' '\n' | nl
            echo ""
            echo "Available key pairs:"
            # Convert to array for selection
            readarray -t KEY_ARRAY <<< "$(echo "$EXISTING_KEYS" | tr '\t' '\n')"
            for i in "${!KEY_ARRAY[@]}"; do
                echo "     $((i+1))    ${KEY_ARRAY[$i]}"
            done
            echo ""
            read -p "Enter the number or name of the key pair (or press Enter for '$KEY_NAME'): " SELECTED_KEY

            if [ -z "$SELECTED_KEY" ]; then
                SELECTED_KEY=$KEY_NAME
            elif [[ "$SELECTED_KEY" =~ ^[0-9]+$ ]]; then
                # User entered a number, convert to key name
                INDEX=$((SELECTED_KEY - 1))
                if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#KEY_ARRAY[@]} ]; then
                    SELECTED_KEY="${KEY_ARRAY[$INDEX]}"
                else
                    echo -e "${RED}✗ Invalid selection number${NC}"
                    exit 1
                fi
            fi

            # Verify selected key exists
            if aws ec2 describe-key-pairs --key-names $SELECTED_KEY --region $AWS_REGION &> /dev/null; then
                KEY_NAME=$SELECTED_KEY
                echo -e "${GREEN}✓ Using existing key pair: $KEY_NAME${NC}"

                # Check if local PEM file exists
                if [ ! -f ~/.ssh/${KEY_NAME}.pem ]; then
                    echo -e "${YELLOW}⚠ Warning: Local key file ~/.ssh/${KEY_NAME}.pem not found${NC}"
                    echo "Make sure you have the private key file to connect to the instances."
                    read -p "Do you have the .pem file for this key? (y/n): " HAS_KEY
                    if [ "$HAS_KEY" != "y" ]; then
                        echo -e "${RED}✗ Cannot proceed without the private key file${NC}"
                        exit 1
                    fi
                else
                    echo -e "${GREEN}✓ Local key file found: ~/.ssh/${KEY_NAME}.pem${NC}"
                fi
            else
                echo -e "${RED}✗ Key pair '$SELECTED_KEY' does not exist${NC}"
                exit 1
            fi
        fi
        ;;
    2)
        # Create new key pair
        ;;
    *)
        echo -e "${RED}✗ Invalid option${NC}"
        exit 1
        ;;
esac

# Create new key pair if option 2 was selected
if [ "$KEY_OPTION" = "2" ]; then
    echo ""
    read -p "Enter name for new key pair (default: $KEY_NAME): " NEW_KEY_NAME

    if [ -n "$NEW_KEY_NAME" ]; then
        KEY_NAME=$NEW_KEY_NAME
    fi

    # Check if key already exists
    if aws ec2 describe-key-pairs --key-names $KEY_NAME --region $AWS_REGION &> /dev/null; then
        echo -e "${RED}✗ Key pair '$KEY_NAME' already exists in AWS${NC}"
        echo "Choose option 1 to use it, or pick a different name."
        exit 1
    fi

    # Check if local file exists
    if [ -f ~/.ssh/${KEY_NAME}.pem ]; then
        echo -e "${YELLOW}⚠ Local file ~/.ssh/${KEY_NAME}.pem already exists${NC}"
        read -p "Overwrite it? (yes/no): " OVERWRITE
        if [ "$OVERWRITE" != "yes" ]; then
            echo -e "${RED}Aborting.${NC}"
            exit 1
        fi
    fi

    echo "Creating new key pair '$KEY_NAME'..."
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --region $AWS_REGION \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/${KEY_NAME}.pem
    chmod 400 ~/.ssh/${KEY_NAME}.pem
    echo -e "${GREEN}✓ Key pair created: ~/.ssh/${KEY_NAME}.pem${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 1: Configuring Security Groups${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

MY_IP=$(curl -s https://checkip.amazonaws.com)/32
echo "Your public IP: $MY_IP"

# Create Security Group for nodes
echo ""
echo "Creating Security Group for nodes..."
NODE_SG_NAME="peer-observer-nodes"
if NODE_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$NODE_SG_NAME" --region $AWS_REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null) && [ "$NODE_SG" != "None" ]; then
    echo -e "${YELLOW}⚠ Security Group '$NODE_SG_NAME' already exists: $NODE_SG${NC}"
else
    NODE_SG=$(aws ec2 create-security-group \
        --group-name $NODE_SG_NAME \
        --description "Security group for Bitcoin observation nodes" \
        --region $AWS_REGION \
        --query 'GroupId' \
        --output text)

    # Rules for nodes
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $NODE_SG --protocol tcp --port 22 --cidr $MY_IP --output text > /dev/null
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $NODE_SG --protocol tcp --port 8333 --cidr 0.0.0.0/0 --output text > /dev/null
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $NODE_SG --protocol udp --port 51820 --cidr 0.0.0.0/0 --output text > /dev/null

    echo -e "${GREEN}✓ Security Group Nodes created: $NODE_SG${NC}"
fi

# Create Security Group for webserver
echo ""
echo "Creating Security Group for webserver..."
WEB_SG_NAME="peer-observer-webserver"
if WEB_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$WEB_SG_NAME" --region $AWS_REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null) && [ "$WEB_SG" != "None" ]; then
    echo -e "${YELLOW}⚠ Security Group '$WEB_SG_NAME' already exists: $WEB_SG${NC}"
else
    WEB_SG=$(aws ec2 create-security-group \
        --group-name $WEB_SG_NAME \
        --description "Security group for peer-observer webserver" \
        --region $AWS_REGION \
        --query 'GroupId' \
        --output text)

    # Rules for webserver
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $WEB_SG --protocol tcp --port 22 --cidr $MY_IP --output text > /dev/null
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $WEB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --output text > /dev/null
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $WEB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0 --output text > /dev/null
    aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $WEB_SG --protocol udp --port 51820 --cidr 0.0.0.0/0 --output text > /dev/null

    echo -e "${GREEN}✓ Security Group Web created: $WEB_SG${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 2: Getting Ubuntu AMI${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

UBUNTU_AMI=$(aws ec2 describe-images \
    --region $AWS_REGION \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo -e "${GREEN}✓ Ubuntu 22.04 AMI: $UBUNTU_AMI${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 3: Checking Existing Instances${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for existing instances
echo "Checking for existing instances..."

# Check for all nodes (node01, node02, etc.)
EXISTING_NODES=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Project,Values=peer-observer" "Name=tag:Name,Values=peer-observer-node*" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output text 2>/dev/null)

EXISTING_WEB=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=peer-observer-web01" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)

# Parse existing nodes
declare -A EXISTING_NODE_IDS
declare -A EXISTING_NODE_STATES
NODE_COUNT=0
WEB_EXISTS=false

if [ -n "$EXISTING_NODES" ]; then
    echo -e "${YELLOW}Found existing nodes:${NC}"
    while IFS=$'\t' read -r instance_id name state; do
        echo "  - $name: $instance_id (state: $state)"
        EXISTING_NODE_IDS["$name"]=$instance_id
        EXISTING_NODE_STATES["$name"]=$state
        NODE_COUNT=$((NODE_COUNT + 1))
    done <<< "$EXISTING_NODES"
fi

if [ "$EXISTING_WEB" != "None" ] && [ -n "$EXISTING_WEB" ]; then
    WEB_EXISTS=true
    WEB_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $EXISTING_WEB \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    echo -e "${YELLOW}✓ Found existing web01: $EXISTING_WEB (state: $WEB_STATE)${NC}"
fi

if [ $NODE_COUNT -eq 0 ] && [ "$WEB_EXISTS" = false ]; then
    echo "No existing instances found."
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 4: Instance Selection${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CREATE_WEB=false
declare -a NODES_TO_CREATE=()
declare -A NODE_TYPES=()

# Check if infrastructure already exists
HAS_INFRASTRUCTURE=false
if [ $NODE_COUNT -gt 0 ] || [ "$WEB_EXISTS" = true ]; then
    HAS_INFRASTRUCTURE=true
fi

# Main decision flow
if [ "$HAS_INFRASTRUCTURE" = true ]; then
    echo -e "${YELLOW}Existing infrastructure detected!${NC}"
    echo ""
    echo "What would you like to do?"
    echo "  1) Use existing infrastructure (no changes)"
    echo "  2) Expand infrastructure (add new nodes)"
    echo ""
    read -p "Select option (1/2): " INFRA_OPTION

    case "$INFRA_OPTION" in
        1)
            echo -e "${GREEN}Using existing infrastructure...${NC}"
            SKIP_CREATION=true
            ;;
        2)
            # Expanding infrastructure
            echo -e "${GREEN}Expanding infrastructure...${NC}"
            echo ""

            # If web exists, only allow adding nodes
            if [ "$WEB_EXISTS" = true ]; then
                echo -e "${YELLOW}Web server already exists. You can only add Bitcoin nodes.${NC}"
                echo ""

                # Ask how many nodes to add
                read -p "How many Bitcoin nodes do you want to add? (1-10): " NUM_NODES

                if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ] || [ "$NUM_NODES" -gt 10 ]; then
                    echo -e "${RED}✗ Invalid number. Please enter a number between 1 and 10.${NC}"
                    exit 1
                fi

                # Find next available node number
                NEXT_NODE_NUM=1
                while [ -n "${EXISTING_NODE_IDS[peer-observer-node$(printf "%02d" $NEXT_NODE_NUM)]}" ]; do
                    NEXT_NODE_NUM=$((NEXT_NODE_NUM + 1))
                done

                # Create array of nodes to create
                for ((i=0; i<NUM_NODES; i++)); do
                    NODE_NAME="peer-observer-node$(printf "%02d" $((NEXT_NODE_NUM + i)))"
                    NODES_TO_CREATE+=("$NODE_NAME")

                    # Ask if pruned or full for each node
                    echo ""
                    echo "Configuration for $NODE_NAME:"
                    echo "  1) Full node (recommended: 1000GB)"
                    echo "  2) Pruned node (saves disk space)"
                    echo ""
                    read -p "Select option (1/2): " NODE_TYPE_OPTION

                    case "$NODE_TYPE_OPTION" in
                        1)
                            NODE_TYPES["$NODE_NAME"]="full"
                            ;;
                        2)
                            NODE_TYPES["$NODE_NAME"]="pruned"
                            ;;
                        *)
                            echo -e "${RED}✗ Invalid option${NC}"
                            exit 1
                            ;;
                    esac
                done

            else
                # No web exists, allow creating web or nodes
                echo "What would you like to add?"
                echo "  1) Web server (peer-observer-web01)"
                echo "  2) Bitcoin node(s)"
                echo "  3) Both web server and Bitcoin node(s)"
                echo ""
                read -p "Select option (1/2/3): " ADD_OPTION

                case "$ADD_OPTION" in
                    1)
                        CREATE_WEB=true
                        echo -e "${GREEN}Will create web server${NC}"
                        ;;
                    2)
                        # Ask how many nodes to add
                        read -p "How many Bitcoin nodes do you want to add? (1-10): " NUM_NODES

                        if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ] || [ "$NUM_NODES" -gt 10 ]; then
                            echo -e "${RED}✗ Invalid number. Please enter a number between 1 and 10.${NC}"
                            exit 1
                        fi

                        # Find next available node number
                        NEXT_NODE_NUM=1
                        while [ -n "${EXISTING_NODE_IDS[peer-observer-node$(printf "%02d" $NEXT_NODE_NUM)]}" ]; do
                            NEXT_NODE_NUM=$((NEXT_NODE_NUM + 1))
                        done

                        # Create array of nodes to create
                        for ((i=0; i<NUM_NODES; i++)); do
                            NODE_NAME="peer-observer-node$(printf "%02d" $((NEXT_NODE_NUM + i)))"
                            NODES_TO_CREATE+=("$NODE_NAME")

                            # Ask if pruned or full for each node
                            echo ""
                            echo "Configuration for $NODE_NAME:"
                            echo "  1) Full node (recommended: 1000GB)"
                            echo "  2) Pruned node (saves disk space)"
                            echo ""
                            read -p "Select option (1/2): " NODE_TYPE_OPTION

                            case "$NODE_TYPE_OPTION" in
                                1)
                                    NODE_TYPES["$NODE_NAME"]="full"
                                    ;;
                                2)
                                    NODE_TYPES["$NODE_NAME"]="pruned"
                                    ;;
                                *)
                                    echo -e "${RED}✗ Invalid option${NC}"
                                    exit 1
                                    ;;
                            esac
                        done
                        ;;
                    3)
                        CREATE_WEB=true

                        # Ask how many nodes to add
                        read -p "How many Bitcoin nodes do you want to add? (1-10): " NUM_NODES

                        if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ] || [ "$NUM_NODES" -gt 10 ]; then
                            echo -e "${RED}✗ Invalid number. Please enter a number between 1 and 10.${NC}"
                            exit 1
                        fi

                        # Find next available node number
                        NEXT_NODE_NUM=1
                        while [ -n "${EXISTING_NODE_IDS[peer-observer-node$(printf "%02d" $NEXT_NODE_NUM)]}" ]; do
                            NEXT_NODE_NUM=$((NEXT_NODE_NUM + 1))
                        done

                        # Create array of nodes to create
                        for ((i=0; i<NUM_NODES; i++)); do
                            NODE_NAME="peer-observer-node$(printf "%02d" $((NEXT_NODE_NUM + i)))"
                            NODES_TO_CREATE+=("$NODE_NAME")

                            # Ask if pruned or full for each node
                            echo ""
                            echo "Configuration for $NODE_NAME:"
                            echo "  1) Full node (recommended: 1000GB)"
                            echo "  2) Pruned node (saves disk space)"
                            echo ""
                            read -p "Select option (1/2): " NODE_TYPE_OPTION

                            case "$NODE_TYPE_OPTION" in
                                1)
                                    NODE_TYPES["$NODE_NAME"]="full"
                                    ;;
                                2)
                                    NODE_TYPES["$NODE_NAME"]="pruned"
                                    ;;
                                *)
                                    echo -e "${RED}✗ Invalid option${NC}"
                                    exit 1
                                    ;;
                            esac
                        done
                        ;;
                    *)
                        echo -e "${RED}✗ Invalid option${NC}"
                        exit 1
                        ;;
                esac
            fi
            ;;
        *)
            echo -e "${RED}✗ Invalid option${NC}"
            exit 1
            ;;
    esac
else
    # No infrastructure exists - initial creation
    echo "No existing infrastructure found. What would you like to create?"
    echo "  1) Complete infrastructure (web server + Bitcoin node)"
    echo "  2) Only web server (peer-observer-web01)"
    echo "  3) Only Bitcoin node(s)"
    echo ""
    read -p "Select option (1/2/3): " INITIAL_OPTION

    case "$INITIAL_OPTION" in
        1)
            CREATE_WEB=true
            NODES_TO_CREATE+=("peer-observer-node01")

            # Ask if pruned or full for node01
            echo ""
            echo "Configuration for peer-observer-node01:"
            echo "  1) Full node (recommended: 1000GB)"
            echo "  2) Pruned node (saves disk space)"
            echo ""
            read -p "Select option (1/2): " NODE_TYPE_OPTION

            case "$NODE_TYPE_OPTION" in
                1)
                    NODE_TYPES["peer-observer-node01"]="full"
                    ;;
                2)
                    NODE_TYPES["peer-observer-node01"]="pruned"
                    ;;
                *)
                    echo -e "${RED}✗ Invalid option${NC}"
                    exit 1
                    ;;
            esac
            ;;
        2)
            CREATE_WEB=true
            echo -e "${GREEN}Creating only web server...${NC}"
            ;;
        3)
            # Ask how many nodes
            read -p "How many Bitcoin nodes do you want to create? (1-10): " NUM_NODES

            if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ] || [ "$NUM_NODES" -gt 10 ]; then
                echo -e "${RED}✗ Invalid number. Please enter a number between 1 and 10.${NC}"
                exit 1
            fi

            # Create nodes starting from node01
            for ((i=0; i<NUM_NODES; i++)); do
                NODE_NAME="peer-observer-node$(printf "%02d" $((i + 1)))"
                NODES_TO_CREATE+=("$NODE_NAME")

                # Ask if pruned or full for each node
                echo ""
                echo "Configuration for $NODE_NAME:"
                echo "  1) Full node (recommended: 1000GB)"
                echo "  2) Pruned node (saves disk space)"
                echo ""
                read -p "Select option (1/2): " NODE_TYPE_OPTION

                case "$NODE_TYPE_OPTION" in
                    1)
                        NODE_TYPES["$NODE_NAME"]="full"
                        ;;
                    2)
                        NODE_TYPES["$NODE_NAME"]="pruned"
                        ;;
                    *)
                        echo -e "${RED}✗ Invalid option${NC}"
                        exit 1
                        ;;
                esac
            done
            ;;
        *)
            echo -e "${RED}✗ Invalid option${NC}"
            exit 1
            ;;
    esac
fi


echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 5: Creating EC2 instances${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

INSTANCES_TO_WAIT=""
declare -A NEW_NODE_INSTANCES=()
declare -A NEW_NODE_IPS=()
declare -A NEW_NODE_ALLOCS=()

# Load BTC_PRUNED_VOLUME_SIZE from aws-config.env if exists
if [ -f aws-config.env ]; then
    source aws-config.env
fi

# Skip creation if using existing instances
if [ "${SKIP_CREATION:-false}" = true ]; then
    echo -e "${GREEN}Using existing instances, skipping creation...${NC}"
else
    # Create nodes
    for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
        echo ""
        echo "Creating $NODE_NAME..."

        # Determine volume size based on node type (single disk for NixOS)
        if [ "${NODE_TYPES[$NODE_NAME]}" = "full" ]; then
            DISK_SIZE=1000
        else
            # Pruned node
            if [ -n "$BTC_PRUNED_VOLUME_SIZE" ]; then
                echo -e "${YELLOW}Using configured pruned volume size: ${BTC_PRUNED_VOLUME_SIZE}GB${NC}"
                DISK_SIZE=$BTC_PRUNED_VOLUME_SIZE
            else
                echo "No default pruned size configured."
                read -p "Enter disk size in GB for $NODE_NAME (recommended minimum: 50): " NEW_SIZE
                DISK_SIZE=${NEW_SIZE:-50}
                # Save for future nodes
                BTC_PRUNED_VOLUME_SIZE=$DISK_SIZE
            fi
        fi

        # Create the instance with single disk (NixOS installs everything on one disk)
        NODE_INSTANCE=$(aws ec2 run-instances \
            --region $AWS_REGION \
            --image-id $UBUNTU_AMI \
            --instance-type $INSTANCE_TYPE_NODE \
            --key-name $KEY_NAME \
            --security-group-ids $NODE_SG \
            --block-device-mappings "[
                {
                    \"DeviceName\":\"/dev/sda1\",
                    \"Ebs\":{
                        \"VolumeSize\":$DISK_SIZE,
                        \"VolumeType\":\"gp3\",
                        \"DeleteOnTermination\":true
                    }
                }
            ]" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NODE_NAME},{Key=Project,Value=peer-observer},{Key=NodeType,Value=${NODE_TYPES[$NODE_NAME]}}]" \
            --query 'Instances[0].InstanceId' \
            --output text)

        echo -e "${GREEN}✓ $NODE_NAME created: $NODE_INSTANCE (${NODE_TYPES[$NODE_NAME]} node, ${DISK_SIZE}GB)${NC}"
        NEW_NODE_INSTANCES["$NODE_NAME"]=$NODE_INSTANCE
        INSTANCES_TO_WAIT="$INSTANCES_TO_WAIT $NODE_INSTANCE"
    done

    # Create web01 if requested
    if [ "$CREATE_WEB" = true ]; then
        echo ""
        echo "Creating peer-observer-web01..."
        WEB_INSTANCE=$(aws ec2 run-instances \
            --region $AWS_REGION \
            --image-id $UBUNTU_AMI \
            --instance-type $INSTANCE_TYPE_WEB \
            --key-name $KEY_NAME \
            --security-group-ids $WEB_SG \
            --block-device-mappings "[
                {
                    \"DeviceName\":\"/dev/sda1\",
                    \"Ebs\":{
                        \"VolumeSize\":$WEB_VOLUME_SIZE,
                        \"VolumeType\":\"gp3\",
                        \"DeleteOnTermination\":true
                    }
                }
            ]" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=peer-observer-web01},{Key=Project,Value=peer-observer}]" \
            --query 'Instances[0].InstanceId' \
            --output text)

        echo -e "${GREEN}✓ Web01 created: $WEB_INSTANCE${NC}"
        INSTANCES_TO_WAIT="$INSTANCES_TO_WAIT $WEB_INSTANCE"
    fi

    if [ -n "$INSTANCES_TO_WAIT" ]; then
        echo ""
        echo "Waiting for instances to reach 'running' state..."
        aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCES_TO_WAIT
        echo -e "${GREEN}✓ Instances running${NC}"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 6: Allocating Elastic IPs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to find available Elastic IP or allocate a new one
find_or_allocate_eip() {
    local instance_name=$1

    # Search for available (unassociated) Elastic IPs
    echo "Searching for available Elastic IP for $instance_name..." >&2
    AVAILABLE_EIP=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[?AssociationId==`null`].AllocationId | [0]' \
        --output text 2>/dev/null)

    if [ "$AVAILABLE_EIP" != "None" ] && [ -n "$AVAILABLE_EIP" ]; then
        echo -e "${GREEN}✓ Found available Elastic IP (reusing): $AVAILABLE_EIP${NC}" >&2
        echo "$AVAILABLE_EIP"
    else
        echo "No available Elastic IPs found. Allocating new one for $instance_name..." >&2
        NEW_EIP=$(aws ec2 allocate-address --region $AWS_REGION --domain vpc --query 'AllocationId' --output text)
        echo -e "${GREEN}✓ New Elastic IP allocated: $NEW_EIP${NC}" >&2
        echo "$NEW_EIP"
    fi
}

# Allocate and associate Elastic IPs for new nodes
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    NODE_INSTANCE=${NEW_NODE_INSTANCES[$NODE_NAME]}
    ALLOC=$(find_or_allocate_eip "$NODE_NAME")
    aws ec2 associate-address --region $AWS_REGION --instance-id $NODE_INSTANCE --allocation-id $ALLOC > /dev/null
    IP=$(aws ec2 describe-addresses --region $AWS_REGION --allocation-ids $ALLOC --query 'Addresses[0].PublicIp' --output text)
    echo -e "${GREEN}✓ $NODE_NAME IP: $IP${NC}"

    NEW_NODE_IPS["$NODE_NAME"]=$IP
    NEW_NODE_ALLOCS["$NODE_NAME"]=$ALLOC
done

# Allocate and associate Elastic IP for web01 if created
if [ "$CREATE_WEB" = true ]; then
    WEB_ALLOC=$(find_or_allocate_eip "web01")
    aws ec2 associate-address --region $AWS_REGION --instance-id $WEB_INSTANCE --allocation-id $WEB_ALLOC > /dev/null
    WEB_IP=$(aws ec2 describe-addresses --region $AWS_REGION --allocation-ids $WEB_ALLOC --query 'Addresses[0].PublicIp' --output text)
    echo -e "${GREEN}✓ Web01 IP: $WEB_IP${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Infrastructure created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}Infrastructure summary:${NC}"
echo ""

# Show summary for new nodes
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    NODE_INSTANCE=${NEW_NODE_INSTANCES[$NODE_NAME]}
    IP=${NEW_NODE_IPS[$NODE_NAME]}
    NODE_TYPE=${NODE_TYPES[$NODE_NAME]}

    # Get disk size
    if [ "$NODE_TYPE" = "full" ]; then
        VOL_SIZE=1000
    else
        VOL_SIZE=${BTC_PRUNED_VOLUME_SIZE:-50}
    fi

    echo "  📦 $NODE_NAME (Bitcoin - $NODE_TYPE)"
    echo "     Instance ID: $NODE_INSTANCE"
    echo "     Public IP: $IP"
    echo "     Type: $INSTANCE_TYPE_NODE"
    echo "     Storage: ${VOL_SIZE}GB"
    echo ""
done

if [ "$CREATE_WEB" = true ]; then
    echo "  🌐 Web01 (Dashboard)"
    echo "     Instance ID: $WEB_INSTANCE"
    echo "     Public IP: $WEB_IP"
    echo "     Type: $INSTANCE_TYPE_WEB"
    echo "     Storage: ${WEB_VOLUME_SIZE}GB"
    echo ""
fi

# Save configuration file
# Load existing config if it exists
TEMP_CONFIG=$(mktemp)

# Start with header
cat > "$TEMP_CONFIG" << EOF
# AWS Infrastructure Configuration - Peer Observer
# This file is automatically generated by create-aws-infra.sh
# and read by manage-aws-instances.sh

# AWS Region
AWS_REGION=$AWS_REGION

# Key Pair
KEY_NAME=$KEY_NAME

# Security Groups
NODE_SECURITY_GROUP=$NODE_SG
WEB_SECURITY_GROUP=$WEB_SG

# Instance Types
NODE_INSTANCE_TYPE=$INSTANCE_TYPE_NODE
WEB_INSTANCE_TYPE=$INSTANCE_TYPE_WEB

# Bitcoin Node Configuration
BTC_PRUNED_VOLUME_SIZE=${BTC_PRUNED_VOLUME_SIZE:-50}

# All Nodes Configuration (array format)
EOF

# Get all existing and new nodes
ALL_NODES=()

# Add existing nodes from aws-config.env if it exists
if [ -f aws-config.env ]; then
    source aws-config.env 2>/dev/null
    # Parse existing node list if exists
    if [ -n "$ALL_NODE_NAMES" ]; then
        IFS=' ' read -ra EXISTING <<< "$ALL_NODE_NAMES"
        ALL_NODES+=("${EXISTING[@]}")
    fi
fi

# Add new nodes
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    if [[ ! " ${ALL_NODES[@]} " =~ " ${NODE_NAME} " ]]; then
        ALL_NODES+=("$NODE_NAME")
    fi
done

# Write all node names as space-separated list
echo "ALL_NODE_NAMES=\"${ALL_NODES[*]}\"" >> "$TEMP_CONFIG"
echo "" >> "$TEMP_CONFIG"

# Write configuration for each node
for NODE_NAME in "${ALL_NODES[@]}"; do
    echo "# $NODE_NAME" >> "$TEMP_CONFIG"

    # Check if this is a new node
    if [[ " ${NODES_TO_CREATE[@]} " =~ " ${NODE_NAME} " ]]; then
        # New node - get from NEW_NODE_ arrays
        INSTANCE=${NEW_NODE_INSTANCES[$NODE_NAME]}
        IP=${NEW_NODE_IPS[$NODE_NAME]}
        ALLOC=${NEW_NODE_ALLOCS[$NODE_NAME]}
        TYPE=${NODE_TYPES[$NODE_NAME]}
    else
        # Existing node - try to get from aws-config.env variables
        # Convert node name to variable suffix (e.g., peer-observer-node01 -> NODE01)
        VAR_SUFFIX=$(echo "$NODE_NAME" | sed 's/peer-observer-//; s/-//g' | tr '[:lower:]' '[:upper:]')

        # Try to get values from existing config
        INSTANCE_VAR="${VAR_SUFFIX}_INSTANCE_ID"
        IP_VAR="${VAR_SUFFIX}_IP"
        ALLOC_VAR="${VAR_SUFFIX}_EIP_ALLOCATION"
        TYPE_VAR="${VAR_SUFFIX}_NODE_TYPE"

        INSTANCE=${!INSTANCE_VAR:-}
        IP=${!IP_VAR:-}
        ALLOC=${!ALLOC_VAR:-}
        TYPE=${!TYPE_VAR:-full}
    fi

    # Convert node name to variable suffix for output
    VAR_SUFFIX=$(echo "$NODE_NAME" | sed 's/peer-observer-//; s/-//g' | tr '[:lower:]' '[:upper:]')

    cat >> "$TEMP_CONFIG" << EOF
${VAR_SUFFIX}_INSTANCE_ID=${INSTANCE}
${VAR_SUFFIX}_IP=${IP}
${VAR_SUFFIX}_EIP_ALLOCATION=${ALLOC}
${VAR_SUFFIX}_NODE_TYPE=${TYPE}

EOF
done

# Web server configuration
cat >> "$TEMP_CONFIG" << EOF
# Web01 - Dashboard & Monitoring
EOF

if [ "$CREATE_WEB" = true ]; then
    cat >> "$TEMP_CONFIG" << EOF
WEB_INSTANCE_ID=$WEB_INSTANCE
WEB_IP=$WEB_IP
WEB_EIP_ALLOCATION=$WEB_ALLOC
EOF
else
    # Keep existing web values if not creating
    if [ -f aws-config.env ]; then
        source aws-config.env 2>/dev/null
    fi
    cat >> "$TEMP_CONFIG" << EOF
WEB_INSTANCE_ID=${WEB_INSTANCE_ID:-}
WEB_IP=${WEB_IP:-}
WEB_EIP_ALLOCATION=${WEB_EIP_ALLOCATION:-}
EOF
fi

cat >> "$TEMP_CONFIG" << EOF

# Last update timestamp
LAST_UPDATE="$(date)"
EOF

# Move temp file to final location
mv "$TEMP_CONFIG" aws-config.env
echo -e "${GREEN}✓ Configuration saved to: aws-config.env${NC}"

# Save README for reference
cat > aws-infrastructure.txt << EOF
Peer Observer AWS Infrastructure
================================

Creation date: $(date)
Region: $AWS_REGION

EOF

# Add information for all nodes
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    NODE_INSTANCE=${NEW_NODE_INSTANCES[$NODE_NAME]}
    IP=${NEW_NODE_IPS[$NODE_NAME]}
    ALLOC=${NEW_NODE_ALLOCS[$NODE_NAME]}
    NODE_TYPE=${NODE_TYPES[$NODE_NAME]}

    cat >> aws-infrastructure.txt << EOF
$NODE_NAME (Bitcoin Observation Node - $NODE_TYPE)
$(printf '%.0s-' {1..50})
Instance ID: $NODE_INSTANCE
Public IP: $IP
Elastic IP Allocation: $ALLOC
Security Group: $NODE_SG
Instance Type: $INSTANCE_TYPE_NODE

EOF
done

if [ "$CREATE_WEB" = true ]; then
    cat >> aws-infrastructure.txt << EOF
Web01 (Dashboard & Monitoring)
-------------------------------
Instance ID: $WEB_INSTANCE
Public IP: $WEB_IP
Elastic IP Allocation: $WEB_ALLOC
Security Group: $WEB_SG
Instance Type: $INSTANCE_TYPE_WEB

EOF
fi

cat >> aws-infrastructure.txt << EOF
SSH Connection
--------------
EOF

for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    IP=${NEW_NODE_IPS[$NODE_NAME]}
    cat >> aws-infrastructure.txt << EOF
$NODE_NAME: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$IP
EOF
done

if [ "$CREATE_WEB" = true ]; then
    cat >> aws-infrastructure.txt << EOF
Web01:  ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$WEB_IP
EOF
fi

cat >> aws-infrastructure.txt << EOF

Instance Management
-------------------
Use ./manage-aws-instances.sh to start/stop instances:
  - ./manage-aws-instances.sh start   # Start instances
  - ./manage-aws-instances.sh stop    # Stop instances
  - ./manage-aws-instances.sh status  # Check status

Next Steps
----------
EOF

if [ "$CREATE_WEB" = true ]; then
    cat >> aws-infrastructure.txt << EOF
1. Configure your domain pointing to: $WEB_IP
EOF
fi

cat >> aws-infrastructure.txt << EOF
2. Update infra.nix with IPs and configuration
3. Deploy NixOS with nixos-anywhere
EOF

echo -e "${GREEN}✓ README saved to: aws-infrastructure.txt${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  NEXT STEPS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

STEP_NUM=1

if [ "$CREATE_WEB" = true ]; then
    echo -e "${STEP_NUM}. ${BLUE}Configure your DNS domain:${NC}"
    echo "   Point your domain to the webserver IP: $WEB_IP"
    echo "   Example: observer.hacknodes.com → $WEB_IP"
    echo ""
    STEP_NUM=$((STEP_NUM + 1))
fi

echo -e "${STEP_NUM}. ${BLUE}Verify SSH connectivity:${NC}"
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    IP=${NEW_NODE_IPS[$NODE_NAME]}
    echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$IP  # $NODE_NAME"
done
if [ "$CREATE_WEB" = true ]; then
    echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$WEB_IP  # web01"
fi
echo ""
STEP_NUM=$((STEP_NUM + 1))

echo -e "${STEP_NUM}. ${BLUE}Update infra.nix:${NC}"
echo "   - Confirm WireGuard public keys"
if [ "$CREATE_WEB" = true ]; then
    echo "   - Add your domain"
fi
echo "   - Update email for Let's Encrypt"
echo ""
STEP_NUM=$((STEP_NUM + 1))

echo -e "${STEP_NUM}. ${BLUE}Deploy NixOS with nixos-anywhere:${NC}"
for NODE_NAME in "${NODES_TO_CREATE[@]}"; do
    IP=${NEW_NODE_IPS[$NODE_NAME]}
    # Extract flake name (e.g., peer-observer-node01 -> node01)
    FLAKE_NAME=$(echo "$NODE_NAME" | sed 's/peer-observer-//')
    echo "   nix run github:nix-community/nixos-anywhere -- \\"
    echo "     --flake .#$FLAKE_NAME \\"
    echo "     --target-host root@$IP"
    echo ""
done
if [ "$CREATE_WEB" = true ]; then
    echo "   nix run github:nix-community/nixos-anywhere -- \\"
    echo "     --flake .#web01 \\"
    echo "     --target-host root@$WEB_IP"
    echo ""
fi
echo -e "${GREEN}Ready to deploy! 🚀${NC}"
