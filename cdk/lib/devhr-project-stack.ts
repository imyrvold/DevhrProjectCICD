import * as cdk from '@aws-cdk/core'
import * as s3 from '@aws-cdk/aws-s3'
import * as lambda from '@aws-cdk/aws-lambda'
import * as dynamodb from '@aws-cdk/aws-dynamodb'
import { Duration } from '@aws-cdk/core'
import * as iam from '@aws-cdk/aws-iam'
import * as event_sources from '@aws-cdk/aws-lambda-event-sources'

const imageBucketName = 'cdk-rekn-imagebucket'
const resizedBucketName = imageBucketName + "-resized"

export class DevhrProjectStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props)

    const dockerfile = '../lambda/rekfunction/';

    // =================================================================================
    // Image Bucket
    // =================================================================================
    const imageBucket = new s3.Bucket(this, imageBucketName, {
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'imageBucket', { value: imageBucket.bucketName })

    // =================================================================================
    // Thumbnail Bucket
    // =================================================================================
    const resizedBucket = new s3.Bucket(this, resizedBucketName, {
      removalPolicy: cdk.RemovalPolicy.DESTROY
    })
    new cdk.CfnOutput(this, 'resizedBucket', { value: resizedBucket.bucketName })

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
    });
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
  ​
  // const serviceFn = new lambda.Function(this, 'serviceFunction', {
  //   code: lambda.Code.fromAsset('servicelambda'),
  //   runtime: lambda.Runtime.PYTHON_3_7,
  //   handler: 'index.handler',
  //   environment: {
  //     "TABLE": table.tableName,
  //     "BUCKET": imageBucket.bucketName,
  //     "RESIZEDBUCKET": resizedBucket.bucketName
  //   },
  // });
  // ​
  // imageBucket.grantWrite(serviceFn);
  // resizedBucket.grantWrite(serviceFn);
  // table.grantReadWriteData(serviceFn);


  }
}
