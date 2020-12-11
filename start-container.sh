#!/bin/bash
# Copyright 2017 Yahoo Holdings. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

if [ $# -gt 1 ]; then
    echo "Allowed arguments to entrypoint are {configserver,services}."
    exit 1
fi

# Always set the hostname to the FQDN name if available
#hostname $(hostname -f) || true

# Always make sure vespa:vespa owns what is in /opt/vespa
chown -R vespa:vespa /opt/vespa

if [ -n "$1" ]; then
    if [ -z "$VESPA_CONFIGSERVERS" ]; then
        echo "VESPA_CONFIGSERVERS must be set with '-e VESPA_CONFIGSERVERS=<comma separated list of config servers>' argument to docker."
        exit 1
    fi
    case $1 in
        configserver)
            /opt/vespa/bin/vespa-start-configserver
            ;;
        services)
            /opt/vespa/bin/vespa-start-services
            ;;
        *)
            echo "Allowed arguments to entrypoint are {configserver,services}."
            exit 1
            ;;
    esac
else
    export VESPA_CONFIGSERVERS=$(hostname)
    /opt/vespa/bin/vespa-start-configserver
    /opt/vespa/bin/vespa-start-services

    printf 'Waiting for Vespa Start...\n'
    until $(curl --output /dev/null --silent --head --fail http://db-admin0:19071/ApplicationStatus); do
        sleep 2
    done

    /opt/vespa/bin/vespa-deploy prepare /xscholar-vespa/target/application.zip && /opt/vespa/bin/vespa-deploy activate

    printf 'Waiting for Application Start...\n'
    until $(curl --output /dev/null --silent --head --fail http://db-stateless0:8080/ApplicationStatus); do
        sleep 5
    done

    FILE=nfs/feed-file.json
    if test -f "$FILE"; then
        printf 'Feeding Vespa...\n'
        java -jar /opt/vespa/lib/jars/vespa-http-client-jar-with-dependencies.jar --file nfs/feed-file.json --endpoint http://db-stateless0:8080 --verbose --useCompression
    else
        printf 'No feed file found at nfs/feed-file.json. Please feed documents manually.\n'
    fi
fi

printf 'Vespa configuration complete! \n'

tail -f /dev/null