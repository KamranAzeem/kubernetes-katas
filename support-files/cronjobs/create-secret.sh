#!/bin/bash

echo
echo "Usage: $0 <k8s-namespace>  <name-of-secrets-file> <name-of-secret-to-be-created>"
echo "Example: $0  crontab  ./secrets.env  credentials-mysql-db "
echo
echo "This scripts generates secret with the name <secret-name>"
echo


NAMESPACE=${1:-crontab}


SECRETS_FILE=${2}
#SECRETS_FILE=./secrets.env

SECRET_NAME=${3}


if [ -z "${NAMESPACE}" ] ; then
  echo "Namespace name was not provided. Exiting ..."
  echo

  exit 1
else
  echo "Namespace was found and is set to '${NAMESPACE}'. Using '${NAMESPACE}' namespace to create the secret ..."
  echo
  NAMESPACE_OPTION="-n ${NAMESPACE}"
fi 



if [ -z "${SECRETS_FILE}" ] ; then
  echo "Name of secrets file was not provided. Exiting ..."
  echo

  exit 1
else
  echo "Name of secrets file is '${SECRETS_FILE}'."
  echo

fi 


if [ -z "${SECRET_NAME}" ] ; then
  echo "Name of the secret being created is required. Exiting ..."
  echo

  exit 1
else
  echo "SECRET_NAME was found set to '${SECRET_NAME}'. Using '${SECRET_NAME}' as name of the secret ..."
  echo
fi 


if [ ! -r ${SECRETS_FILE} ]; then
  echo "File ${SECRETS_FILE} could not be read, exiting ..."
  exit 1
else
  echo "${SECRETS_FILE} was found."
  echo
fi

source  ${SECRETS_FILE}

K8S_SECRET_NAME=${SECRET_NAME}


# First delete existing secret:

kubectl ${NAMESPACE_OPTION} delete secret ${K8S_SECRET_NAME} || true


kubectl ${NAMESPACE_OPTION} create secret generic ${K8S_SECRET_NAME} \
  --from-literal=DB_USERNAME=${DB_USERNAME} \
  --from-literal=DB_PASSWORD=${DB_PASSWORD}
  

# The secrets.env file has the following format/values:
# DB_USERNAME=username
# DB_PASSWORD=secretpassword

