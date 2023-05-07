# Commercetools Cloudinary MACH integration on AWS

## Installation
See [link TODO](https://cloudinary.com)

### TL;DR;
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