import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import NIO

Lambda.run { ServiceHandler(context: $0) }
