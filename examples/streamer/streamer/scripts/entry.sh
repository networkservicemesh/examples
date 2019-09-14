#!/bin/sh

while true
do
    ncat --exec "/bin/source.sh" -l 0.0.0.0 80
done
