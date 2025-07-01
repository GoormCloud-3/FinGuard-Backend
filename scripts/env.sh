#!/bin/bash
set -e

cd "$(dirname "$0")/.." || exit 1

echo "개발 환경을 입력해주세요. (예: dev, prod, stage)"
read -r ENV

export ENV

# 🔐 Security Groups
export SG_DAO=$(
	aws ec2 describe-security-groups \
		--filters Name=group-name,Values="finguard-${ENV}-backend" Name=tag:Env,Values="${ENV}" \
		--query 'SecurityGroups[*].GroupId' \
		--output text
)

export SG_ALERT=$(
	aws ec2 describe-security-groups \
		--filters Name=group-name,Values="finguard-${ENV}-notification-sender" Name=tag:Env,Values="${ENV}" \
		--query 'SecurityGroups[*].GroupId' \
		--output text
)

# 🌐 Subnets
read -a PRIVATE_SUBNETS <<<"$(
	aws ec2 describe-subnets \
		--filters "Name=tag:Name,Values=finguard-${ENV}-lambda-*" \
		--query "Subnets[*].SubnetId" \
		--output text
)"
export PRIVATE_SUBNET_1="${PRIVATE_SUBNETS[0]}"
export PRIVATE_SUBNET_2="${PRIVATE_SUBNETS[1]}"

# 🔧 Lambda IAM Roles
export API_LAMBDA_ROLE_ARN=$(
	aws iam get-role \
		--role-name "finguard-${ENV}-backend" \
		--query 'Role.Arn' \
		--output text
)

export SQS_LAMBDA_ROLE_ARN=$(
	aws iam get-role \
		--role-name "finguard-${ENV}-fraud-checker" \
		--query 'Role.Arn' \
		--output text
)

# 📬 SQS ARN
export SQS_URL=$(
	aws sqs list-queues \
		--query "QueueUrls[?contains(@, 'finguard-${ENV}-trade-queue')]" \
		--output text
)

export SQS_ARN=$(
	aws sqs get-queue-attributes \
		--queue-url "$SQS_URL" \
		--attribute-names QueueArn \
		--query "Attributes.QueueArn" \
		--output text
)

# 출력
echo "✔ SG_DAO:              $SG_DAO"
echo "✔ SG_ALERT:            $SG_ALERT"
echo "✔ PRIVATE_SUBNET_1:    $PRIVATE_SUBNET_1"
echo "✔ PRIVATE_SUBNET_2:    $PRIVATE_SUBNET_2"
echo "✔ API_LAMBDA_ROLE_ARN: $API_LAMBDA_ROLE_ARN"
echo "✔ SQS_LAMBDA_ROLE_ARN: $SQS_LAMBDA_ROLE_ARN"
echo "✔ SQS_ARN:             $SQS_ARN"

# 🚫 유효성 검사
if [[ -z "$SG_DAO" || -z "$SG_ALERT" || -z "$PRIVATE_SUBNET_1" || -z "$PRIVATE_SUBNET_2" || -z "$API_LAMBDA_ROLE_ARN" || -z "$SQS_LAMBDA_ROLE_ARN" || -z "$SQS_ARN" ]]; then
	echo "❌ 에러: 필수 환경 변수 중 하나 이상이 비어 있습니다." >&2
	exit 1
fi
