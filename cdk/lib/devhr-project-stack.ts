import * as cdk from '@aws-cdk/core'
import * as s3 from '@aws-cdk/aws-s3'
import * as lambda from '@aws-cdk/aws-lambda'
import * as dynamodb from '@aws-cdk/aws-dynamodb'
import { Duration } from '@aws-cdk/core'
import * as iam from '@aws-cdk/aws-iam'
import * as event_sources from '@aws-cdk/aws-lambda-event-sources'

const imageBucketName = 'cdk-rekn-imagebucket'

export class DevhrProjectStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props)

    const dockerfile = '../';

    // =================================================================================
    // Image Bucket
    // =================================================================================
    const imageBucket = new s3.Bucket(this, imageBucketName, {
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'imageBucket', { value: imageBucket.bucketName })

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
        'BUCKET': imageBucket.bucketName
      },
      timeout: Duration.seconds(5)
    });
    rekFn.addEventSource(new event_sources.S3EventSource(imageBucket, { events: [s3.EventType.OBJECT_CREATED] }))
    imageBucket.grantRead(rekFn)
    table.grantWriteData(rekFn)

    rekFn.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['rekognition:DetectLabels'],
      resources: ['*']
    }))
  }
}
