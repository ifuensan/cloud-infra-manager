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

# List existing key pairs
echo "Checking for existing key pairs in AWS..."
EXISTING_KEYS=$(aws ec2 describe-key-pairs --region $AWS_REGION --query 'KeyPairs[*].KeyName' --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_KEYS" ]; then
    echo -e "${GREEN}Found existing key pairs:${NC}"
    echo "$EXISTING_KEYS" | tr '\t' '\n' | nl
    echo ""
fi

# Ask user preference
echo "What would you like to do?"
echo "  1) Use an existing key pair"
echo "  2) Create a new key pair"
echo ""
read -p "Select option (1/2): " KEY_OPTION

case "$KEY_OPTION" in
    1)
        if [ -z "$EXISTING_KEYS" ]; then
            echo -e "${RED}✗ No existing key pairs found${NC}"
            echo "Creating a new one..."
            KEY_OPTION=2
        else
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

EXISTING_NODE=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=peer-observer-node01" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)

EXISTING_WEB=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=peer-observer-web01" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)

NODE_EXISTS=false
WEB_EXISTS=false

if [ "$EXISTING_NODE" != "None" ] && [ -n "$EXISTING_NODE" ]; then
    NODE_EXISTS=true
    NODE_STATE=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $EXISTING_NODE \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    echo -e "${YELLOW}✓ Found existing node01: $EXISTING_NODE (state: $NODE_STATE)${NC}"
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

if [ "$NODE_EXISTS" = false ] && [ "$WEB_EXISTS" = false ]; then
    echo "No existing instances found."
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 4: Instance Selection${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CREATE_NODE=false
CREATE_WEB=false

# If both exist, ask if user wants to skip or recreate
if [ "$NODE_EXISTS" = true ] && [ "$WEB_EXISTS" = true ]; then
    echo -e "${YELLOW}Both instances already exist!${NC}"
    echo ""
    echo "What would you like to do?"
    echo "  1) Skip creation (use existing instances)"
    echo "  2) Create new instances (you'll need to terminate existing ones first)"
    echo ""
    read -p "Select option (1/2): " EXISTING_OPTION

    case "$EXISTING_OPTION" in
        1)
            echo -e "${GREEN}Using existing instances...${NC}"
            # Load existing data and skip creation
            NODE_INSTANCE=$EXISTING_NODE
            WEB_INSTANCE=$EXISTING_WEB
            SKIP_CREATION=true
            ;;
        2)
            echo -e "${RED}✗ Please terminate existing instances first using manage-aws-instances.sh destroy${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}✗ Invalid option${NC}"
            exit 1
            ;;
    esac
# If only node exists
elif [ "$NODE_EXISTS" = true ] && [ "$WEB_EXISTS" = false ]; then
    echo -e "${YELLOW}Node01 already exists: $EXISTING_NODE${NC}"
    echo ""
    read -p "Do you want to create web01? (yes/no): " CREATE_WEB_ANSWER

    if [ "$CREATE_WEB_ANSWER" = "yes" ]; then
        CREATE_WEB=true
        NODE_INSTANCE=$EXISTING_NODE
        echo -e "${GREEN}Will create web01 and use existing node01${NC}"
    else
        echo -e "${GREEN}Using existing node01 only${NC}"
        NODE_INSTANCE=$EXISTING_NODE
        SKIP_CREATION=true
    fi
# If only web exists
elif [ "$NODE_EXISTS" = false ] && [ "$WEB_EXISTS" = true ]; then
    echo -e "${YELLOW}Web01 already exists: $EXISTING_WEB${NC}"
    echo ""
    read -p "Do you want to create node01? (yes/no): " CREATE_NODE_ANSWER

    if [ "$CREATE_NODE_ANSWER" = "yes" ]; then
        CREATE_NODE=true
        WEB_INSTANCE=$EXISTING_WEB
        echo -e "${GREEN}Will create node01 and use existing web01${NC}"
    else
        echo -e "${GREEN}Using existing web01 only${NC}"
        WEB_INSTANCE=$EXISTING_WEB
        SKIP_CREATION=true
    fi
