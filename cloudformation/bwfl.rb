
CloudFormation do
  Description("Bees with Frickin Laserbeams")
  AWSTemplateFormatVersion("2010-09-09")
  
 Parameter("StatusS3BucketName") do
    Description("Bucket name for status page")
    Type("String")
    Default("camm-beeswithfrickinlaserbeams")
  end
  
  Parameter("InstanceVPC") do
    Description("Target VPC ID for drones")
    Type("AWS::EC2::VPC::Id")
  end

  Parameter("InstanceType") do
    Type "String"
    Description "Instance Type for drones"
    Default "t2.micro"
  end

  Parameter("Revision") do
    Type "String"
    Description "Used to force cloudformation to reevaluate changes"
    Default "5"
  end

  Parameter("InstanceSubnets") do
    Description("Comma separated set of subnets for drones")
    Type("List<AWS::EC2::Subnet::Id>")
    Default("subnet-gggggggg,subnet-hhhhhhhh,subnet-iiiiiiii")
    ConstraintDescription("Must be a list of valid existing Subnet IDs expressed as as 'subnet-gggggggg,subnet-hhhhhhhh'")
  end

  Parameter("InstanceAMI") do
    Type "AWS::EC2::Image::Id"
    Description "AMI for drones"
    Default "ami-992d1afa"
  end

  EC2_SecurityGroup("InstanceSecurityGroup") do
    Property("GroupDescription", "The security group for drones")
    Property("VpcId", Ref("InstanceVPC"))
    Property("Tags", [
      {
        "Key"   => "Name",
        "Value" => "BWFL"
      }
    ])
  end
  
  EC2_SecurityGroupIngress("InstanceAccessSSHCIDR") do
    Property("IpProtocol", "tcp")
    Property("FromPort", "22")
    Property("ToPort", "22")
    Property("CidrIp", "0.0.0.0/0")
    Property("GroupId", FnGetAtt("InstanceSecurityGroup", "GroupId"))
  end

  IAM_InstanceProfile("InstanceProfile") do
    Property("Roles", [ Ref("InstanceRole") ] )
    Property("Path", "/Drone/" )
  end


  IAM_Role("InstanceRole") do
    Property("AssumeRolePolicyDocument", JSON.parse(File.read("#{$policy_dir}/ec2-assume-role.json")))
    Property("Path", "/")
    Property("ManagedPolicyArns", [
      "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
      "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    ])
    Property("Policies", [
      {
        "PolicyName" => "DronePolicy_S3",
        "PolicyDocument" => {
          "Statement" => [ 
            {
              "Action"   => "s3:ListAllMyBuckets",
              "Effect"   => "Allow",
              "Resource" => "*"
            },
            {
              "Action"   => [ "s3:*"],
              "Effect"   => "Allow",
              "Resource" => [ FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName"), "/*" ]), FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName")]) ]
            }
          ]
        }
      }
    ])
  end

  IAM_User("WebSDKUser") do
    Policies([
      {
      "PolicyName" => "WebSDKUser",
      "PolicyDocument" => {
         "Version" => "2012-10-17",
         "Statement" => [ 
          {
            "Effect" => "Allow",
            "Action" => [ "s3:List*", "s3:get*" ],
            "Resource" => [ 
              FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName") ]), 
              FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName"), "/*" ])
            ]
          },{
            "Effect" => "Allow",
            "Action" => [ "autoscaling:Describe*" ],
            "Resource" => "*"
          },{
            "Effect" => "Allow",
            "Action" => [ "lambda:Invoke*" ],
            "Resource" => [ FnGetAtt("BeesUp", "Arn"), FnGetAtt("BeesDown", "Arn"), FnGetAtt("BeesLaunch", "Arn") ]
          } 
         ]
        }
      }
    ] )
  end

  IAM_AccessKey("WebSDKAccessKey") do
    Property("UserName", Ref("WebSDKUser"))
  end

  Lambda_Function("CreateS3File") do
    DependsOn(["LambdaExecutionRole"])
    Description("Function to create a *small* file in an S3 bucket")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat(File.read("#{$lambda_dir}/create_s3_file.js"),
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region")
      ) 
    })
  end

  Lambda_Function("CreateS3FileFromHTTPS") do
    DependsOn(["LambdaExecutionRole"])
    Description("Function to create a file in an S3 bucket from an HTTPS URL")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat(File.read("#{$lambda_dir}/create_s3_file_get_https.js"),
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region")
      ) 
    })
  end

  Resource("InitialStatusPage") do
    DependsOn("WebSDKAccessKey")
    Type("Custom::InitialStatusPage")
    Property("ServiceToken", FnGetAtt("CreateS3File", "Arn"))
    Property("StackName", Ref("AWS::StackName"))
    Property("Region", Ref("AWS::Region"))
    Property("Bucket", Ref("StatusS3Bucket"))
    Property("ContentType", "text/html")
    Property("Body", FnFormat(File.read("index.html"),
        :accesskey => Ref("WebSDKAccessKey"),
        :secretkey => FnGetAtt("WebSDKAccessKey", "SecretAccessKey"),
        :asg => Ref("AutoScalingGroup"),
        :swarmattack => Ref("BeesLaunch"),
        :swarmup => Ref("BeesUp"),
        :swarmdown => Ref("BeesDown")
    ))
    Property("Key", "index.html")
  end

  Resource("JSDateLib") do
    Type("Custom::InitialStatusPage")
    Property("ServiceToken", FnGetAtt("CreateS3FileFromHTTPS", "Arn"))
    Property("StackName", Ref("AWS::StackName"))
    Property("Region", Ref("AWS::Region"))
    Property("Host", "raw.githubusercontent.com")
    Property("Port", "443")
    Property("Path", "datejs/Datejs/master/build/date-en-AU.js")
    Property("Bucket", Ref("StatusS3Bucket"))
    Property("ContentType", "text/javascript")
    Property("Key", "date-en-AU.js")
  end

  Lambda_Permission("AllowBeesUp") do
    Property("FunctionName", FnGetAtt("BeesUp", "Arn"))
    Property("Principal", "*")
    Property("Action", "lambda:InvokeFunction")
  end

  Lambda_Function("BeesUp") do
    DependsOn(["LambdaExecutionRole"])
    Description("Scale up a swarm")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat(File.read("#{$lambda_dir}/swarm_up.js"),
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region"),
      :asg => Ref("AutoScalingGroup"),
      :swarmup => Ref("BeesUp")
      ) 
    })
  end

  Lambda_Function("BeesDown") do
    DependsOn(["LambdaExecutionRole"])
    Description("Scale down a swarm")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat(File.read("#{$lambda_dir}/swarm_down.js"),
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region"),
      :swarmdown => Ref("BeesDown"),
      :asg => Ref("AutoScalingGroup"),
      ) 
    })
  end

  Lambda_Permission("AllowBeesDown") do
    Property("FunctionName", FnGetAtt("BeesDown", "Arn"))
    Property("Principal", "*")
    Property("Action", "lambda:InvokeFunction")
  end

  Lambda_Function("BeesLaunch") do
    DependsOn(["LambdaExecutionRole"])
    Description("Attttaaaaaaaaaaaaaccckk!")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat(File.read("#{$lambda_dir}/swarm_attack.js"),
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region"),
      :asg => Ref("AutoScalingGroup"),
      :ssmdoc => Ref("SSMDocument"),
      :ssmrole => FnGetAtt("SSMExecutionRole", "Arn"),
      :outputbucket => Ref("StatusS3Bucket"),
      :notiftopic => Ref("StatusSNSTopic") 
      ) 
    })
  end

  S3_Bucket("StatusS3Bucket") do
    DeletionPolicy "Retain"
    AccessControl "BucketOwnerFullControl"
    VersioningConfiguration({ "Status" => "Enabled"})
    Property("BucketName", Ref("StatusS3BucketName"))
    Property("WebsiteConfiguration", { "IndexDocument" => "index.html" })
  end

  S3_BucketPolicy("StatusS3BucketPolicy") do    
    Property("Bucket", Ref("StatusS3BucketName"))   
    Property("PolicyDocument", {    
      "Statement" => [ 
        {   
          "Action"    => [ "s3:GetObject" ],    
          "Effect"    => "Allow",   
          "Principal" => "*",
          "Sid"       => "ReadStatusPage",
          "Resource"  => FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName"), "/*" ])
        }
     ]   
    })    
  end

  AutoScaling_AutoScalingGroup("AutoScalingGroup") do
    DependsOn(["LaunchConfig","StatusSNSTopic"])
    Property("NotificationConfigurations", [
  	  {
  		"NotificationTypes" => [
  		  "autoscaling:EC2_INSTANCE_LAUNCH",
  		  "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
  		  "autoscaling:EC2_INSTANCE_TERMINATE",
  		  "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  		  "autoscaling:TEST_NOTIFICATION"
  		],
  		"TopicARN" => Ref("StatusSNSTopic")
	  }])
    Cooldown 60
    HealthCheckGracePeriod 60
    LaunchConfigurationName Ref("LaunchConfig")
    MinSize 0
    DesiredCapacity 0
    MaxSize 0
    VPCZoneIdentifier Ref("InstanceSubnets")
#    SubnetIdentifiers FnGetAZs( Ref("AWS::Region") )


    Tags [
      {
        :Key   => "Name",
        :PropagateAtLaunch => true,
        :Value => "Drones"
      }
    ]
  end

  AutoScaling_LaunchConfiguration("LaunchConfig") do
    DependsOn(["InstanceProfile", "InstanceSecurityGroup"])
    ImageId Ref("InstanceAMI")
    IamInstanceProfile Ref("InstanceProfile")
    SecurityGroups [ Ref("InstanceSecurityGroup") ]
    InstanceType Ref("InstanceType")
    KeyName "bees"
  end

  Resource("SSMDocument") do
    Type("AWS::SSM::Document")
    Property("Content", FnFormat(File.read("#{$ssmdoc_dir}/apachebench.json")))
  end

  Lambda_Function("SnsMessageEvent") do
    DependsOn(["LambdaExecutionRole"])
    Description("Function to pull SNS message")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat( 
      File.read("#{$lambda_dir}/mo_process_sns.js") ,
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region"), 
      :bucket => Ref("TransferS3BucketName"), 
      :tableName => Ref("StatusTable"),
      :snsTopic => Ref("StatusSNSTopic") 
      ) 
    })
  end

  Lambda_Permission("AllowSnsMessageEvent") do
    DependsOn(["SnsMessageEvent","StatusSNSTopic"])
    Property("FunctionName", FnGetAtt("SnsMessageEvent", "Arn"))
    Property("Principal", "sns.amazonaws.com")
    Property("Action", "lambda:InvokeFunction")
    # have to hand-craft an ARN as the bucket wont (and can't) yet exist
    Property("SourceArn", Ref("StatusSNSTopic"))
  end

  Lambda_Function("UpdateStatusPage") do
    DependsOn(["LambdaExecutionRole"])
    Description("Function to update status page with data from Dynamo DB")
    Property("Handler", "index.handler")
    Property("Runtime", "nodejs4.3")
    Property("Timeout", "30")
    Property("Role", FnGetAtt("LambdaExecutionRole", "Arn"))
    Property("Code", { "ZipFile" => FnFormat( 
      File.read("#{$lambda_dir}/mo_process_status.js") ,
      :stackname => Ref("AWS::StackName"), 
      :region => Ref("AWS::Region"), 
      :bucket => Ref("StatusS3BucketName"), 
      :tableName => Ref("StatusTable")
      ) 
    })
  end

  Lambda_EventSourceMapping("UpdateStatusEventSourceMapping") do
    DependsOn("UpdateStatusPage")
    Property("BatchSize", 100)
    Property("Enabled", true)
    Property("EventSourceArn", FnGetAtt("StatusTable", "StreamArn"))
    Property("FunctionName", FnGetAtt("UpdateStatusPage", "Arn"))
    Property("StartingPosition", "LATEST")
  end

  IAM_Role("SSMExecutionRole") do
    Property("AssumeRolePolicyDocument", JSON.parse(File.read("#{$policy_dir}/ssm-notif-trust.json")))
    Property("Path", "/")
    Property("ManagedPolicyArns", ["arn:aws:iam::aws:policy/AmazonSNSFullAccess"])
    Property("Policies", [ {
      "PolicyName" => "SSMExecution",
      "PolicyDocument" => {
        "Version" => "2012-10-17",
        "Statement" => [ 
          {   
            "Action"    => [ "s3:PutObject" ],    
            "Effect"    => "Allow",   
            "Sid"       => "PutLogs",
            "Resource"  => FnJoin("", [ "arn:aws:s3:::", Ref("StatusS3BucketName"), "logs/*" ])
          }
        ]
      }
      }])
  end

  IAM_Role("LambdaExecutionRole") do
    Property("AssumeRolePolicyDocument", JSON.parse(File.read("#{$policy_dir}/lambda-assume-role.json")))
    Property("Path", "/")
    Property("Policies", [
      JSON.parse(File.read("#{$policy_dir}/cloudwatch-logging.json")),
      {
        "PolicyDocument" => {
          "Statement" => [
            {
              "Action" => [
                "cloudformation:*",
                "lambda:*",
                "autoscaling:*",
                "s3:*",
                "dynamodb:*",
                "iam:PassRole",
                "sns:*",
                "ec2:*",
                "ssm:*"
              ],
              "Effect" => "Allow",
              "Resource" => "*"
            }
          ],
          "Version" => "2012-10-17"
        },
        "PolicyName" => "LambdaExecution"
      }
  ])
  end

  DynamoDB_Table("StatusTable") do
    Property("StreamSpecification", { "StreamViewType" => "KEYS_ONLY" })
    Property("AttributeDefinitions", [
      {
        "AttributeName" => "runName",
        "AttributeType" => "S"
      },
      {
        "AttributeName" => "timeStamp",
        "AttributeType" => "S"
      }
#      ,
#      {
#        "AttributeName" => "ssmCommandId",
#        "AttributeType" => "S"
#      },
#      {
#        "AttributeName" => "targetUrl",
#        "AttributeType" => "S"
#      },
#      {
#        "AttributeName" => "totalRequests",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "concurrency",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "completeRequests",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "failedRequests",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "totalTransferredBytes",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "timePerRequest",
#        "AttributeType" => "N"
#      },
#      {
#        "AttributeName" => "timePerRequestConcurrent",
#        "AttributeType" => "N"
#      }
    ])
    Property("KeySchema", [
      {
        "AttributeName" => "runName",
        "KeyType" => "HASH"
      },
      {
        "AttributeName" => "timeStamp",
        "KeyType" => "RANGE"
      }
    ])
    Property("ProvisionedThroughput", {
      "ReadCapacityUnits" => 10,
      "WriteCapacityUnits" => 10
    })
  end

  SNS_Topic("StatusSNSTopic") do
    DependsOn("SnsMessageEvent")
    Property("Subscription", [
      {
        "Endpoint" => FnGetAtt("SnsMessageEvent", "Arn"),
        "Protocol" => "lambda"
      }
    ])
  end

  Output("StatusPageURL") do
    Description("Status Page URL")
    Value( FnJoin("", [ "https://s3-", Ref("AWS::Region"), ".amazonaws.com/", Ref("StatusS3BucketName"), "/index.html" ] ))
  end
end
