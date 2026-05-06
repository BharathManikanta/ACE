#!/bin/bash
set -e

echo "===== EMAIL NOTIFICATION STARTED ====="

echo "Workspace Path: $WORKSPACE_PATH"

# =====================================================
# Changed services file path
# =====================================================

CHANGED_SERVICES_FILE="$WORKSPACE_PATH/.changed_services"

echo "Looking for file:"
echo "$CHANGED_SERVICES_FILE"

# =====================================================
# Check changed services file
# =====================================================

if [ ! -s "$CHANGED_SERVICES_FILE" ]; then
  echo "No changed services found."
  exit 0
fi

# =====================================================
# Convert multiline services into comma-separated
# =====================================================

SERVICE_LIST=$(paste -sd "," "$CHANGED_SERVICES_FILE")

if [ -z "$SERVICE_LIST" ]; then
  echo "Service list empty."
  exit 0
fi

echo "Changed Services:"
echo "$SERVICE_LIST"

# =====================================================
# Go to scripts directory
# =====================================================

cd "$WORKSPACE_PATH/scripts"

echo "Current Directory:"
pwd

echo "Files:"
ls -la

# =====================================================
# Install dependency
# =====================================================

pip3 install jinja2

# =====================================================
# Send email
# =====================================================

python3 send_email.py \
  --name "Bharath" \
  --service_name "${SERVICE_LIST}" \
  --build_number "${CI_PIPELINE_IID}" \
  --build_time "${CI_PIPELINE_CREATED_AT}" \
  --recipient "bharathmanikanta.gundapu@eidiko.com"

echo "===== EMAIL NOTIFICATION COMPLETED ====="
