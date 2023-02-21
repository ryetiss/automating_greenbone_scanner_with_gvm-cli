#!/bin/bash

# This tool using for automating Greenbone Scanner with gvm-cli on Docker.
# Author: Ramazan YETIS


if [[ $# -lt 5 ]] ; then
   echo "Usage: $0 <TARGET_HOSTS> <TARGET_NAME> <TASK_NAME> <GMP_USERNAME> <GMP_PASSWORD>"
   exit 1
fi

TARGET_HOSTS=$1
TARGET_NAME=$2
TASK_NAME=$3
GMP_USER=$4
GMP_PASS=$5

CONTAINER_ID=$(docker ps -q -f ancestor=greenbone/gvmd:stable)

TARGET_ID=$(docker exec -iu gvmd $CONTAINER_ID gvm-cli --gmp-username $GMP_USER --gmp-password $GMP_PASS socket --socketpath /run/gvmd/gvmd.sock --xml "<create_target><name>$TARGET_NAME</name><hosts>$TARGET_HOSTS</hosts><port_list id='33d0cd82-57c6-11e1-8ed1-406186ea4fc5'></port_list></create_target>" | grep -oP '(?<=id=")[^"]+')
sleep 2
if [ -n "$TARGET_ID" ]; then echo "[INFO] TARGET WAS CREATED... ID:$TARGET_ID"; fi

TASK_ID=$(docker exec -iu gvmd $CONTAINER_ID gvm-cli --gmp-username $GMP_USER --gmp-password $GMP_PASS socket --socketpath /run/gvmd/gvmd.sock --xml "<create_task><name>$TASK_NAME</name><comment>Vulnerability scan of the hosts</comment><config id='daba56c8-73ec-11df-a475-002264764cea'/><target id='$TARGET_ID'/><scanner id='08b69003-5fc2-4037-a479-93b440211c73'/></create_task>" | grep -oP '(?<=id=")[^"]+')
sleep 2
if [ -n "$TASK_ID" ]; then echo "[INFO] TASK WAS CREATED... ID:$TASK_ID"; fi

REPORT_ID=$(docker exec -iu gvmd $CONTAINER_ID gvm-cli --gmp-username $GMP_USER --gmp-password $GMP_PASS socket --socketpath /run/gvmd/gvmd.sock --xml "<start_task task_id='$TASK_ID'/>" | grep -oP '(?<=<report_id>)[^<]+')
sleep 3
if [ -n "$REPORT_ID" ]; then echo "[INFO] REPORT ID IS $REPORT_ID"; fi

while true; do

        TASK_STATUS=$(docker exec -iu gvmd $CONTAINER_ID gvm-cli --gmp-username $GMP_USER --gmp-password $GMP_PASS socket --socketpath /run/gvmd/gvmd.sock --xml "<get_tasks task_id='$TASK_ID'/>" | grep -oP '(?<=<status>)[^<]+')

        if [ "$TASK_STATUS" = "Done" ]; then
                docker exec -iu gvmd $CONTAINER_ID gvm-cli --gmp-username $GMP_USER --gmp-password $GMP_PASS socket --socketpath /run/gvmd/gvmd.sock --xml "<get_reports report_id='$REPORT_ID' format_id='c1645568-627a-11e3-a660-406186ea4fc5' details='True'/>" | grep -oP '(?<=</report_format>)[^<]+' | base64 -d > ScanResults.csv
                echo "[INFO] TASK IS DONE"
                break
        elif [ "$TASK_STATUS" = "Running" ]; then
                echo "[INFO] Task is Running..."
                sleep 30
        elif [ "$TASK_STATUS" = "Queued" ]; then
                echo "[INFO] Task is Queuing..."
                sleep 30
        elif [ "$TASK_STATUS" = "Requested" ]; then
                echo "[INFO] Task is Requesting..."
                sleep 30
        else
                echo "[WARNING] Somethings go wrong..."
                break
        fi
done
