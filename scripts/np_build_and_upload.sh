#!/bin/bash
set -e

echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "BUILD_NUMBER=$BUILD_NUMBER" > .env
echo "TIMESTAMP=$TIMESTAMP" >> .env

CI_PROJECT_NAME="ace-pipeline"

echo "Build Number: $BUILD_NUMBER"

# -------------------------------
# 🔧 Git configuration
# -------------------------------
echo "Configuring git..."

# Disable SSL verification only for CI/internal runners
git config --global http.sslVerify false || true

# -------------------------------
# 🔧 Ensure full git history
# -------------------------------
echo "Fetching full git history..."

if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  git fetch --unshallow || true
fi

git fetch --all || true

# -------------------------------
# 🔍 Detect changed files
# -------------------------------
echo "Detecting changed files..."

if git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
else
  echo "No previous commit found, using full repo"
  CHANGED_FILES=$(git ls-files)
fi

echo "All changed files:"
echo "$CHANGED_FILES"

# -------------------------------
# 🎯 Extract changed applications
# -------------------------------
echo "$CHANGED_FILES" \
  | grep '^applications/' \
  | awk -F'/' 'NF>1 {print $2}' \
  | sort -u \
  | grep -v '^$' > .changed_services

echo "Filtered changed services:"
cat .changed_services || true

# -------------------------------
# ❌ Exit if no changes
# -------------------------------
if ! grep -q '[^[:space:]]' .changed_services; then
  echo "No application changes detected. Skipping build."
  exit 0
fi

echo "Detected services:"
while read -r service; do
  [ -z "$service" ] && continue
  echo "→ $service"
done < .changed_services

# -------------------------------
# 📦 Prepare BAR folder
# -------------------------------
mkdir -p bar

# -------------------------------
# 🔨 Build BAR files
# -------------------------------
echo "===== BUILDING BAR FILES ====="

while read -r service; do

  [ -z "$service" ] && continue

  echo "-----------------------------------"
  echo "Processing service: $service"

  if [ ! -d "applications/$service" ]; then
    echo "Skipping: applications/$service not found"
    continue
  fi

  echo "Building BAR for $service..."

  # =========================================================
  # IMPORTANT:
  # --input-path should point to workspace containing projects
  # --project should be ONLY the ACE project name
  # =========================================================

  ibmint package \
    --input-path applications \
    --project "$service" \
    --output-bar-file "bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  BAR_FILE="bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  # -------------------------------
  # ✅ Validate BAR creation
  # -------------------------------
  if [ ! -f "$BAR_FILE" ]; then
    echo "ERROR: BAR file not created for $service"
    exit 1
  fi

  echo "BAR created successfully:"
  ls -lh "$BAR_FILE"

  # -------------------------------
  # 📤 Upload to Nexus
  # -------------------------------
  echo "Uploading $service BAR to Nexus..."

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${service}-latest-${TIMESTAMP}.bar"

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$BAR_FILE" \
    "${NEXUS_REPOSITORY}/${CI_PROJECT_NAME}-${service}-latest.bar"

  echo "Upload completed for $service"

done < .changed_services

# -------------------------------
# ✅ Build completed
# -------------------------------
echo "===== BUILD COMPLETED ====="

echo "Generated BAR files:"
ls -lh bar/

# -------------------------------
# 📄 Persist artifacts
# -------------------------------
cp .env "$WORKSPACE/" || true
cp .changed_services "$WORKSPACE/" || true

echo "===== SCRIPT FINISHED SUCCESSFULLY ====="
