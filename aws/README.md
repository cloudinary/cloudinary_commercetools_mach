# commercetools Cloudinary MACH extension on AWS

These instructions walk you through configuring Amazon AWS to host the serverless microservice that integrates Cloudinary assets in your commercetools instance.

## Installation
See [AWS installation documentation](https://cloudinary.com/documentation/commercetools_installation#amazon_aws).

### Next steps
Create your secrets:
* `aws secretsmanager create-secret --name cloud-api-secret --secret-string $CloudinaryApiSecret`
* `aws secretsmanager create-secret --name ct-client-secret --secret-string $CommercetoolsApiSecret`

Build & deploy your stack:
* `sam build --use-container`
* `sam deploy --guided`

## AWS resources flow
 - webhook -> Api Gateway (AWS managed)
 - Api Gateway -> [auth] SQS
 - SQS [auth] <- AWS Lambda
 - AWS Lambda -> [auth] Get Secrets from SM & process data
