#!/bin/bash
export KUBECONFIG="$(kind get kubeconfig-path --name="nsm")"
