#!/usr/bin/env node
import 'source-map-support/register'
import * as cdk from '@aws-cdk/core'
import { DevhrProjectCicdInfraStack } from '../lib/devhr-project-cicd-infra'

const app = new cdk.App()
new DevhrProjectCicdInfraStack(app, 'DevhrProjectCicdInfraStack')

app.synth()