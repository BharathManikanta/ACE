#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

# =====================================================
# TEST FAILURE SCENARIO
# =====================================================

echo "===== TESTING FAILED PIPELINE STATUS ====="

echo "Forcing build failure intentionally..."

exit 1

# =====================================================
# ORIGINAL BUILD LOGIC BELOW
# =====================================================

WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "BUILD_NUMBER=$BUILD_NUMBER" > .env
echo "TIMESTAMP=$TIMESTAMP" >> .env

CI_PROJECT_NAME="ace-app"

echo "Build Number: $BUILD_NUMBER"

mkdir -p bar

echo "===== BUILD COMPLETED ====="
