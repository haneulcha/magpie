#!/bin/sh
# 개발 중 서명이 바뀌면 손쉬운 사용 권한이 조용히 죽는다(증상: 이벤트가 안 잡힘).
# 이 스크립트로 리셋하고 앱을 다시 실행해 허용하면 된다.
set -e
BUNDLE_ID="${1:-com.haneul.Magpie}"
tccutil reset Accessibility "$BUNDLE_ID"
echo "reset Accessibility for $BUNDLE_ID — 앱을 다시 실행해 허용하세요."
