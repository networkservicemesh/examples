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
	cmd_status
	cmd_check_gre
	cmd_test_ping
	cmd_test_loadbalancing
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

##  status
##    Print route status and ping.
cmd_status() {
	local cmd
	local pod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	log "==== Status in pod [$pod]"
	for cmd in "vppctl show int" \
		"vppctl show lb vips verbose" \
		"vppctl ping 10.60.1.4 repeat 1" \
		"ping -c1 -W1 10.70.0.1" \
		"ping -c1 -W1 10.60.1.4" \
		"ip addr show" \
		"ip ro" \
		"ip ro get 10.2.2.2" \
		; do
		log "Cmd [$cmd]"
		kubectl exec $pod -- $cmd
	done

	pod=$(kubectl get pods -l networkservicemesh.io/app=application-server -o name | head -1)
	log "==== Status in pod [$pod]"
	for cmd in \
		"ip link show" \
		"ip addr show" \
		"ip ro" \
		"ip rule" \
		"ip ro show table 222" \
		; do
		log "Cmd [$cmd]"
		kubectl exec -c alpine-img $pod -- $cmd
	done

	return 0
}

cmd_check_gre() {
	log "==== Check GRE access"
	local pod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	local cmd
	for cmd in \
		"ip tunnel add foo4 mode gre remote 10.60.1.4" \
		"ip addr add 10.70.0.5/32 dev foo4" \
		"ip link set up dev foo4" \
		"ip ro add 10.2.2.3/32 dev foo4" \
		"ping -c1 -W1 10.2.2.3" \
		; do
		log "Cmd [$cmd]"
		kubectl exec $pod -- $cmd
	done

}

##  test_ping
##    Ping the VIP address
cmd_test_ping() {
	log "Ping the VIP address"
	local now begin=$(date +%s)
	local lbpod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	while ! kubectl exec $lbpod -- ping -c1 -W1 10.2.2.2; do
		now=$(date +%s)
		test $((now-begin)) -gt 60 && die "Ping failed"
		sleep 1
	done
	return 0
}

##  test_loadbalancing
cmd_test_loadbalancing() {
	log "Test load-balancing"
	local lbpod=$(kubectl get pods -l networkservicemesh.io/app=load-balancer -o name)
	log "load-balancer pod [$lbpod]"
	cmd='for i in $(seq 1 30); do nc -w 2 10.2.2.2 5001 < /dev/null; done'
	log "Execute command [$cmd]"
	kubectl exec $lbpod -- sh -c "$cmd" | tee /tmp/lb-data.txt
	cmd_freq /tmp/lb-data.txt | tee /tmp/lb-freq.txt
	local i=$(cat /tmp/lb-freq.txt | wc -l)
	test $i -lt 2 && die "No loadbalancing"
	# Note to nitpickers;
	# Yes, this test has probability to fail, I get it to 1/3^29 if the lb-targets are random
}

cmd_freq() {
	test -n "$1" || die "No file"
	test -r "$1" || die "Not readable [$1]"
	local n i
	for n in $(sort < $1 | uniq); do
		i=$(grep $n $1 | wc -l)
		echo "$n:$i"
	done
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
