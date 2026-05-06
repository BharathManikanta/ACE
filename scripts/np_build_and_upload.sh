#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)

echo "Workspace: $WORKSPACE"

# =====================================================
# CREATE .changed_services FILE
# =====================================================

echo "Creating changed services file..."

echo "CommitRestAPI" > .changed_services

echo "Contents of .changed_services:"

cat .changed_services

# =====================================================
# FORCE BUILD FAILURE
# =====================================================

echo "===== TESTING FAILED PIPELINE STATUS ====="

echo "Build failed intentionally for testing..."

# IMPORTANT
# This makes Tekton pipeline status = Failed

exit 1
