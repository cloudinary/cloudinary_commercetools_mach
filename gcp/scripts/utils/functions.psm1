#logged user requires Project IAM Admin rights, Cloud Run Admin for cloud run, Pub/Sub Admin, Secret Manager Admin

function setupGcloudCli {
    (New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe") 
    & $env:Temp\GoogleCloudSDKInstaller.exe
}

function SignIn {
    gcloud init
}

function UpdateComponents {
    gcloud components update
}

function ProjectExists {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId
    )

    $count = gcloud projects list --sort-by=$ProjectId --limit=1

    return $count -gt 0
}

function CreateProject {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectName,

        [Parameter(Mandatory = $True)]        
        [string]
        $OrganizationId
    )

    gcloud projects create $ProjectId --enable-cloud-apis --name=$ProjectName --organization=$OrganizationId --set-as-default
}

function SetDefaults {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $Region
    )

    gcloud config set project $ProjectId
    gcloud config set run/region $Region
}

function EnablePubSub {
    gcloud services enable pubsub.googleapis.com
}

function EnableSecretManager {
    gcloud services enable secretmanager.googleapis.com
}

function EnableApiGateway {
    gcloud services enable apigateway.googleapis.com
    gcloud services enable servicemanagement.googleapis.com
    gcloud services enable servicecontrol.googleapis.com
}

function CreatePubSubTopic {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $Topic
    )

    gcloud pubsub topics create $Topic
}

function TopicExists {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $Topic
    )

    $count = gcloud pubsub topics list --filter="name.scope(topic):'$Topic'"

    return $count -gt 0
}

function GetProjectNumber {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId
    )

    $ProjectExists = ProjectExists -ProjectId $ProjectId

    if ($ProjectExists) {
        $projectNumber = gcloud projects list --sort-by=$ProjectId --limit=1 --format='value(projectNumber)'
        
        return $projectNumber
    }
    else {
        return
    }
}

function GetServiceUrl {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $AppName,

        [Parameter(Mandatory = $True)]        
        [string]
        $Region
    )

    $url = gcloud run services describe $AppName --platform managed --region $Region --format 'value(status.url)'

    return $url
}

function CreatePubSubSubscription {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]
        [string]
        $ServiceUrl,
        
        [Parameter(Mandatory = $True)]
        [string]
        $PubsubInvokerSAName,

        [Parameter(Mandatory = $True)]
        [string]
        $Topic,

        [Parameter(Mandatory = $True)]        
        [string]
        $PubsubSubscription,

        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectNumber
    )

    gcloud pubsub subscriptions create $PubsubSubscription --topic $Topic --ack-deadline=600 --push-endpoint="$ServiceUrl/ProcessCloudinaryNotification" --push-auth-service-account="$PubsubInvokerSAName@$ProjectId.iam.gserviceaccount.com" --min-retry-delay=60 --max-retry-delay=600 --enable-message-ordering
    
    # handle dead letter messages
    CreatePubSubTopic -Topic $Topic-dead-letter
    gcloud pubsub subscriptions update $PubsubSubscription --dead-letter-topic=$Topic-dead-letter --max-delivery-attempts=5 --dead-letter-topic-project=$ProjectId
    $pubsubServiceAccount = "service-$ProjectNumber@gcp-sa-pubsub.iam.gserviceaccount.com"
    gcloud pubsub topics add-iam-policy-binding $Topic-dead-letter --member="serviceAccount:$pubsubServiceAccount" --role="roles/pubsub.publisher"
    gcloud pubsub subscriptions add-iam-policy-binding $PubsubSubscription --member="serviceAccount:$pubsubServiceAccount" --role="roles/pubsub.subscriber"
}

