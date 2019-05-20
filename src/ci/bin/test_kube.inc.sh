#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

source "${BASH_SOURCE%/*}/test.inc.sh" || source test.inc.sh

# A set of functions for use in the Kubernetes test script.

GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON="cromwell-centaur-service-account.json"
GOOGLE_ZONE=us-central1-c
DOCKER_ETC_PATH=/usr/share/etc

cromwell::build::setup_common_environment

cromwell::build::setup_centaur_environment

GOOGLE_PROJECT=$(cat "$CROMWELL_BUILD_RESOURCES_DIRECTORY/$GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON" | jq -r .project_id)

# Takes a single string argument and `echo`s a possibly modified version of that argument with non-alphanumeric
# characters converted to dashes. TODO: restrict the initial character as necessary
cromwell::kube::google_safe_name() {
  echo -n "$1" | tr -c '[[:digit:][:alpha:]]' '-'
}

cromwell::kube::google_safe_build_name() {
  echo -n "$(cromwell::kube::google_safe_name ${CROMWELL_BUILD_PROVIDER}-${CROMWELL_BUILD_NUMBER:-$RANDOM})"
}

# Creates a Google friendly identifier name specific to this build based on a single argument.
cromwell::kube::centaur_gke_name() {
  local prefix="centaur-gke"
  local build_name="$(cromwell::kube::google_safe_build_name)"
  local arg=$1
  echo -n "${prefix}-${arg}-${build_name}"
}

# Run a specified command after activating the specified service account.
#
# Usage: cromwell::kube::gcloud_run_as_service_account command
cromwell::kube::gcloud_run_as_service_account() {
  local command="$1"
  docker run -v "$CROMWELL_BUILD_RESOURCES_DIRECTORY:$DOCKER_ETC_PATH" -e DOCKER_ETC_PATH --rm google/cloud-sdk:latest /bin/bash -c "\
    gcloud auth activate-service-account --key-file $DOCKER_ETC_PATH/${GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON} && $command "
}

# Configure kubectl for gke then run the specified command
cromwell::kube::gcloud_run_kubectl_command_as_service_account() {
  local gkeClusterName="$1"
  local command="$2"
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT container clusters get-credentials --zone $GOOGLE_ZONE $gkeClusterName && $command"
}

cromwell::kube::generate_cloud_sql_instance_name() {
  echo -n $(cromwell::kube::centaur_gke_name "cloudsql")
}

# Starts a Cloud SQL instance with the specified name.
cromwell::kube::create_cloud_sql_instance() {
  local cloudSqlInstanceName="$1"
  local cloudSqlPassword="$(cat ${CROMWELL_BUILD_RESOURCES_DIRECTORY}/cromwell-centaur-gke-cloudsql.json | jq -r '.db_pass')"

  # Create the Cloud SQL instance.
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT sql instances create --zone $GOOGLE_ZONE --storage-size=10GB --database-version=MYSQL_5_7 $cloudSqlInstanceName"

  # Create a user.
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT sql users create cromwell --instance $cloudSqlInstanceName --password='${cloudSqlPassword}'"

  # Create the cromwell test database.
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT sql databases create cromwell_test --instance $cloudSqlInstanceName"
}

cromwell::kube::destroy_cloud_sql_instance() {
  local instanceName="$1"
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT --quiet sql instances delete $instanceName"
}