# If neither exists
else
    echo "Which instances do you want to create?"
    echo "  1) Both instances (node01 + web01)"
    echo "  2) Only node instance (peer-observer-node01)"
    echo "  3) Only web instance (peer-observer-web01)"
    echo ""
    read -p "Select option (1/2/3): " INSTANCE_OPTION

    case "$INSTANCE_OPTION" in
        1)
            CREATE_NODE=true
            CREATE_WEB=true
            echo -e "${GREEN}Creating both instances...${NC}"
            ;;
        2)
            CREATE_NODE=true
            echo -e "${GREEN}Creating only node instance...${NC}"
            ;;
        3)
            CREATE_WEB=true
            echo -e "${GREEN}Creating only web instance...${NC}"
            ;;
        *)
            echo -e "${RED}✗ Invalid option${NC}"
            exit 1
            ;;
    esac
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 5: Creating EC2 instances${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

INSTANCES_TO_WAIT=""

# Skip creation if using existing instances
if [ "${SKIP_CREATION:-false}" = true ]; then
    echo -e "${GREEN}Using existing instances, skipping creation...${NC}"

    # Get data from existing instances for config file
    if [ -n "$NODE_INSTANCE" ]; then
        NODE_IP=$(aws ec2 describe-instances \
            --region $AWS_REGION \
            --instance-ids $NODE_INSTANCE \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        # Get Elastic IP allocation if exists
        NODE_ALLOC=$(aws ec2 describe-addresses \
            --region $AWS_REGION \
            --filters "Name=instance-id,Values=$NODE_INSTANCE" \
            --query 'Addresses[0].AllocationId' \
            --output text 2>/dev/null)

        if [ "$NODE_ALLOC" = "None" ] || [ -z "$NODE_ALLOC" ]; then
            NODE_ALLOC=""
        fi
    fi

    if [ -n "$WEB_INSTANCE" ]; then
        WEB_IP=$(aws ec2 describe-instances \
            --region $AWS_REGION \
            --instance-ids $WEB_INSTANCE \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        # Get Elastic IP allocation if exists
        WEB_ALLOC=$(aws ec2 describe-addresses \
            --region $AWS_REGION \
            --filters "Name=instance-id,Values=$WEB_INSTANCE" \
            --query 'Addresses[0].AllocationId' \
            --output text 2>/dev/null)

        if [ "$WEB_ALLOC" = "None" ] || [ -z "$WEB_ALLOC" ]; then
            WEB_ALLOC=""
        fi
    fi
else
    # Create node01 if requested
    if [ "$CREATE_NODE" = true ]; then
    echo "Creating peer-observer-node01..."
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
                    \"VolumeSize\":50,
                    \"VolumeType\":\"gp3\",
                    \"DeleteOnTermination\":true
                }
            },
            {
                \"DeviceName\":\"/dev/sdf\",
                \"Ebs\":{
                    \"VolumeSize\":$BITCOIN_VOLUME_SIZE,
                    \"VolumeType\":\"gp3\",
                    \"DeleteOnTermination\":false
                }
            }
        ]" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=peer-observer-node01},{Key=Project,Value=peer-observer}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo -e "${GREEN}✓ Node01 created: $NODE_INSTANCE${NC}"
    INSTANCES_TO_WAIT="$NODE_INSTANCE"
fi

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

# Allocate and associate Elastic IP for node01 if created
if [ "$CREATE_NODE" = true ]; then
    echo "Allocating Elastic IP for node01..."
    NODE_ALLOC=$(aws ec2 allocate-address --region $AWS_REGION --domain vpc --query 'AllocationId' --output text)
    aws ec2 associate-address --region $AWS_REGION --instance-id $NODE_INSTANCE --allocation-id $NODE_ALLOC > /dev/null
    NODE_IP=$(aws ec2 describe-addresses --region $AWS_REGION --allocation-ids $NODE_ALLOC --query 'Addresses[0].PublicIp' --output text)
    echo -e "${GREEN}✓ Node01 IP: $NODE_IP${NC}"
# Get existing node01 data if not creating it
elif [ -n "$NODE_INSTANCE" ]; then
    echo "Getting data from existing node01..."
    NODE_IP=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $NODE_INSTANCE \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    NODE_ALLOC=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=instance-id,Values=$NODE_INSTANCE" \
        --query 'Addresses[0].AllocationId' \
        --output text 2>/dev/null)

    if [ "$NODE_ALLOC" = "None" ] || [ -z "$NODE_ALLOC" ]; then
        NODE_ALLOC=""
    fi

    echo -e "${GREEN}✓ Node01 IP: $NODE_IP${NC}"
fi

# Allocate and associate Elastic IP for web01 if created
if [ "$CREATE_WEB" = true ]; then
    echo "Allocating Elastic IP for web01..."
    WEB_ALLOC=$(aws ec2 allocate-address --region $AWS_REGION --domain vpc --query 'AllocationId' --output text)
    aws ec2 associate-address --region $AWS_REGION --instance-id $WEB_INSTANCE --allocation-id $WEB_ALLOC > /dev/null
    WEB_IP=$(aws ec2 describe-addresses --region $AWS_REGION --allocation-ids $WEB_ALLOC --query 'Addresses[0].PublicIp' --output text)
    echo -e "${GREEN}✓ Web01 IP: $WEB_IP${NC}"