function SetupPubSub {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $Region,

        [Parameter(Mandatory = $True)]        
        [string]
        $Topic,

        [Parameter(Mandatory = $True)]        
        [string]
        $PubsubInvokerSAName,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName, # subscriber app

        [Parameter(Mandatory = $True)]        
        [string]
        $PubsubSubscription
    )

    $TopicExists = TopicExists -Topic $Topic

    if (!$TopicExists) {
        Write-Host "Creating Pub/Sub topic"

        CreatePubSubTopic -Topic $Topic
    }
    else {
        Write-Host "Topic $Topic already exists"
    }

    $projectNumber = GetProjectNumber -ProjectId $ProjectId

    gcloud iam service-accounts create $PubsubInvokerSAName --display-name="Cloud Run Pub/Sub Invoker"
    gcloud run services add-iam-policy-binding $AppName --member=serviceAccount:"$PubsubInvokerSAName@$ProjectId.iam.gserviceaccount.com" --role=roles/run.invoker
    gcloud projects add-iam-policy-binding $ProjectId --member=serviceAccount:"service-$projectNumber@gcp-sa-pubsub.iam.gserviceaccount.com" --role=roles/iam.serviceAccountTokenCreator

    $serviceUrl = GetServiceUrl -AppName $AppName -Region $Region

    CreatePubSubSubscription -ProjectId $ProjectId -ServiceUrl $serviceUrl -PubsubInvokerSAName $PubsubInvokerSAName -Topic $Topic -PubsubSubscription $PubsubSubscription -ProjectNumber $projectNumber
}

function SetupPublisherSA {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName,

        [Parameter(Mandatory = $True)]        
        [string]
        $PubsubPublisherSAName,

        [Parameter(Mandatory = $True)]        
        [string]
        $Topic
    )
    
    gcloud iam service-accounts create $PubsubPublisherSAName --display-name="Cloud Run Pub/Sub Publisher"
    gcloud pubsub topics add-iam-policy-binding $Topic --member=serviceAccount:"$PubsubPublisherSAName@$ProjectId.iam.gserviceaccount.com" --role=roles/pubsub.publisher
    gcloud run services update $AppName --service-account "$PubsubPublisherSAName@$ProjectId.iam.gserviceaccount.com"
}

function SetupApiGatewaySA {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName,

        [Parameter(Mandatory = $True)]        
        [string]
        $ApiGatewaySAName
    )

    gcloud iam service-accounts create $ApiGatewaySAName --display-name="Gateway manager for Cloud Run"
    gcloud run services add-iam-policy-binding $AppName --member="serviceAccount:$ApiGatewaySAName@$ProjectId.iam.gserviceaccount.com" --role=roles/run.invoker
}

function SetupApiGateway {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $Region,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName,

        [Parameter(Mandatory = $True)]        
        [string]
        $ApiGatewaySAName,

        [Parameter(Mandatory = $True)]        
        [string]
        $OpenApiSpec,

        [Parameter(Mandatory = $True)]        
        [string]
        $ApiGatewayConfigId,

        [Parameter(Mandatory = $True)]        
        [string]
        $ApiGatewayId
    )

    gcloud api-gateway api-configs create $ApiGatewayConfigId --api=$AppName --openapi-spec=$OpenApiSpec --project=$ProjectId --backend-auth-service-account="$ApiGatewaySAName@$ProjectId.iam.gserviceaccount.com"
    gcloud api-gateway api-configs describe $ApiGatewayConfigId --api=$AppName --project=$ProjectId

    gcloud api-gateway gateways create $ApiGatewayId --api=$AppName --api-config=$ApiGatewayConfigId --location=$Region --project=$ProjectId
    gcloud api-gateway gateways describe $ApiGatewayId --location=$Region --project=$ProjectId

    $gatewayUrl = gcloud api-gateway gateways describe $ApiGatewayId --location=$Region --project=$ProjectId --format 'value(defaultHostname)'

    Write-StartText "Gateway url: $gatewayUrl"
}

# cloud run
function BuildContainer {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName
    )

    gcloud builds submit --tag gcr.io/$ProjectId/$AppName
}

# function CreateContinuousDeploymentTempl {
#     param(
#         [Parameter(Mandatory = $True)]        
#         [string]
#         $ProjectId,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $AppName,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Region,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $TemplPath
#     )

#     $templSetup =
#     "steps:
#     # Build the container image
#     - name: 'gcr.io/cloud-builders/docker'
#       args: ['build', '-t', 'gcr.io/$ProjectId/$($AppName):`$COMMIT_SHA', '.']
#     # Push the container image to Container Registry
#     - name: 'gcr.io/cloud-builders/docker'
#       args: ['push', 'gcr.io/$ProjectId/$($AppName):`$COMMIT_SHA']
#     # Deploy container image to Cloud Run
#     - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
#       entrypoint: gcloud
#       args:
#       - 'run'
#       - 'deploy'
#       - '$AppName'
#       - '--image'
#       - 'gcr.io/$ProjectId/$($AppName):`$COMMIT_SHA'
#       - '--region'
#       - '$Region'
#     images:
#     - 'gcr.io/$ProjectId/$($AppName):`$COMMIT_SHA'"
    
