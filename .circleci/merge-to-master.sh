#!/bin/bash
# if we are testing a PR, merge it with the latest master branch before testing
# this ensures that all tests pass with the latest changes in master.

set -eu -o pipefail

PR_NUMBER=${CI_PULL_REQUEST//*pull\//}
err=0

if [ -z "$PR_NUMBER" ]; then
    exit
fi

(set -x && git pull --ff-only origin "refs/pull/$PR_NUMBER/merge") || err=$?

if [ "$err" -ne "0" ]; then
    echo
    echo -e "\033[0;31mERROR: Failed to merge your branch with the latest master."
    echo -e "Please manually merge master into your branch, and push the changes to GitHub.\033[0m"
    exit $err
fi
