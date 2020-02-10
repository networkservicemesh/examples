#! /bin/sh
##
## check_load_balancer.sh --
##
##   Test-script for the NSM example;
##   https://github.com/networkservicemesh/examples/examples/load-balancer/
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$

die() {
    echo "ERROR: $*" >&2
    rm -rf $tmp
    exit 1
}
help() {
    grep '^##' $0 | cut -c3-
    rm -rf $tmp
    exit 0
}
echo "$1" | grep -qi "^help\|-h" && help

log() {
	echo "$*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}

##  test
##    Execute tests.
##
cmd_test() {
	cmd_env
	local to=300s
	kubectl wait -n default --timeout=$to --for condition=Ready --all pods || \
		die "Pods not ready after $to"
	log "All PODs ready"

	cmd_check_load_balancer
	cmd_check_as
}

cmd_check_load_balancer() {
	local now begin=$(date +%s)
	local lbpod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	while test -z "$lbpod"; do
		sleep 5
		now=$(date +%s)
		test $((now-begin)) -lt 60 || die "Load-balancer POD not found"
		lbpod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	done
	log "Load-balancer POD [$lbpod]"
	kubectl wait -n default --timeout=30s --for condition=Ready $lbpod || \
		die "Lb-pod not ready"
}

cmd_check_as() {
	local now begin=$(date +%s)
	local aspods="$(kubectl get pods -l networkservicemesh.io/app=application-server -o name)"

	while test -z "$aspods"; do
		sleep 5
		now=$(date +%s)
		test $((now-begin)) -lt 60 || die "Application-server PODs not found"
		aspods="$(kubectl get pods -l networkservicemesh.io/app=application-server -o name)"
	done
	log "Application server PODs [$aspods]"
	kubectl wait -n default --timeout=30s --for condition=Ready $aspods || \
		die "AS-pods not ready"
}

# Get the command. Use "test" as default.
if test -n "$1"; then
	cmd=$1
	shift
else
	cmd=test
fi

grep -q "^cmd_$cmd()" $0 $hook || die "Invalid command [$cmd]"

while echo "$1" | grep -q '^--'; do
    if echo $1 | grep -q =; then
	o=$(echo "$1" | cut -d= -f1 | sed -e 's,-,_,g')
	v=$(echo "$1" | cut -d= -f2-)
	eval "$o=\"$v\""
    else
	o=$(echo "$1" | sed -e 's,-,_,g')
	eval "$o=yes"
    fi
    shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