# Get existing web01 data if not creating it
elif [ -n "$WEB_INSTANCE" ]; then
    echo "Getting data from existing web01..."
    WEB_IP=$(aws ec2 describe-instances \
        --region $AWS_REGION \
        --instance-ids $WEB_INSTANCE \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    WEB_ALLOC=$(aws ec2 describe-addresses \
        --region $AWS_REGION \
        --filters "Name=instance-id,Values=$WEB_INSTANCE" \
        --query 'Addresses[0].AllocationId' \
        --output text 2>/dev/null)

    if [ "$WEB_ALLOC" = "None" ] || [ -z "$WEB_ALLOC" ]; then
        WEB_ALLOC=""
    fi

    echo -e "${GREEN}✓ Web01 IP: $WEB_IP${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Infrastructure created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}Infrastructure summary:${NC}"
echo ""

if [ "$CREATE_NODE" = true ]; then
    echo "  📦 Node01 (Bitcoin)"
    echo "     Instance ID: $NODE_INSTANCE"
    echo "     Public IP: $NODE_IP"
    echo "     Type: $INSTANCE_TYPE_NODE"
    echo "     Storage: 50GB (OS) + ${BITCOIN_VOLUME_SIZE}GB (Bitcoin)"
    echo ""
fi

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
if [ -f aws-config.env ]; then
    source aws-config.env
fi

cat > aws-config.env << EOF
# AWS Infrastructure Configuration - Peer Observer
# This file is automatically generated by create-aws-infra.sh
# and read by manage-aws-instances.sh

# AWS Region
AWS_REGION=$AWS_REGION

# Key Pair
KEY_NAME=$KEY_NAME

# Node01 - Bitcoin Observation Node
EOF

if [ "$CREATE_NODE" = true ]; then
    cat >> aws-config.env << EOF
NODE_INSTANCE_ID=$NODE_INSTANCE
NODE_IP=$NODE_IP
NODE_EIP_ALLOCATION=$NODE_ALLOC
NODE_SECURITY_GROUP=$NODE_SG
NODE_INSTANCE_TYPE=$INSTANCE_TYPE_NODE
EOF
else
    # Keep existing node values if not creating
    cat >> aws-config.env << EOF
NODE_INSTANCE_ID=${NODE_INSTANCE_ID:-}
NODE_IP=${NODE_IP:-}
NODE_EIP_ALLOCATION=${NODE_EIP_ALLOCATION:-}
NODE_SECURITY_GROUP=${NODE_SECURITY_GROUP:-$NODE_SG}
NODE_INSTANCE_TYPE=${NODE_INSTANCE_TYPE:-$INSTANCE_TYPE_NODE}
EOF
fi

cat >> aws-config.env << EOF

# Web01 - Dashboard & Monitoring
EOF

if [ "$CREATE_WEB" = true ]; then
    cat >> aws-config.env << EOF
WEB_INSTANCE_ID=$WEB_INSTANCE
WEB_IP=$WEB_IP
WEB_EIP_ALLOCATION=$WEB_ALLOC
WEB_SECURITY_GROUP=$WEB_SG
WEB_INSTANCE_TYPE=$INSTANCE_TYPE_WEB
EOF
else
    # Keep existing web values if not creating
    cat >> aws-config.env << EOF
WEB_INSTANCE_ID=${WEB_INSTANCE_ID:-}
WEB_IP=${WEB_IP:-}
WEB_EIP_ALLOCATION=${WEB_EIP_ALLOCATION:-}
WEB_SECURITY_GROUP=${WEB_SECURITY_GROUP:-$WEB_SG}
WEB_INSTANCE_TYPE=${WEB_INSTANCE_TYPE:-$INSTANCE_TYPE_WEB}
EOF
fi

cat >> aws-config.env << EOF

# Last update timestamp
LAST_UPDATE="$(date)"
EOF

echo -e "${GREEN}✓ Configuration saved to: aws-config.env${NC}"

# Save README for reference
cat > aws-infrastructure.txt << EOF
Peer Observer AWS Infrastructure
================================

Creation date: $(date)
Region: $AWS_REGION

EOF

if [ "$CREATE_NODE" = true ]; then
    cat >> aws-infrastructure.txt << EOF
Node01 (Bitcoin Observation Node)
---------------------------------
Instance ID: $NODE_INSTANCE
Public IP: $NODE_IP
Elastic IP Allocation: $NODE_ALLOC
Security Group: $NODE_SG
Instance Type: $INSTANCE_TYPE_NODE

EOF
fi

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

if [ "$CREATE_NODE" = true ]; then
    cat >> aws-infrastructure.txt << EOF
Node01: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$NODE_IP
EOF
fi

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
if [ "$CREATE_NODE" = true ]; then
    echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$NODE_IP"
fi
if [ "$CREATE_WEB" = true ]; then
    echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$WEB_IP"
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
if [ "$CREATE_NODE" = true ]; then
    echo "   nix run github:nix-community/nixos-anywhere -- \\"
    echo "     --flake .#node01 \\"
    echo "     --target-host root@$NODE_IP"
    echo ""
fi
if [ "$CREATE_WEB" = true ]; then
    echo "   nix run github:nix-community/nixos-anywhere -- \\"
    echo "     --flake .#web01 \\"
    echo "     --target-host root@$WEB_IP"
    echo ""
fi
echo -e "${GREEN}Ready to deploy! 🚀${NC}"
