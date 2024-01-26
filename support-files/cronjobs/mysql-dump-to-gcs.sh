#!/bin/bash

# This script expects the following variables to be available
#   in the OS environment.

    #~ export MYSQLHOST=mysql.svc.cluster.local
    #~ export MYSQLPORT=3306
    #~ export MYSQLDBNAME=wordpress
    #~ export MYSQLUSER=wordpress
    #~ export MYSQLPASSWORD=wordpress
    #~ export GCPPROJECTID=$(gcloud config get-value project)
    #~ export GCSBUCKET=gs://mysql-backups-aclab-me
# It also expects a GCPKEY jsonfile in original form.
# GCP service account should have cloud storage admin privileges.


DUMPFILE=/tmp/$(date +%F-%H-%M)-${MYSQLDBNAME}-compressed-mysql.dump

GCPKEYFILE=/root/gcp-key.json


echo "Starting backup of ${MYSQLDBNAME} to ${DUMPFILE} ..." 

mysqldump \
  --compress \
  --routines \
  --host=${MYSQLHOST} \
  --port=${MYSQLPORT} \
  --user=${MYSQLUSER} \
  --password=${MYSQLPASSWORD} \
  --databases ${MYSQLDBNAME} \
  --result-file=${DUMPFILE}


echo "Backup of MySQL database ${MYSQLDBNAME} to ${DUMPFILE} .. Done."

ls -lhtr ${DUMPFILE}

if [ ! -r ${GCPKEYFILE} ]; then
  echo "ERROR - File ${GCPKEYFILE} was not found!"
fi


gcloud auth activate-service-account \
  --key-file=${GCPKEYFILE}

#kubectl cp /home/kamran/Downloads/trainingvideos-3ea2d93e747d.json mysql-pg-gsutil:/root/gcp-key.json

  
gsutil cp ${DUMPFILE} ${GCSBUCKET}/


echo "Backup to ${GCSBUCKET}/${DUMPFILE} .. Done."

gsutil ls ${GCSBUCKET}
