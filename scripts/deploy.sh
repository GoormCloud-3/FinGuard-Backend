#!/bin/bash
set -e

# 항상 루트에서 실행되도록 이동
cd "$(dirname "$0")/.." || exit 1

source ./scripts/env.sh

echo "배포할 거면 y를 입력하세요"
read -r answer

if [[ "$answer" == "y" ]]; then
	sls deploy --stage "$ENV"
else
	echo "🚫 배포를 취소합니다."
fi
