import * as cdk from '@aws-cdk/core'
import * as s3 from '@aws-cdk/aws-s3'
import * as lambda from '@aws-cdk/aws-lambda'
import * as dynamodb from '@aws-cdk/aws-dynamodb'
import { Duration } from '@aws-cdk/core'
import * as iam from '@aws-cdk/aws-iam'
import * as event_sources from '@aws-cdk/aws-lambda-event-sources'
import * as cognito from '@aws-cdk/aws-cognito'
import * as apigw from '@aws-cdk/aws-apigateway'
import { AuthorizationType, PassthroughBehavior } from '@aws-cdk/aws-apigateway'
import { CfnOutput } from '@aws-cdk/core'

const imageBucketName = 'cdk-rekn-imagebucket'
const resizedBucketName = imageBucketName + "-resized"

export class DevhrProjectStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props)

    const dockerfile = '../lambda/rekfunction/';
    const serviceDockerfile = '../lambda/servicefunction/';

    // =================================================================================
    // Image Bucket
    // =================================================================================
    const imageBucket = new s3.Bucket(this, imageBucketName, {
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'imageBucket', { value: imageBucket.bucketName })
    const imageBucketArn = imageBucket.bucketArn;

    // =================================================================================
    // Thumbnail Bucket
    // =================================================================================
    const resizedBucket = new s3.Bucket(this, resizedBucketName, {
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'resizedBucket', { value: resizedBucket.bucketName })
    const resizedBucketArn = resizedBucket.bucketArn;

    // =================================================================================
    // Amazon DynamoDB table for storing image labels
    // =================================================================================
    const table = new dynamodb.Table(this, 'ImageLabels', {
      tableName: 'ImageLabels',
      partitionKey: { name: 'image', type: dynamodb.AttributeType.STRING },
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'ddbTable', { value: table.tableName })

    // =================================================================================
    // Building our AWS Lambda Function; compute for our serverless microservice
    // =================================================================================
    const rekFn = new lambda.DockerImageFunction(this, 'recognitionFunction', {
      functionName: 'recognitionFunction',
      code: lambda.DockerImageCode.fromImageAsset(dockerfile),
      environment: {
        'TABLE': table.tableName,
        'BUCKET': imageBucket.bucketName,
        'THUMBBUCKET': resizedBucket.bucketName
      },
      timeout: Duration.seconds(30)
    })
    rekFn.addEventSource(new event_sources.S3EventSource(imageBucket, { events: [s3.EventType.OBJECT_CREATED] }))
    imageBucket.grantRead(rekFn)
    resizedBucket.grantPut(rekFn)
    resizedBucket.grantPutAcl(rekFn)
    table.grantWriteData(rekFn)

    rekFn.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['rekognition:DetectLabels'],
      resources: ['*']
    }))

    // =====================================================================================
    // Lambda for Synchronous Front End
    // =====================================================================================
  ​  const serviceFn = new lambda.DockerImageFunction(this, 'serviceFunction', {
      functionName: 'serviceFunction',
      code: lambda.DockerImageCode.fromImageAsset(serviceDockerfile),
      environment: {
        'TABLE': table.tableName,
        'BUCKET': imageBucket.bucketName,
        'THUMBBUCKET': resizedBucket.bucketName
      },
      timeout: Duration.seconds(30)
    })

    imageBucket.grantWrite(serviceFn);
    resizedBucket.grantWrite(serviceFn);
    table.grantReadWriteData(serviceFn);

    const api = new apigw.LambdaRestApi(this, 'imageAPI', {
      defaultCorsPreflightOptions: {
        allowOrigins: apigw.Cors.ALL_ORIGINS,
        allowMethods: apigw.Cors.ALL_METHODS
      },
      handler: serviceFn,
      proxy: false
    })

    // =====================================================================================
    // This construct builds a new Amazon API Gateway with AWS Lambda Integration
    // =====================================================================================
    const lambdaIntegration = new apigw.LambdaIntegration(serviceFn, {
      proxy: false,
      requestParameters: {
        'integration.request.querystring.action': 'method.request.querystring.action',
        'integration.request.querystring.key': 'method.request.querystring.key'
      },
      requestTemplates: {
        'application/json': JSON.stringify({ action: "$util.escapeJavaScript($input.params('action'))", key: "$util.escapeJavaScript($input.params('key'))" })
      },
      passthroughBehavior: PassthroughBehavior.WHEN_NO_TEMPLATES,
      integrationResponses: [
        {
          statusCode: "200",
          responseParameters: {
            // We can map response parameters
            // - Destination parameters (the key) are the response parameters (used in mappings)
            // - Source parameters (the value) are the integration response parameters or expressions
            'method.response.header.Access-Control-Allow-Origin': "'*'"
          }
        },
        {
          // For errors, we check if the error message is not empty, get the error data
          selectionPattern: "(\n|.)+",
          statusCode: "500",
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': "'*'"
          }
        }
      ],
    })

    // =====================================================================================
    // Cognito User Pool Authentication
    // =====================================================================================
    const userPool = new cognito.UserPool(this, "ImageRekognitionUserPool", {
      userPoolName: "ImageRekognitionUserPool",
      selfSignUpEnabled: true, // Allow users to sign up
      autoVerify: { email: true }, // Verify email addresses by sending a verification code
      signInAliases: { username: true, email: true }, // Set email as an alias
    })

    const userPoolClient = new cognito.UserPoolClient(this, "ImageRekognitionUserPoolClient", {
      userPoolClientName: "ImageRekognitionUserPoolClient",
      userPool,
      generateSecret: true, // Don't need to generate secret for web app running on browsers
    })

    const identityPool = new cognito.CfnIdentityPool(this, "ImageRekognitionIdentityPool", {
      identityPoolName: "ImageRekognitionIdentityPool",
      allowUnauthenticatedIdentities: false, // Don't allow unathenticated users
      cognitoIdentityProviders: [
        {
        clientId: userPoolClient.userPoolClientId,
        providerName: userPool.userPoolProviderName,
        },
      ],
    })

    const auth = new apigw.CfnAuthorizer(this, 'APIGatewayAuthorizer', {
      name: 'customer-authorizer',
      identitySource: 'method.request.header.Authorization',
      providerArns: [userPool.userPoolArn],
      restApiId: api.restApiId,
      type: AuthorizationType.COGNITO,
    })

    const authenticatedRole = new iam.Role(this, "ImageRekognitionAuthenticatedRole", {
      assumedBy: new iam.FederatedPrincipal(
        "cognito-identity.amazonaws.com",
          {
          StringEquals: {
              "cognito-identity.amazonaws.com:aud": identityPool.ref,
          },
          "ForAnyValue:StringLike": {
            "cognito-identity.amazonaws.com:amr": "authenticated",
          },
        },
        "sts:AssumeRoleWithWebIdentity"
      ),
    })

    // IAM policy granting users permission to upload, download and delete their own pictures
    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        actions: [
          "s3:GetObject",
          "s3:PutObject"
        ],
        effect: iam.Effect.ALLOW,
        resources: [
          imageBucketArn + "/private/${cognito-identity.amazonaws.com:sub}/*",
          imageBucketArn + "/private/${cognito-identity.amazonaws.com:sub}",
          resizedBucketArn + "/private/${cognito-identity.amazonaws.com:sub}/*",
          resizedBucketArn + "/private/${cognito-identity.amazonaws.com:sub}"
        ],
      })
    )

    // IAM policy granting users permission to list their pictures
    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        actions: ["s3:ListBucket"],
        effect: iam.Effect.ALLOW,
        resources: [
          imageBucketArn,
          resizedBucketArn
        ],
        conditions: {"StringLike": {"s3:prefix": ["private/${cognito-identity.amazonaws.com:sub}/*"]}}
      })
    )

    new cognito.CfnIdentityPoolRoleAttachment(this, "IdentityPoolRoleAttachment", {
      identityPoolId: identityPool.ref,
      roles: { authenticated: authenticatedRole.roleArn },
    })

    // Export values of Cognito
    new CfnOutput(this, "UserPoolId", {
      value: userPool.userPoolId,
    })
    new CfnOutput(this, "AppClientId", {
      value: userPoolClient.userPoolClientId,
    })
    new CfnOutput(this, "IdentityPoolId", {
      value: identityPool.ref,
    })


    // =====================================================================================
    // API Gateway
    // =====================================================================================
    const imageAPI = api.root.addResource('images')
    ​
    // GET /images
    imageAPI.addMethod('GET', lambdaIntegration, {
      authorizationType: AuthorizationType.COGNITO,
      authorizer: { authorizerId: auth.ref },
      requestParameters: {
        'method.request.querystring.action': true,
        'method.request.querystring.key': true
      },
      methodResponses: [
        {
          statusCode: "200",
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': true,
          },
        },
        {
          statusCode: "500",
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': true,
          },
        }
      ]
    })
    
    // DELETE /images
    imageAPI.addMethod('DELETE', lambdaIntegration, {
      authorizationType: AuthorizationType.COGNITO,
      authorizer: { authorizerId: auth.ref },
      requestParameters: {
        'method.request.querystring.action': true,
        'method.request.querystring.key': true
      },
      methodResponses: [
        {
          statusCode: "200",
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': true,
          },
        },
        {
          statusCode: "500",
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': true,
          },
        }
      ]
    })
    
  }
}
