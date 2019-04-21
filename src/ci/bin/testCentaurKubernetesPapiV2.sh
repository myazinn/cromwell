#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
export CROMWELL_BUILD_REQUIRES_SECURE=true
# import in shellcheck / CI / IntelliJ compatible ways
# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/test.inc.sh" || source test.inc.sh

# Setting these variables should cause the associated config values to be rendered into centaur_application_horicromtal.conf
# There should probably be more indirections in CI scripts but that can wait.
export TEST_CROMWELL_TAG=just-testing-horicromtal
export TEST_CROMWELL_CONF=horicromtal_application.conf
export CROMWELL_BUILD_MYSQL_USERNAME=travis

cromwell::build::setup_common_environment

cromwell::build::setup_centaur_environment

#cromwell::build::assemble_jars

GOOGLE_AUTH_MODE="service-account"
GOOGLE_REFRESH_TOKEN_PATH="${CROMWELL_BUILD_RESOURCES_DIRECTORY}/papi_refresh_token.txt"

# Export variables used in conf files
export GOOGLE_AUTH_MODE
export GOOGLE_REFRESH_TOKEN_PATH
export TEST_CROMWELL_COMPOSE_FILE="${CROMWELL_BUILD_ROOT_DIRECTORY}/scripts/docker-compose-mysql/docker-compose-horicromtal.yml"

# Copy rendered files
mkdir -p "${CROMWELL_BUILD_CENTAUR_TEST_RENDERED}"
cp \
    "${CROMWELL_BUILD_RESOURCES_DIRECTORY}/private_docker_papi_v2_usa.options" \
    "${TEST_CROMWELL_COMPOSE_FILE}" \
    "${CROMWELL_BUILD_CENTAUR_TEST_RENDERED}"

GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON="cromwell-centaur-service-account.json"
GOOGLE_ZONE=us-central1-c

KUBE_CLUSTER_NAME=$(cromwell::build::centaur_gke_name "cluster")
KUBE_SQL_INSTANCE_NAME=$(cromwell::build::centaur_gke_name "cloudsql")
KUBE_CLOUDSQL_PASSWORD="$(cat ${CROMWELL_BUILD_RESOURCES_DIRECTORY}/cromwell-centaur-gke-cloudsql.json | jq -r '.db_pass')"

GOOGLE_PROJECT=$(cat "$CROMWELL_BUILD_RESOURCES_DIRECTORY/$GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON" | jq -r .project_id)

# TEMP TURNING THIS OFF TO TEST CLOUDSQL STUFF
# gcloud --project $GOOGLE_PROJECT container clusters create --zone $GOOGLE_ZONE $KUBE_CLUSTER_NAME --num-nodes=3
#WARNING: Accessing a Container Engine cluster requires the kubernetes commandline
#client [kubectl]. To install, run
#  $ gcloud components install kubectl

# Phase 1. Even this is PAPI since Cromwell will be running in a Docker container and trying to run Docker in Docker
#          currently no es bueno.
# - spin up a Cloud SQL. Obtain its coordinates to be able to access it from a Cloud SQL proxy.
#   (I think this might have been why I didn't do Cloud SQL before but who cares I think it's worth it).
#
cromwell::build::gcloud_run_as_service_account \
  "gcloud --project $GOOGLE_PROJECT sql instances create --zone $GOOGLE_ZONE --storage-size=10GB --database-version=MYSQL_5_7 $KUBE_SQL_INSTANCE_NAME" \
  $GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON

# Create a user
cromwell::build::gcloud_run_as_service_account \
  "gcloud --project $GOOGLE_PROJECT sql users create cromwell --instance $KUBE_SQL_INSTANCE_NAME --password='${KUBE_CLOUDSQL_PASSWORD}'" \
  $GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON

# This is what the Cloud SQL proxies will need for their -instances parameter
KUBE_CLOUDSQL_CONNECTION_NAME=$(cromwell::build::gcloud_run_as_service_account \
  "gcloud sql instances list --filter=name:$KUBE_SQL_INSTANCE_NAME --format='value(connectionName)'" \
  $GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON | tr -d '\n')

echo "Instance connectionName is $KUBE_CLOUDSQL_CONNECTION_NAME"

# - spin up a CloudIP service fronting said MySQL container
# - spin up a uni-Cromwell that talks to said MySQL
# - spin up a LoadBalancer service that fronts this Cromwell
#
# Run the Centaur test suite against this Cromwell service.

# Phase 1. Even this is PAPI since Cromwell will be running in a Docker container and trying to run Docker in Docker
#          currently no es bueno.
# - spin up a MySQL container expressing a PersistentVolumeClaim
# - spin up a CloudIP service fronting said MySQL container
# - spin up a uni-Cromwell that talks to said MySQL
# - spin up a LoadBalancer service that fronts this Cromwell
#
# Run the Centaur test suite against this Cromwell service.

# Phase 2 same as Phase 1 except separate Cromwells for summarizer, frontend, backend.

# TEMP TURNING THIS OFF TO TEST CLOUDSQL STUFF
# gcloud --project $GOOGLE_PROJECT --quiet container clusters delete $GOOGLE_KUBERNETES_CLUSTER_NAME --zone $GOOGLE_ZONE

#docker image ls -q broadinstitute/cromwell:"${TEST_CROMWELL_TAG}" | grep . || \
#CROMWELL_SBT_DOCKER_TAGS="${TEST_CROMWELL_TAG}" sbt server/docker
#
#cromwell::build::run_centaur \
#    -p 100 \
#    -e localdockertest \
#    "${CROMWELL_BUILD_CENTAUR_TEST_ADDITIONAL_PARAMETERS:-""}" \
#    -d "${CROMWELL_BUILD_CENTAUR_TEST_DIRECTORY}"
#
#cromwell::build::generate_code_coverage