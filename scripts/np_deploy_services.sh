#!/bin/bash
set -e

echo "===== DEPLOYMENT STARTED ====="

WORKSPACE_PATH=$(pwd)

echo "Workspace Path: $WORKSPACE_PATH"

# =====================================================
# Load Environment Variables
# =====================================================

source "$WORKSPACE_PATH/.env"

echo "BUILD_NUMBER=$BUILD_NUMBER"
echo "TIMESTAMP=$TIMESTAMP"

# =====================================================
# Files
# =====================================================

CHANGED_SERVICES_FILE="$WORKSPACE_PATH/.changed_services"

SERVICE_MAP_FILE="$WORKSPACE_PATH/mappings/service-map.properties.txt"

YAML_PATH="$WORKSPACE_PATH/integration-servers"

ALL_DEPLOYED_SERVICES="/tmp/all_deployed_services.txt"

rm -f "$ALL_DEPLOYED_SERVICES"

# =====================================================
# Validate Files
# =====================================================

if [ ! -f "$SERVICE_MAP_FILE" ]; then
  echo "ERROR: service-map.properties not found"
  exit 1
fi

if [ ! -s "$CHANGED_SERVICES_FILE" ]; then
  echo "No changed services found."
  exit 0
fi

echo "===== CHANGED SERVICES ====="

cat "$CHANGED_SERVICES_FILE"

echo "===== SERVICE MAP CONTENT ====="

cat "$SERVICE_MAP_FILE"

# =====================================================
# FIX WINDOWS LINE ENDINGS
# =====================================================

sed -i 's/\r$//' "$SERVICE_MAP_FILE"

echo "===== LOGIN TO OPENSHIFT ====="

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

oc login "$SERVER_URL" \
  --token="$TOKEN" \
  --insecure-skip-tls-verify

# =====================================================
# Common Library Flags
# =====================================================

DEPLOY_COMMON=false

if grep -q "^CommonLibrary$" "$CHANGED_SERVICES_FILE"; then
  DEPLOY_COMMON=true
fi

if grep -q "^Exception_Handler$" "$CHANGED_SERVICES_FILE"; then
  DEPLOY_COMMON=true
fi

echo "DEPLOY_COMMON=$DEPLOY_COMMON"

# =====================================================
# Deploy All Services if Common Libraries Changed
# =====================================================

if [ "$DEPLOY_COMMON" = true ]; then

  echo "===== DEPLOYING ALL SERVICES ====="

  while IFS='=' read -r service integration_server; do

    [ -z "$service" ] && continue

    echo "----------------------------------"

    echo "Service: $service"

    echo "Integration Server: $integration_server"

    echo "$service" >> "$ALL_DEPLOYED_SERVICES"

    TEMP_YAML="$YAML_PATH/${service}-modified.yaml"

    cp "$YAML_PATH/generic.yaml" "$TEMP_YAML"

    APP_BAR="ace-app-${service}-latest.bar"

    if grep -q "^CommonLibrary$" "$CHANGED_SERVICES_FILE"; then
      COMMON_BAR="ace-app-CommonLibrary-latest-${TIMESTAMP}.bar"
    else
      COMMON_BAR="ace-app-CommonLibrary-latest.bar"
    fi

    if grep -q "^Exception_Handler$" "$CHANGED_SERVICES_FILE"; then
      EXCEPTION_BAR="ace-app-Exception_Handler-latest-${TIMESTAMP}.bar"
    else
      EXCEPTION_BAR="ace-app-Exception_Handler-latest.bar"
    fi

    sed -i "s|eidiko|$integration_server|g" "$TEMP_YAML"

    sed -i "s|ApplicationURL|$NEXUS_REPOSITORY/$APP_BAR|g" "$TEMP_YAML"

    sed -i "s|CommonLibraryURL|$NEXUS_REPOSITORY/$COMMON_BAR|g" "$TEMP_YAML"

    sed -i "s|ExceptionHandlerURL|$NEXUS_REPOSITORY/$EXCEPTION_BAR|g" "$TEMP_YAML"

    echo "===== MODIFIED YAML ====="

    cat "$TEMP_YAML"

    echo "Applying Integration Server..."

    oc apply \
      -f "$TEMP_YAML" \
      -n "$OPENSHIFT_NAMESPACE" || {

        echo "ERROR deploying $integration_server"

        continue
    }

    echo "Deployment submitted for $integration_server"

    sleep 20

  done < "$SERVICE_MAP_FILE"

