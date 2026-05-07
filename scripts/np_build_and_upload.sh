echo "===== ACE BUILD STARTED ====="

WORKSPACE=$(pwd)

echo "Workspace: $WORKSPACE"

BUILD_NUMBER=$(date +%s)
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "BUILD_NUMBER=$BUILD_NUMBER" > .env
echo "TIMESTAMP=$TIMESTAMP" >> .env

CI_PROJECT_NAME="ace-app"

echo "Build Number: $BUILD_NUMBER"

# =====================================================
# Git Configuration
# =====================================================

echo "Configuring git..."

git config --global http.sslVerify false || true

# =====================================================
# Detect Changed Files
# ORIGINAL BUILD LOGIC BELOW
# =====================================================

echo "Detecting changed files..."

if git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
else
  echo "No previous commit found, using full repo"
  CHANGED_FILES=$(git ls-files)
fi

echo "All changed files:"
echo "$CHANGED_FILES"

# =====================================================
# Detect Changed Applications & Libraries
# =====================================================

echo "Detecting changed applications/libraries..."

echo "$CHANGED_FILES" \
  | grep -E '^(applications|libraries)/' \
  | awk -F'/' 'NF>1 {print $2}' \
  | sort -u \
  | grep -v '^$' > .changed_services

echo "Detected components:"
cat .changed_services || true

# =====================================================
# Exit if No Relevant Changes
# =====================================================

if ! grep -q '[^[:space:]]' .changed_services; then
  echo "No application/library changes detected."
  exit 0
fi

# =====================================================
# Display Detected Components
# =====================================================

echo "Detected services/libraries:"

while read -r service; do
WORKSPACE=$(pwd)
echo "Workspace: $WORKSPACE"

  [ -z "$service" ] && continue
BUILD_NUMBER=$(date +%s)
TIMESTAMP=$(date +%Y%m%d%H%M%S)

  echo "→ $service"
echo "BUILD_NUMBER=$BUILD_NUMBER" > .env
echo "TIMESTAMP=$TIMESTAMP" >> .env

done < .changed_services
CI_PROJECT_NAME="ace-app"

# =====================================================
# Prepare BAR Folder
# =====================================================
echo "Build Number: $BUILD_NUMBER"

mkdir -p bar

# =====================================================
# Build BAR Files
# =====================================================

echo "===== BUILDING BAR FILES ====="

while read -r service; do

  [ -z "$service" ] && continue

  echo "-----------------------------------"
  echo "Processing component: $service"

  # ===================================================
  # Skip if application folder does not exist
  # ===================================================

  if [ ! -d "applications/$service" ]; then
    echo "Skipping non-application component: $service"
    continue
  fi

  echo "Building BAR for $service..."

  VERSION_BAR="bar/${CI_PROJECT_NAME}-${service}-v${BUILD_NUMBER}.bar"
  TIMESTAMP_BAR="bar/${CI_PROJECT_NAME}-${service}-latest-${TIMESTAMP}.bar"
  LATEST_BAR="bar/${CI_PROJECT_NAME}-${service}-latest.bar"

  # ===================================================
  # Build BAR
  # ===================================================

  ibmint package \
    --input-path applications \
    --project "$service" \
    --output-bar-file "$VERSION_BAR"

  # ===================================================
  # Validate BAR
  # ===================================================

  if [ ! -f "$VERSION_BAR" ]; then
    echo "ERROR: BAR file not created for $service"
    exit 1
  fi

  # ===================================================
  # Create Latest Copies
  # ===================================================

  cp "$VERSION_BAR" "$TIMESTAMP_BAR"
  cp "$VERSION_BAR" "$LATEST_BAR"

  echo "BAR files created:"

  ls -lh "$VERSION_BAR"
  ls -lh "$TIMESTAMP_BAR"
  ls -lh "$LATEST_BAR"

  # ===================================================
  # Upload to Nexus
  # ===================================================

  echo "Uploading BAR files to Nexus..."

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$VERSION_BAR" \
    "${NEXUS_REPOSITORY}/$(basename "$VERSION_BAR")"

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$TIMESTAMP_BAR" \
    "${NEXUS_REPOSITORY}/$(basename "$TIMESTAMP_BAR")"

  curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$LATEST_BAR" \
    "${NEXUS_REPOSITORY}/$(basename "$LATEST_BAR")"

  echo "Upload completed for $service"

done < .changed_services

# =====================================================
# Build Completed
# =====================================================

echo "===== BUILD COMPLETED ====="

echo "Generated BAR files:"
ls -lh bar/

echo "Changed services/libraries:"
cat .changed_services || true

echo "Artifacts already available in shared workspace."

echo "===== SCRIPT FINISHED SUCCESSFULLY ====="
