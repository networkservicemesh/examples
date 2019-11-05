#!/bin/bash



########################
# include the magic
########################
DEMOMAGIC=${DEMOMAGIC:-/Users/tiswanso/src/demo-magic/demo-magic.sh}
. ${DEMOMAGIC} -d

# hide the evidence
clear

function pc {
    pe "$@"
    #pe "clear"
    echo "----DONE---- $@"
    wait
    clear
}


pc `ping -c 20 10.87.49.1 &`
