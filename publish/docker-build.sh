#!/usr/bin/env bash

# Builds the docker image used for publishing cromwell

set -euo pipefail

build_root="$( dirname "${BASH_SOURCE[0]}" )"
docker build "${build_root}" -t broadinstitute/cromwell-publish

echo "Success! Docker image is ready for pushing via:"
echo "docker push broadinstitute/cromwell-publish"
