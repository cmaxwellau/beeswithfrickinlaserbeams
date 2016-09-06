var aws=require('aws-sdk');
var autoscaling=new aws.AutoScaling();
var ssm = new aws.SSM();
aws.config.region='%{region}';

exports.handler=function(event,context,cb) {
  console.log(JSON.stringify(event));
  autoscaling.describeAutoScalingGroups({AutoScalingGroupNames:['%{asg}']},function(err, data) {
    if(!event.testname){console.log("Invalid test name:"+event.testname);return;}
    var instances = data.AutoScalingGroups[0].Instances.map(function(obj){return obj.InstanceId;});
    if(instances.length<1){console.log(instances.length+ " instances in ASG. Exiting");return;}
    var per_i_requests = Math.ceil(event.total / instances.length);
    if(per_i_requests<1){console.log("Invalid requests:"+per_i_requests);return;}
    var per_i_concurrency = Math.ceil(event.concurrent / instances.length);
    if(per_i_concurrency<1){console.log("Invalid requests:"+per_i_concurrency);return;}
    console.log(JSON.stringify(instances));
    var params = {
      DocumentName: '%{ssmdoc}',
      InstanceIds: instances,
      Parameters: {
        target: [event.url],
        requests:[JSON.stringify(per_i_requests)],
        concurrency: [JSON.stringify(per_i_concurrency)]
      },
      ServiceRoleArn: '%{ssmrole}',
      TimeoutSeconds: 180,
      NotificationConfig: {
        NotificationArn: '%{notiftopic}',
        NotificationEvents: ['All'],
        NotificationType: 'Command'
      },
      OutputS3BucketName: '%{outputbucket}',
      OutputS3KeyPrefix: "logs/"+event.testname+"/"
    };
    ssm.sendCommand(params, function(err, data) {
       if (err) {console.log(err, err.stack); return;}
       console.log(data);
    });
    if (err) {console.log(err, err.stack); return;}
  });
};
