import * as cdk from '@aws-cdk/core';
import { DevhrProjectStack } from './devhr-project-stack';

export class LambdaDeploymentStage extends cdk.Stage {
	constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
		super(scope, id, props);
		
		new DevhrProjectStack(this, 'DevhrProjectStack');
	}
}
