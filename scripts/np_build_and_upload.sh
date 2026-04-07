#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

# Workspace (Tekton runs inside this path)
WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

# Generate build number (Tekton doesn't have CI_PIPELINE_IID)
BUILD_NUMBER=$(date +%s)
echo "BUILD_NUMBER=$BUILD_NUMBER" > .env

# Project name (can also pass as param)
CI_PROJECT_NAME="ace-app"

echo "Build Number: $BUILD_NUMBER"

# -------------------------------
# 🔍 Detect changed files
# -------------------------------
echo "Detecting changed files..."

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | \
  awk '!/^\.(gitlab-ci|gitlab-cd|gitlab-prod-cd|gitlab-dr-cd)\.yml$/')

echo "$CHANGED_FILES"

# Extract services
echo "$CHANGED_FILES" | awk -F'/' '{print $1}' | sort | uniq > .changed_services

echo "Changed services:"
cat .changed_services || true

# Exit if no changes
if [ ! -s .changed_services ]; then
  echo "No changes detected. Exiting build."
  exit 0
fi

# -------------------------------
# 📦 Prepare BAR folder
# -------------------------------
mkdir -p bar

# Timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "TIMESTAMP=$TIMESTAMP" >> .env

# -------------------------------
# 🔨 Build BAR files
# -------------------------------
echo "===== BUILDING BAR FILES ====="

while read service; do

  echo "-----------------------------------"
  echo "Processing service: $service"

  # Skip libraries (optional logic)
  if [[ "$service" == "CommonLibrary" || "$service" == "Exception_Handler" ]]; then
    echo "Skipping standalone BAR for library: $service"
    continue
  fi

  echo "Building BAR for $service..."

  ibmint package \
    --input-path . \
    --output-bar-file bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar

  BAR_FILE="bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  echo "BAR created: $BAR_FILE"

  # -------------------------------
  # 📤 Upload to Nexus
  # -------------------------------
  echo "Uploading $service to Nexus..."

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  echo "Uploading latest-$TIMESTAMP..."

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-latest-${TIMESTAMP}.bar"

  echo "Uploading latest..."

  curl -v -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "$NEXUS_REPOSITORY/${CI_PROJECT_NAME}-${service}-latest.bar"

done < .changed_services

echo "===== BUILD COMPLETED ====="

# Show generated files
ls -l bar/

# Save artifacts (used by deploy step)
cp .env "$WORKSPACE" || true
cp .changed_services "$WORKSPACE" || true