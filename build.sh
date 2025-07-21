#!/bin/bash


samba_version=$(git tag)
if [ "X$samba_version" == "X" ]; then
  samba_version=4
fi
version=$(git rev-parse --short HEAD)
build_date=$(date -Iseconds)
tagdate=$(date +%Y_%m_%d__%H%M)
gituser=$(git config --global user.name)

echo "version: $version"
echo "build_date: $build_date"
echo "tagdate: $tagdate"
echo "gituser: $gituser"
echo "user: $USER"

docker build \
        --build-arg "version=$version" \
        --build-arg "build_date=$build_date" \
        -t $USER/docker-samba-ad-dc:${samba_version} smb-ad-dc
docker tag $USER/docker-samba-ad-dc:${samba_version} $USER/docker-samba-ad-ac:latest
