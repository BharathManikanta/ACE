#!/bin/bash
set -e

echo "===== EMAIL NOTIFICATION STARTED ====="

# -------------------------------------------------
# Check changed services file
# -------------------------------------------------
if [ ! -s .changed_services ]; then
  echo "No changed services found."
  exit 0
fi

# -------------------------------------------------
# Convert multiline services into comma-separated
# -------------------------------------------------
SERVICE_LIST=$(paste -sd "," .changed_services)

if [ -z "$SERVICE_LIST" ]; then
  echo "Service list empty."
  exit 0
fi

echo "Changed Services:"
echo "$SERVICE_LIST"

# -------------------------------------------------
# Go to scripts directory
# -------------------------------------------------
cd "$WORKSPACE_PATH/scripts"

# -------------------------------------------------
# Install dependency
# -------------------------------------------------
pip3 install jinja2

# -------------------------------------------------
# Send email
# -------------------------------------------------
python3 send_email.py \
  --name "Bharath" \
  --status "${CI_JOB_STATUS}" \
  --service_name "${SERVICE_LIST}" \
  --build_number "${CI_PIPELINE_IID}" \
  --build_time "${CI_PIPELINE_CREATED_AT}" \
  --recipient "bharathmanikanta.hundapu@gmail.com"

echo "===== EMAIL NOTIFICATION COMPLETED ====="
