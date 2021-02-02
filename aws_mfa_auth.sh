#! /bin/bash
#
# Author: Jack Goodacre
# Date:   02/02/2021
#
# Usage:  ./aws_mfa_auth.sh
# Notes:  Populate below defaults for a smoother ride
####

# Defaults
personalMfaArn="arn:aws:iam::123456789:mfa/iamUserName"
defaultIamRoleArn="arn:aws:iam::123456789:role/iamRoleName"
defaultProfileName="profileName"
defaultAwsRegion="eu-west-2"

# Collect MFA Token
read -p "Enter MFA Token: " mfaToken

if [[ ! "$mfaToken" =~ ^[0-9]{6}$ ]]
then 
  echo "Invalid MFA Token Supplied" && exit 
fi

# Collect MFA Device ARN
read -p "Enter MFA Device ARN [$personalMfaArn]: " mfaArn
: ${mfaArn:=$personalMfaArn}

if [[ ! $mfaArn =~ ^arn:aws:iam::.*mfa/.+$ ]]
then 
  echo "Likely Invalid MFA Device ARN Value Set" && exit
fi

# Collect IAM Role ARN
read -p "Enter IAM Role ARN [$defaultIamRoleArn]: " IamRoleArn
: ${IamRoleArn:=$defaultIamRoleArn}

if [[ ! $IamRoleArn =~ ^arn:aws:iam::.*role/.+$ ]] 
then
  echo "Likely invalid IAM Role ARN Value Set" && exit
fi

# Collect IAM Role Profile Name
read -p "Enter Profile Name for $IamRoleArn [$defaultProfileName]: " profileName
: ${profileName:=$defaultProfileName}

if [ -z $profileName ] 
then
  echo "Profile Name Cannot be null" && exit
fi

# Collect Preferred Default Region
read -p "Enter Preferred Default Region for $IamRoleArn IAM Role [$defaultAwsRegion]: " AwsRegion
: ${AwsRegion:=$defaultAwsRegion}

# Borked regex for AWS regions
#if [[ ! $defaultAwsRegion =~ ^(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\d$ ]] 
#then 
  #echo "Likely Invalid AWS Region Value Set - Check Script Defaults" && exit
#fi


# Get Tokens via AWSCLI
echo -e "\nGetting Session Token..." && response=`aws sts get-session-token --serial-number $personalMfaArn --token-code $mfaToken`

if [[ `jq '.Credentials.SessionToken' <<< "$response"` != null ]]
then 
  echo -e "\nSetting AWS root Profile Values:"
  aws configure set aws_access_key_id `jq -r '.Credentials.AccessKeyId' <<< "$response"` --profile root && echo "Set aws_access_key_id in ~/.aws/credentials"
  aws configure set aws_secret_access_key `jq -r '.Credentials.SecretAccessKey' <<< "$response"` --profile root && echo "Set aws_secret_access_key in ~/.aws/credentials"
  aws configure set aws_session_token `jq -r '.Credentials.SessionToken' <<< "$response"` --profile root && echo "Set aws_session_token in ~/.aws/credentials"
  echo -e "\nMFA Token Expiry: `jq -r '.Credentials.Expiration' <<< "$response"`"
else
  echo -e "\nResponse from sts get-session-token invalid - Check input parameters & retry"
fi

# Configure IAM Role Switch Profile for DPE
echo -e "\nSetting AWSCLI dpe profile config"
aws configure set role_arn $IamRoleArn --profile $profileName
aws configure set source_profile root --profile $profileName
aws configure set region $AwsRegion --profile $profileName
echo -e "\n :) \n"  

exit