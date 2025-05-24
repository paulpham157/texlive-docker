#!/bin/bash
set -ex

# 1. Build individual texlive versions
for TL_VERSION in 2018 2020 2022 2024; do
    TL_IMAGE="scienhub/texlive:${TL_VERSION}"
    echo "Building texlive ${TL_VERSION}..."
    docker build --file Dockerfile \
        --tag "$TL_IMAGE" \
        --build-arg BASE="scienhub/base" \
        --build-arg TL_VERSION="$TL_VERSION" \
        --build-arg TL_MIRROR="https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/${TL_VERSION}/tlnet-final" \
        ./
    docker push "$TL_IMAGE"
done

# 2. Build the mono image
MONO_IMAGE="scienhub/texlive:mono"

DOCKER_BUILDKIT=0 docker build \
    --tag "$MONO_IMAGE" \
    --file mono.dockerfile \
    ./

docker push "$MONO_IMAGE"

