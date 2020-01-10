#! /bin/sh
##
## nsehook.sh --
##
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
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

log() {
	echo "$*" >&2
}
dbg() {
	test "$__verbose" = "true" && echo "$*" >&2
}
x() {
	dbg "$*"
	$* || die "Failed to ececute [$*]"
}

##  env
##    Print environment.
##
cmd_env() {
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
	__verbose=true
}

##  endpoint_started
##    Calles as a "hook" when the NSE is started.
##
cmd_endpoint_started() {

	cmd_env

	x ip link add name vpp1out type veth peer name vpp1host
	x ip link set dev vpp1out up
	x ip link set dev vpp1host up
	x ip addr add 10.70.0.0/31 dev vpp1host

	x vppctl create host-interface name vpp1out
	x vppctl set int state host-vpp1out up
	x vppctl set int ip address host-vpp1out 10.70.0.1/31
	x vppctl ip route add 0.0.0.0/0 via 10.70.0.0 host-vpp1out

	x vppctl create loopback interface
	x vppctl set int l2 bridge loop0 1 bvi
	x vppctl set interface state loop0 up
	x vppctl set int ip address loop0 10.60.1.1/24

	x ip ro add 10.60.1.0/24 via 10.70.0.1

	test -n "$VIP_ADDRESS" || die 'Not set [$VIP_ADDRESS]'
	x vppctl lb vip $VIP_ADDRESS
	x vppctl lb conf ip4-src-address 10.60.1.1
	x ip ro add $VIP_ADDRESS via 10.70.0.1


	return 0
}

cmd_new_connection() {
	cmd_env
	test -n "$VIP_ADDRESS" || die 'Not set [$VIP_ADDRESS]'
	x vppctl lb as $VIP_ADDRESS $1
}

cmd_del_connection() {
	cmd_env
	test -n "$VIP_ADDRESS" || die 'Not set [$VIP_ADDRESS]'
	x vppctl lb as $VIP_ADDRESS $1 del
}

cmd_x() {
	cmd_env
	x $*
}

# Get the command
cmd=$1
shift
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
