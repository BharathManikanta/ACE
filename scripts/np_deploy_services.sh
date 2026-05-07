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

    # =================================================
    # Use Generic YAML
    # =================================================

    cp "$YAML_PATH/generic.yaml" \
       "$YAML_PATH/generic-modified.yaml"

    APP_BAR="ace-app-${service}-latest.bar"

    # =================================================
    # Common Library BAR
    # =================================================

    if grep -q "^CommonLibrary$" "$CHANGED_SERVICES_FILE"; then
      COMMON_BAR="ace-app-CommonLibrary-latest-${TIMESTAMP}.bar"
    else
      COMMON_BAR="ace-app-CommonLibrary-latest.bar"
    fi

    # =================================================
    # Exception Handler BAR
    # =================================================

    if grep -q "^Exception_Handler$" "$CHANGED_SERVICES_FILE"; then
      EXCEPTION_BAR="ace-app-Exception_Handler-latest-${TIMESTAMP}.bar"
    else
      EXCEPTION_BAR="ace-app-Exception_Handler-latest.bar"
    fi

    # =================================================
    # Replace YAML Values
    # =================================================

    sed -i "s|eidiko|$integration_server|g" \
      "$YAML_PATH/generic-modified.yaml"

    sed -i "s|ApplicationURL|$NEXUS_REPOSITORY/$APP_BAR|g" \
      "$YAML_PATH/generic-modified.yaml"

    sed -i "s|CommonLibraryURL|$NEXUS_REPOSITORY/$COMMON_BAR|g" \
      "$YAML_PATH/generic-modified.yaml"

    sed -i "s|ExceptionHandlerURL|$NEXUS_REPOSITORY/$EXCEPTION_BAR|g" \
      "$YAML_PATH/generic-modified.yaml"

    echo "===== MODIFIED YAML ====="

    cat "$YAML_PATH/generic-modified.yaml"

    # =================================================
    # Deploy
    # =================================================

    oc apply \
      -f "$YAML_PATH/generic-modified.yaml" \
      -n "$OPENSHIFT_NAMESPACE"

  done < "$SERVICE_MAP_FILE"

fi

# =====================================================
# Deploy Changed Services
# =====================================================

echo "===== DEPLOY CHANGED SERVICES ====="

while read -r service; do

  [ -z "$service" ] && continue

  # Skip Libraries
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

  echo "Integration Server: $INTEGRATION_SERVER"

  # ===================================================
  # Use Generic YAML
  # ===================================================

  cp "$YAML_PATH/generic.yaml" \
     "$YAML_PATH/generic-modified.yaml"

  # ===================================================
  # BAR Names
  # ===================================================

  APP_BAR="ace-app-${service}-v${BUILD_NUMBER}.bar"

  COMMON_BAR="ace-app-CommonLibrary-latest.bar"

  EXCEPTION_BAR="ace-app-Exception_Handler-latest.bar"

  # ===================================================
  # Replace YAML Values
  # ===================================================

  sed -i "s|eidiko|$INTEGRATION_SERVER|g" \
    "$YAML_PATH/generic-modified.yaml"

  sed -i "s|ApplicationURL|$NEXUS_REPOSITORY/$APP_BAR|g" \
    "$YAML_PATH/generic-modified.yaml"

  sed -i "s|CommonLibraryURL|$NEXUS_REPOSITORY/$COMMON_BAR|g" \
    "$YAML_PATH/generic-modified.yaml"

  sed -i "s|ExceptionHandlerURL|$NEXUS_REPOSITORY/$EXCEPTION_BAR|g" \
    "$YAML_PATH/generic-modified.yaml"

  echo "===== MODIFIED YAML ====="

  cat "$YAML_PATH/generic-modified.yaml"

  # ===================================================
  # Deploy
  # ===================================================

  oc apply \
    -f "$YAML_PATH/generic-modified.yaml" \
    -n "$OPENSHIFT_NAMESPACE"

done < "$CHANGED_SERVICES_FILE"

# =====================================================
# POD STATUS CHECK
# =====================================================

echo "===== CHECKING POD STATUS ====="

while read -r service; do

  [ -z "$service" ] && continue

  if [[ "$service" == "CommonLibrary" || "$service" == "Exception_Handler" ]]; then
    continue
  fi

  INTEGRATION_SERVER=$(grep "^${service}=" \
    "$SERVICE_MAP_FILE" | cut -d'=' -f2)

  if [ -z "$INTEGRATION_SERVER" ]; then
    continue
  fi

  echo "Checking Pod: $INTEGRATION_SERVER"

  POD_NAME=$(oc get pods \
    -n "$OPENSHIFT_NAMESPACE" \
    -l app.kubernetes.io/name="$INTEGRATION_SERVER" \
    -o jsonpath='{.items[0].metadata.name}')

  if [ -z "$POD_NAME" ]; then
    echo "No pod found."
    continue
  fi

  echo "Pod Name: $POD_NAME"

  for i in {1..10}; do

    STATUS=$(oc get pod "$POD_NAME" \
      -n "$OPENSHIFT_NAMESPACE" \
      -o jsonpath='{.status.phase}')

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
    exit 1
  fi

done < "$CHANGED_SERVICES_FILE"

echo "===== DEPLOYMENT COMPLETED SUCCESSFULLY ====="
