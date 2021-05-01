import * as cdk from '@aws-cdk/core';
import * as codepipeline from '@aws-cdk/aws-codepipeline';
import * as codepipeline_actions from '@aws-cdk/aws-codepipeline-actions';
import * as ecr from '@aws-cdk/aws-ecr';
import * as iam from '@aws-cdk/aws-iam';
import * as pipelines from '@aws-cdk/pipelines';
import { LambdaDeploymentStage } from './lambda-deployment';

export class DevhrProjectCicdInfraStack extends cdk.Stack {
    constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
        super(scope, id, props)

		const sourceArtifact = new codepipeline.Artifact();
        const cdkOutputArtifact = new codepipeline.Artifact();
        
        const pipeline = new pipelines.CdkPipeline(this, 'CdkPipeline', {
            crossAccountKeys: false,
            pipelineName: 'devhr-project-pipeline',
            cloudAssemblyArtifact: cdkOutputArtifact,

            sourceAction: new codepipeline_actions.GitHubSourceAction({
                actionName: 'DownloadSources',
                owner: 'imyrvold',
                repo: 'DevhrProjectCICD',
                branch: 'part4',
                    oauthToken: cdk.SecretValue.secretsManager('github-token'),
                    output: sourceArtifact
            }),

            synthAction: pipelines.SimpleSynthAction.standardNpmSynth({
				sourceArtifact: sourceArtifact,
                cloudAssemblyArtifact: cdkOutputArtifact,
                subdirectory: 'cdk'
            })
        });

        const repository = new ecr.Repository(this, 'Repository', { repositoryName: 'cdk-cicd/devhr-project'});
        const buildRole = new iam.Role(this, 'DockerBuildRole', {
            assumedBy: new iam.ServicePrincipal('codebuild.amazonaws.com')
        });
		repository.grantPullPush(buildRole);
        
        const lambdaStage = new LambdaDeploymentStage(this, 'LambdaDeploymentStage');
        pipeline.addApplicationStage(lambdaStage);
    }
}