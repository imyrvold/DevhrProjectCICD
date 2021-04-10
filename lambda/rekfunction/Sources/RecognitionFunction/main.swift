import AWSLambdaRuntime

Lambda.run { RekHandler(context: $0) }

