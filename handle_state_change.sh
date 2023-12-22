#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
        "MASTER")   echo "$(date) - $TYPE $NAME has triggered $STATE" >> /var/log/keepalived_state.log
                    # curl --silent --insecure http://localhost:80/to/MASTER -o /dev/null # Perform a REST API call to change state to MASTER
                    exit 0
                    ;;
        "BACKUP")   echo "$(date) - $TYPE $NAME has triggered $STATE" >> /var/log/keepalived_state.log
                    # curl --silent --insecure http://localhost:80/to/BACKUP -o /dev/null # Perform a REST API call to change state to BACKUP
                    exit 0
                    ;;
        "FAULT")    echo "$(date) - $TYPE $NAME has triggered $STATE" >> /var/log/keepalived_state.log
                    # curl --silent --insecure http://localhost:80/to/BACKUP -o /dev/null # Perform a REST API call to change state to BACKUP
                    exit 0
                    ;;
        *)          echo "unknown state"
                    exit 1
                    ;;
esac
~             