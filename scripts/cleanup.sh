#!/bin/bash
# cleanup.sh - FinOps teardown for the EEI6369 AWS lab (521429610)
# Run in AWS CloudShell (region ap-southeast-2):  bash cleanup.sh | tee cleanup-log.txt
# Edit the names below if yours are different.
export AWS_REGION=ap-southeast-2
VPC_NAME="521429610-lab-vpc"
RDS_ID="student-db"
DB_SUBNET_GROUP="lab-db-subnet-group"
DB_PARAM_GROUP="lab-pg16-ssl"
ECR_REPO="student-api"
KEY_NAME="lab-key"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$VPC_NAME --query 'Vpcs[0].VpcId' --output text)
echo "Target VPC: $VPC_NAME ($VPC_ID)"

echo "[1] Deleting RDS instance $RDS_ID (no final snapshot)..."
aws rds delete-db-instance --db-instance-identifier $RDS_ID --skip-final-snapshot --delete-automated-backups
aws rds wait db-instance-deleted --db-instance-identifier $RDS_ID

echo "[2] Terminating EC2 instances in the VPC..."
IDS=$(aws ec2 describe-instances --filters Name=vpc-id,Values=$VPC_ID \
  Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then
  aws ec2 terminate-instances --instance-ids $IDS
  aws ec2 wait instance-terminated --instance-ids $IDS
fi
sleep 60   # give AWS time to release network interfaces

echo "[3] Deleting DB subnet group and parameter group..."
aws rds delete-db-subnet-group --db-subnet-group-name $DB_SUBNET_GROUP
aws rds delete-db-parameter-group --db-parameter-group-name $DB_PARAM_GROUP

echo "[4] Deleting ECR repository and all images..."
aws ecr delete-repository --repository-name $ECR_REPO --force

echo "[5] Deleting security groups (rules first, then groups)..."
SGS=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID \
  --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
for SG in $SGS; do
  RULES=$(aws ec2 describe-security-group-rules --filters Name=group-id,Values=$SG \
    --query 'SecurityGroupRules[?IsEgress==`false`].SecurityGroupRuleId' --output text)
  [ -n "$RULES" ] && aws ec2 revoke-security-group-ingress --group-id $SG --security-group-rule-ids $RULES >/dev/null
done
for SG in $SGS; do
  aws ec2 delete-security-group --group-id $SG && echo "  deleted $SG"
done

echo "[6] Deleting subnets..."
for S in $(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[].SubnetId' --output text); do
  aws ec2 delete-subnet --subnet-id $S && echo "  deleted $S"
done

echo "[7] Deleting custom route tables..."
MAIN_RT=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
  --query 'RouteTables[0].RouteTableId' --output text)
for RT in $(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID --query 'RouteTables[].RouteTableId' --output text); do
  if [ "$RT" != "$MAIN_RT" ]; then aws ec2 delete-route-table --route-table-id $RT && echo "  deleted $RT"; fi
done

echo "[8] Detaching and deleting the internet gateway..."
IGW=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC_ID \
  --query 'InternetGateways[0].InternetGatewayId' --output text)
aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW

echo "[9] Deleting the VPC and key pair..."
aws ec2 delete-vpc --vpc-id $VPC_ID
aws ec2 delete-key-pair --key-name $KEY_NAME

echo "[10] Verification - all lists below should be empty:"
echo "RDS:";  aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text
echo "EC2:";  aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].InstanceId' --output text
echo "VPC:";  aws ec2 describe-vpcs --filters Name=tag:Name,Values=$VPC_NAME --query 'Vpcs[].VpcId' --output text
echo "ECR:";  aws ecr describe-repositories --query 'repositories[].repositoryName' --output text
echo "Teardown complete."
