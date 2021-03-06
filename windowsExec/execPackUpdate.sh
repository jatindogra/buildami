#!/bin/bash -e

set -o pipefail

export CURR_JOB=$1
export RES_REL=$2
export AMI_ID=$3
export AMI_TYPE=$4
export RES_AWS_CREDS=$5

# since resources here have dashes Shippable replaces them and UPPER cases them
export RES_REL_VER_NAME=$(shipctl get_resource_version_name "$RES_REL")
export RES_REL_VER_NAME_DASH=${RES_REL_VER_NAME//./-}

# Now get AWS keys
export RES_AWS_CREDS_UP=$(echo $RES_AWS_CREDS | awk '{print toupper($0)}')
export RES_AWS_CREDS_INT=$RES_AWS_CREDS_UP"_INTEGRATION"


set_context(){

  # now get the AWS keys
  export AWS_ACCESS_KEY_ID=$(eval echo "$"$RES_AWS_CREDS_INT"_ACCESSKEY")
  export AWS_SECRET_ACCESS_KEY=$(eval echo "$"$RES_AWS_CREDS_INT"_SECRETKEY")


  echo "CURR_JOB=$CURR_JOB"
  echo "RES_REL=$RES_REL"
  echo "RES_AWS_CREDS=$RES_AWS_CREDS"

  echo "RES_REL_VER_NAME=$RES_REL_VER_NAME"
  echo "RES_REL_VER_NAME_DASH=$RES_REL_VER_NAME_DASH"

  echo "RES_AWS_CREDS_UP=$RES_AWS_CREDS_UP"
  echo "RES_AWS_CREDS_INT=$RES_AWS_CREDS_INT"

  echo "REGION=$REGION"
  
  echo "AMI_ID=$AMI_ID"
  echo "AMI_TYPE=$AMI_TYPE"
  echo "WINRM_USERNAME=${#WINRM_USERNAME}" #print only length not value
  echo "WINRM_PASSWORD=${#WINRM_PASSWORD}" #print only length not value
  echo "AWS_ACCESS_KEY_ID=${#AWS_ACCESS_KEY_ID}" #print only length not value
  echo "AWS_SECRET_ACCESS_KEY=${#AWS_SECRET_ACCESS_KEY}" #print only length not value
}

build_ami() {
  echo "-----------------------------------"
  echo "validating AMI template"
  echo "-----------------------------------"

  packer validate -var aws_access_key=$AWS_ACCESS_KEY_ID \
    -var aws_secret_key=$AWS_SECRET_ACCESS_KEY \
    -var REGION=$REGION \
    -var WINRM_USERNAME=$WINRM_USERNAME \
    -var WINRM_PASSWORD=$WINRM_PASSWORD \
    -var AMI_ID=$AMI_ID \
    -var AMI_TYPE=$AMI_TYPE \
    execAMIUpdate.json

  echo "building AMI"
  echo "-----------------------------------"

  packer build -machine-readable -var aws_access_key=$AWS_ACCESS_KEY_ID \
    -var aws_secret_key=$AWS_SECRET_ACCESS_KEY \
    -var REGION=$REGION \
    -var AMI_ID=$AMI_ID \
    -var AMI_TYPE=$AMI_TYPE \
    -var REL_VER=$RES_REL_VER_NAME \
    -var REL_DASH_VER=$RES_REL_VER_NAME_DASH \
    -var WINRM_USERNAME=$WINRM_USERNAME \
    -var WINRM_PASSWORD=$WINRM_PASSWORD \
    execAMIUpdate.json 2>&1 | tee output.txt

  # this is to get the ami from output
  echo versionName=$(cat output.txt | awk -F, '$0 ~/artifact,0,id/ {print $6}' \
    | cut -d':' -f 2) > "$JOB_STATE/$CURR_JOB.env"

  echo "RES_REL_VER_NAME=$RES_REL_VER_NAME" >> /build/state/$CURR_JOB.env
  echo "RES_REL_VER_NAME_DASH=$RES_REL_VER_NAME_DASH" >> /build/state/$CURR_JOB.env
  cat "$JOB_STATE/$CURR_JOB.env"
}

main() {
  set_context
  build_ami
}

main
