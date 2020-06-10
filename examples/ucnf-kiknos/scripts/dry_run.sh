#!/usr/bin/env bash

function pipe() {
  local cmd=$1; shift
  while read -r in; do s="$s$in"; done
  echo "$s | $cmd $*"
}
function aws() { echo "aws $*"; }
function python() { echo "python $*"; }
function eksctl() { echo "eksctl $*"; }
function helm() { echo "helm $*"; }
function kind() { echo "kind $*"; }
function make() { echo "make $*"; }
function bash() { echo "bash $*"; }
function grep() { pipe grep $*;}
function awk() { pipe awk $*;}
function cut() { pipe cut $*;}
function kubectl() {
  if [[ $* =~ (-f|--filename)([[:space:]]+|[[:space:]]*=[[:space:]]*)- ]]; then
    pipe kubectl $*;
  fi
  echo "kubectl $*"
}