fi

# =====================================================
# Deploy Changed Services
# =====================================================

if [ "$DEPLOY_COMMON" = false ]; then

  echo "===== DEPLOY CHANGED SERVICES ====="

  while read -r service; do

    [ -z "$service" ] && continue

    if [[ "$service" == "CommonLibrary" || "$service" == "Exception_Handler" ]]; then
      continue
    fi

    echo "----------------------------------"

    echo "Deploying Service: $service"

    INTEGRATION_SERVER=$(grep "^${service}=" \
      "$SERVICE_MAP_FILE" | cut -d'=' -f2)

    if [ -z "$INTEGRATION_SERVER" ]; then
      echo "No integration server mapping found for $service"
      continue
    fi

    echo "$service" >> "$ALL_DEPLOYED_SERVICES"

    echo "Integration Server: $INTEGRATION_SERVER"

    TEMP_YAML="$YAML_PATH/${service}-modified.yaml"

    cp "$YAML_PATH/generic.yaml" "$TEMP_YAML"

    APP_BAR="ace-app-${service}-v${BUILD_NUMBER}.bar"

    COMMON_BAR="ace-app-CommonLibrary-latest.bar"

    EXCEPTION_BAR="ace-app-Exception_Handler-latest.bar"

    sed -i "s|eidiko|$INTEGRATION_SERVER|g" "$TEMP_YAML"

    sed -i "s|ApplicationURL|$NEXUS_REPOSITORY/$APP_BAR|g" "$TEMP_YAML"

    sed -i "s|CommonLibraryURL|$NEXUS_REPOSITORY/$COMMON_BAR|g" "$TEMP_YAML"

    sed -i "s|ExceptionHandlerURL|$NEXUS_REPOSITORY/$EXCEPTION_BAR|g" "$TEMP_YAML"

    echo "===== MODIFIED YAML ====="

    cat "$TEMP_YAML"

    echo "Applying Integration Server..."

    oc apply \
      -f "$TEMP_YAML" \
      -n "$OPENSHIFT_NAMESPACE" || {

        echo "ERROR deploying $INTEGRATION_SERVER"

        continue
    }

    echo "Deployment submitted for $INTEGRATION_SERVER"

    sleep 20

  done < "$CHANGED_SERVICES_FILE"

fi

# =====================================================
# POD STATUS CHECK
# =====================================================

echo "===== CHECKING POD STATUS ====="

while read -r service; do

  [ -z "$service" ] && continue

  INTEGRATION_SERVER=$(grep "^${service}=" \
    "$SERVICE_MAP_FILE" | cut -d'=' -f2)

  if [ -z "$INTEGRATION_SERVER" ]; then
    continue
  fi

  echo "Checking Pod: $INTEGRATION_SERVER"

  POD_NAME=""

  for i in {1..10}; do

    POD_NAME=$(oc get pods \
      -n "$OPENSHIFT_NAMESPACE" \
      -l app.kubernetes.io/name="$INTEGRATION_SERVER" \
      -o jsonpath='{.items[0].metadata.name}' \
      2>/dev/null || true)

    if [ -n "$POD_NAME" ]; then
      break
    fi

    echo "Waiting for pod creation..."
    sleep 15

  done

  if [ -z "$POD_NAME" ]; then
    echo "No pod found for $INTEGRATION_SERVER"
    exit 1
  fi

  echo "Pod Name: $POD_NAME"

  for i in {1..20}; do

    STATUS=$(oc get pod "$POD_NAME" \
      -n "$OPENSHIFT_NAMESPACE" \
      -o jsonpath='{.status.phase}' \
      2>/dev/null || true)

    echo "Current Status: $STATUS"

    if [ "$STATUS" == "Running" ]; then
      echo "Pod Running Successfully"
      break
    fi

    echo "Waiting 30 seconds..."
    sleep 30

  done

  if [ "$STATUS" != "Running" ]; then

    echo "Pod failed to reach Running state."

    echo "===== POD DETAILS ====="

    oc describe pod "$POD_NAME" \
      -n "$OPENSHIFT_NAMESPACE" || true

    echo "===== POD LOGS ====="

    oc logs "$POD_NAME" \
      -n "$OPENSHIFT_NAMESPACE" || true

    exit 1

  fi

done < "$ALL_DEPLOYED_SERVICES"

echo "===== DEPLOYMENT COMPLETED SUCCESSFULLY ====="
