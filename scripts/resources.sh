#!/bin/sh

USER_POOL_NAME="ImageRekognitionUserPool"
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 5 --query UserPools[?Name==\`${USER_POOL_NAME}\`].Id --output text | tr -d \")
echo "USER_POOL_ID=${USER_POOL_ID}"

APP_CLIENT_NAME="ImageRekognitionUserPoolClient"
APP_CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id ${USER_POOL_ID} --query UserPoolClients[?ClientName==\`${APP_CLIENT_NAME}\`].ClientId --output text | tr -d \")
echo "APP_CLIENT_ID=${APP_CLIENT_ID}"

APP_CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client --user-pool-id ${USER_POOL_ID} --client-id ${APP_CLIENT_ID} --query UserPoolClient.ClientSecret --output text)
echo "APP_CLIENT_SECRET=${APP_CLIENT_SECRET}"

IDENTITY_POOL_NAME="ImageRekognitionIdentityPool"
IDENTITY_POOL_ID=$(aws cognito-identity list-identity-pools --max-results 5 --query IdentityPools[?IdentityPoolName==\`${IDENTITY_POOL_NAME}\`].IdentityPoolId --output text | tr -d \")
echo "IDENTITY_POOL_ID=${IDENTITY_POOL_ID}"

API_NAME="imageAPI"
REST_API_ID=$(aws apigateway get-rest-apis --query items[?name==\`${API_NAME}\`].id --output text | tr -d \")
ENDPOINT=https://${REST_API_ID}.execute-api.eu-west-1.amazonaws.com/prod
echo "API available at: ${ENDPOINT}"