#     Clear-Content -Path $TemplPath
#     $templSetup | out-file -filepath $TemplPath
# }

# # Continuous deployment
# function CreateBuildTrigger {
#     param(
#         [Parameter(Mandatory = $True)]        
#         [string]
#         $RepositoryOwner,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Repository,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Region,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Branch,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $TemplPath
#     )

#     gcloud beta builds triggers create github --region=$Region --repo-name=$Repository --repo-owner=$RepositoryOwner --branch-pattern=$Branch --build-config=$TemplPath
# }

# cloud run
function DeployApp {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $AppName,

        [Parameter(Mandatory = $True)]        
        [bool]
        $RequireAuth,

        [Parameter(Mandatory = $True)]        
        [string]
        $EnvVars
    )

    if ($RequireAuth) {
        gcloud run deploy $AppName --image gcr.io/$ProjectId/$AppName --no-allow-unauthenticated --set-env-vars $EnvVars
    }
    else {
        gcloud run deploy $AppName --image gcr.io/$ProjectId/$AppName --allow-unauthenticated --set-env-vars $EnvVars
    }
}

function CreateSecret {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $SecretId
    )

    gcloud secrets create $SecretId --replication-policy="automatic"
}

function CreateSecretVersion {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $SecretId,

        [Parameter(Mandatory = $True)]        
        [string]
        $SecretValue
    )

    $SecretValue | gcloud secrets versions add $SecretId --data-file=-
}

function GetSercretVersion {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $SecretId,

        [Parameter(Mandatory = $True)]        
        [string]
        $Version
    )

    gcloud secrets versions access $Version --secret=$SecretId
}

function SetupSecretManagerSA {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $SecretAccessorSAName,
        
        [Parameter(Mandatory = $True)]        
        [string]
        $AppName
    )
    
    gcloud iam service-accounts create $SecretAccessorSAName --display-name="Cloud Run Secret Accessor"
    gcloud run services update $AppName --service-account "$SecretAccessorSAName@$ProjectId.iam.gserviceaccount.com"
}

function AssignSASecretAccess {
    param(
        [Parameter(Mandatory = $True)]        
        [string]
        $ProjectId,

        [Parameter(Mandatory = $True)]        
        [string]
        $SecretAccessorSAName,

        [Parameter(Mandatory = $True)]        
        [string]
        $SecretId
    )

    $projectNumber = GetProjectNumber -ProjectId $ProjectId
    gcloud secrets add-iam-policy-binding $SecretId --member="serviceAccount:$projectNumber-compute@developer.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"
    gcloud secrets add-iam-policy-binding $SecretId --member="serviceAccount:$SecretAccessorSAName@$ProjectId.iam.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"
    gcloud secrets add-iam-policy-binding $SecretId --member="serviceAccount:$SecretAccessorSAName@$ProjectId.iam.gserviceaccount.com" --role="roles/viewer"
    gcloud secrets add-iam-policy-binding $SecretId --member="serviceAccount:$SecretAccessorSAName@$ProjectId.iam.gserviceaccount.com" --role="roles/secretmanager.viewer"
}

# # cloud functions
# function DeployTemplate {
#     param(
#         [Parameter(Mandatory = $True)]        
#         [string]
#         $ProjectId,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $FunctionsName,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Region,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Topic,

#         [Parameter(Mandatory = $True)]        
#         [string]
#         $PubsubSubscription,
        
#         [Parameter(Mandatory = $True)]        
#         [string]
#         $Deployment
#     )

#     gcloud deployment-manager deployments create $Deployment --template deploy-init.jinja --properties region:$Region, project:$ProjectId, topic:$Topic, pubsubSubscription:$PubsubSubscription, deployment:$Deployment, functionsName:$FunctionsName
# }

function Write-StartText {
    param (
        [string] [Parameter(Mandatory = $true)] $Text
    )

    Write-Host "--- $Text" -ForegroundColor Blue
}

function Write-Done {
    Write-Host "--- Done" -ForegroundColor Green
    Write-Host
}

function Get-Settings {
    param (
        [string] [Parameter(Mandatory = $true)] $fileName
    )

    $RootFolder = "$($PSScriptRoot)\..\..\"
    return Get-Content -Raw -Path ($RootFolder + "/scripts/settings/" + $fileName + ".json") | ConvertFrom-Json
}