# commercetools Cloudinary MACH integration on GCP

These instructions walk you through configuring Google Cloud Platform to host the serverless microservice that integrates Cloudinary assets in your commercetools instance.

## Installation
See [GCP installation documentation](https://cloudinary.com/documentation/commercetools_installation#gcp).

### Next steps

# GCP resources config

Update scripts/settings/commercetools.json
 - CloudRunName - represents API id, Cloud Run API endpoint for webhook, pushes messages to PUB/SUB topic, hidden behind API Gateway, auth required (internal)
 - CloudRunSubscriberName - represents API id, Cloud Run API for internal use, receives push messages from PUB/SUB, auth required (internal)
 - Topic - PUB/SUB topic id
 - PubsubSubscription - Subscription Id, used by Subscriber Cloud Run API
 - PubsubInvokerSAName - Service Account used for authentication to Subscriber Cloud Run API, Pub/Sub push -> API
 - PubsubPublisherSAName - Service Account used for authentication to publishing messages to Topic
 - SecretAccessorSAName - Service Account used for accessing secrets from Secret Manager
 - ApiGatewaySAName - Service Account used for accessing Cloud Run API endpoint for webhook by Api Gateway
 - OpenApiSpec - file name of Api Gateway config spec
 - ApiGatewayConfigId - Api Gateway config id
 - ApiGatewayId - Api Gateway id

 > :warning: **Before running deployment scripts, ensure calling user has necessary permissions: Project IAM Admin rights, Cloud Run Admin for cloud run, Pub/Sub Admin, Secret Manager Admin, Api Gateway Admin**

 > :warning: **Before running deploy-step4 (Api Gateway setup), update openapi2-run.yaml with title:CloudRunName and address:url endpoint of CloudRunName**

# Powershell deployment scripts

* `deploy-step1.ps1`
* `deploy-step2.ps1`
* `deploy-step3.ps1`
* `deploy-step4.ps1`

 # GCP resources flow

 - webhook -> Api Gateway
 - Api Gateway -> [auth] Cloud Run
 - Cloud run -> [auth] PUB/SUB Topic
 - PUB/SUB Topic -> Subscription
 - Subscription -> [auth] Cloud Run (Subscriber): \
    failure: after 5 failures message is passed to $Topic-dead-letter \
    success: Cloud Run (Subscriber) -> [auth] Get Secrets from SM & process data

 # GCP endpoint for webhook

 Endpoint from Api Gateway is provided in console after running setup with deploy-step4 or can be viewed under https://console.cloud.google.com/api-gateway/gateway/$ApiGatewayId/location/$Region?project=$ProjectId
