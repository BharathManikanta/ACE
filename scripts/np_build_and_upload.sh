#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
echo "BUILD_NUMBER=$BUILD_NUMBER" > .env

CI_PROJECT_NAME="ace-app"

echo "Build Number: $BUILD_NUMBER"

# -------------------------------
# 🔍 Detect changed files
# -------------------------------
echo "Detecting changed files..."

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)

echo "All changed files:"
echo "$CHANGED_FILES"

# ✅ Extract ONLY applications/<service>
echo "$CHANGED_FILES" | grep '^applications/' | awk -F'/' '{print $2}' | sort | uniq > .changed_services

echo "Filtered changed services:"
cat .changed_services || true

# ✅ Exit if no application changes
if [ ! -s .changed_services ]; then
  echo "No application changes detected. Skipping build."
  exit 0
fi

# -------------------------------
# 📦 Prepare BAR folder
# -------------------------------
mkdir -p bar

TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "TIMESTAMP=$TIMESTAMP" >> .env

# -------------------------------
# 🔨 Build BAR files
# -------------------------------
echo "===== BUILDING BAR FILES ====="

while read service; do

  # skip empty lines
  [ -z "$service" ] && continue

  echo "-----------------------------------"
  echo "Processing service: $service"

  echo "Building BAR for $service..."

  ibmint package \
    --input-path . \
    --project applications/$service \
    --output-bar-file bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar

  BAR_FILE="bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  # ✅ Check BAR exists before upload
  if [ ! -f "$BAR_FILE" ]; then
    echo "ERROR: BAR file not created for $service"
    exit 1
  fi

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

ls -l bar/

cp .env "$WORKSPACE" || true
cp .changed_services "$WORKSPACE" || true
