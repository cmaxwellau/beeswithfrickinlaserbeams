var aws=require('aws-sdk');
var autoscaling=new aws.AutoScaling();
aws.config.region='%{region}';
exports.handler=function(event,context,cb) {
  console.log(JSON.stringify(event));
  var params = {
    AutoScalingGroupName: '%{asg}',
    DesiredCapacity: 0,
    MaxSize: 0,
    MinSize: 0,
  };
  autoscaling.updateAutoScalingGroup(params, function(err, data) {
    if (err) console.log(err, err.stack);
    else console.log(data);
  });
};
