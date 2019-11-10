#!/bin/bash
set -x
# Original script by Andy Bursavich:
# https://github.com/kubernetes/kubernetes/issues/79384#issuecomment-521493597

DIR=$( dirname "${BASH_SOURCE[0]}" )/../
cd "${DIR}"

set -euo pipefail

BRANCH=${1:-master}

if [ -d $BRANCH ]
then
  LOCALPATH=$BRANCH
else
  V=$(
          go mod download -json "github.com/networkservicemesh/networkservicemesh/controlplane/api@${BRANCH}" |
          sed -n 's|.*"Version": "\(.*\)".*|\1|p'
      )
fi

MODS=()
while IFS='' read -r line
do
    MODS+=("$line")
done < <( grep "github.com/networkservicemesh/networkservicemesh" go.mod  | awk '{print $1}' | sort -u)


for MOD in "${MODS[@]}"; do
  if [ -z ${LOCALPATH+x} ]
  then
    go mod edit "-replace=${MOD}=${MOD}@${V}"
  else
    go mod edit -replace="${MOD}"="${MOD/github.com\/networkservicemesh\/networkservicemesh/$LOCALPATH}"
  fi
done
go mod tidy
