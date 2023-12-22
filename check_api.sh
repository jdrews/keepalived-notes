#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure http://localhost:80 -o /dev/null || errorExit "Error GET"