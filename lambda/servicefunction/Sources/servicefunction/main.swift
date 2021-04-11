import AWSLambdaRuntime

Lambda.run { ServiceHandler(context: $0) }