# Returns the connection name for the specific Cloud SQL instance name.
#
# Usage: cromwell::kube::connection_name_for_cloud_sql_instance instance_name
cromwell::kube::connection_name_for_cloud_sql_instance() {
  # TOL It appears the connectionName can be inferred (<project>:<region>:<instance name>), so it may not be necessary to query.
  local instanceName="$1"
  echo -n $(cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT sql instances describe $instanceName --format='value(connectionName)'" | tr -d '\n')
}

cromwell::kube::generate_gke_cluster_name() {
  echo -n $(cromwell::kube::centaur_gke_name "cluster")
}

# Create a GKE cluster with the specified name.
cromwell::kube::create_gke_cluster() {
  local gkeClusterName="$1"
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT container clusters create --zone $GOOGLE_ZONE $gkeClusterName --num-nodes=3"

  echo -n ${gkeClusterName}
}

cromwell:kube::destroy_gke_cluster() {
  local gkeClusterName="$1"
    cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT --quiet container clusters delete $gkeClusterName --zone $GOOGLE_ZONE"
}

cromwell::kube::generate_gcr_tag() {
  local buildName=$(cromwell::kube::google_safe_build_name)
  echo -n "gcr.io/$GOOGLE_PROJECT/centaur-gke/cromwell:${buildName}"
}

cromwell::kube::tag_for_gcr() {
  local image="$1"
  local tag="$2"
  docker tag ${image} ${tag}
}

cromwell::kube::gcr_login() {
  cat "$CROMWELL_BUILD_RESOURCES_DIRECTORY/$GOOGLE_CENTAUR_SERVICE_ACCOUNT_JSON" | docker login -u _json_key --password-stdin https://gcr.io
}

cromwell::kube::push_to_gcr() {
  local tag="$1"
  docker push ${tag}
}

cromwell::kube::delete_from_gcr() {
  local tag="$1"
  cromwell::kube::gcloud_run_as_service_account \
    "gcloud --project $GOOGLE_PROJECT --quiet container images delete $tag"
}

cromwell::kube::create_secrets() {
  local from_files=""
  for file in ${CROMWELL_BUILD_RESOURCES_DIRECTORY}/*.conf ${CROMWELL_BUILD_RESOURCES_DIRECTORY}/*.json
  do
    # This is going to run inside the gcloud Docker container which mounts the resources directory at $DOCKER_ETC_PATH
    from_files+="--from-file=${DOCKER_ETC_PATH}/$(basename ${file}) "
  done

  # Cromwell secrets don't need to be named in a build-specific way because they are scoped to a build-specific cluster.
  local command="kubectl create secret generic cromwell-secrets ${from_files}"
  echo "Creating secrets with command: $command"

  cromwell::kube::gcloud_run_kubectl_command_as_service_account \
    "${KUBE_CLUSTER_NAME}" "${command}"
}

cromwell::private::kube::rendered_file_for_vtmpl() {
  local file="$1"
  echo -n "${CROMWELL_BUILD_RESOURCES_DIRECTORY}/$(basename ${file%.vtmpl})"
}

# Takes an arbitrary number of environment variable names (*not* values). For all *.vtmpl files in the resources directory,
# replace text matching the name of each environment variable by the value of that environment variable.
# Redirect output to a file named the same as the input file minus the .vtmpl extension.
cromwell::kube::render_vtmpl_resources() {
  local seds=$(cromwell::private::build_render_vtmpl_command $*)
  for file in $(find ${CROMWELL_BUILD_RESOURCES_SOURCES} -name '*.vtmpl')
  do
    local outfile=$(cromwell::private::kube::rendered_file_for_vtmpl ${file})
    local command="cat ${file} | ${seds} > ${outfile}"
    eval "${command}"
    echo "Rendering ${file} -> ${outfile}"
  done
}

cromwell::private::build_render_vtmpl_command() {
  local seds=()
  for var in $*
  do
    seds+=(" sed 's/${var}/${!var}/g' ")
  done
  local IFS="|"
  echo -n "${seds[*]}"
}

cromwell::kube::start_cromwell() {
  for instance_type in frontend backend summarizer
  do
    KUBE_CROMWELL_INSTANCE_TYPE="${instance_type}"
    cromwell::kube::gcloud_run_kubectl_command_as_service_account \
      "${KUBE_CLUSTER_NAME}" "kubectl apply -f ${DOCKER_ETC_PATH}/cromwell-service.yaml"
  done
}
