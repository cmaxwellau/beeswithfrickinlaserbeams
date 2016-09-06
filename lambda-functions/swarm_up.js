var aws=require('aws-sdk');
var autoscaling=new aws.AutoScaling();
aws.config.region='%{region}';
exports.handler=function(event,context,cb) {
  console.log(JSON.stringify(event));
  if (!(event > 0 && event < 20)){
    console.log('Must be an integer between 1 and 20!');
    return;
  }
  asgsize=event;
  var params = {
    AutoScalingGroupName: '%{asg}',
    DesiredCapacity: asgsize,
    MaxSize: asgsize,
    MinSize: asgsize,
  };
  autoscaling.updateAutoScalingGroup(params, function(err, data) {
    if (err) console.log(err, err.stack);
    else console.log(data);
  });
};
