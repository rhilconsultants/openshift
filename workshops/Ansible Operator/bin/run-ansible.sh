#!/bin/bash

ANSIBLE_ENV_VARS=""

if [[ -z "$INVENTORY" ]]; then
	echo "No inventory file provided (environment value INVENTORY)"
	exit 1;
else
	ANSIBLE_ENV_VARS="${ANSIBLE_ENV_VARS} INVENTORY=${INVENTORY}"
fi

if [[ -z "$OPTS" ]]; then
	echo "no OPTS option provided (OPTS environment value)"
else
	ANSIBLE_ENV_VARS="${ANSIBLE_ENV_VARS} OPTS=${OPTS}"

fi 

if [[ -z "$K8S_AUTH_API_KEY" ]]; then 
	echo "No Kubernetes Authentication key provided (K8S_AUTH_API_KEY environment value)"
else 
	ANSIBLE_ENV_VARS="${ANSIBLE_ENV_VARS} K8S_AUTH_API_KEY=${K8S_AUTH_API_KEY}"
fi

if [[ -z "${K8S_AUTH_HOST}" ]]; then
	echo "no Kubernetes API provided (K8S_AUTH_HOST environment value)"
else
	ANSIBLE_ENV_VARS="${ANSIBLE_ENV_VARS}  K8S_AUTH_HOST=${K8S_AUTH_HOST}"
fi

if [[ -z "${K8S_AUTH_VALIDATE_CERTS}" ]]; then
  	echo "No validation flag provided (Default: K8S_AUTH_VALIDATE_CERTS=true)"
else
	ANSIBLE_ENV_VARS="${ANSIBLE_ENV_VARS} K8S_AUTH_VALIDATE_CERTS=${K8S_AUTH_VALIDATE_CERTS}"
fi  

if [[ -z $"$PLAYBOOK_FILE" ]]; then
	echo "No Playbook file provided... exiting"
	exit 1
else	
	$ANSIBLE_ENV_VARS ansible-playbook $PLAYBOOK_FILE
fi