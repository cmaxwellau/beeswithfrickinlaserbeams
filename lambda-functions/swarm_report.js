var aws=require('aws-sdk');
var cfnsvc=new aws.CloudFormation();
var asgsvc=new aws.AutoScaling();
aws.config.region='%{region}';
var sns=new aws.SNS({apiVersion: '2010-03-31'});
var fn='';
exports.handler=function(event,context,cb) {
  event_obj=event.Records[0].s3;
  console.log(JSON.stringify(event_obj));
  kn=event_obj.object.key;
  if(kn.indexOf("-INPUT-")<1){console.log("Bad filename "+kn);process.exit(1);}
  create(kn.substring(kn.lastIndexOf('/')+1).split("-INPUT-")[0],kn);
  cb(null,'Done!');
};
pubSNS = function (sta){
 var mess = '{"AccountName" : "'+fn+'","ProcessName": "Lambda-Input-Processor","Status":"'+ sta + '"}';
 var spa = {Message:mess, TopicArn: '%{snstopic}'};
 sns.publish(spa, function(err, data) {if (err) console.log(err, err.stack);});
};
create=function (c_id,kn){
  fn=kn.substring(kn.lastIndexOf('/')+1).replace("-INPUT-","-");
  res='%{stackname}-'+fn;
  var p={LogicalResourceId:'TemplateASG',StackName:'%{stackname}'};
  cfnsvc.describeStackResource(p,function(e,res_data) {
    if(e){console.log(e,e.stack);process.exit(1);}
    //console.log(JSON.stringify(res_data));
    r_id=res_data.StackResourceDetail.PhysicalResourceId;
    var p={AutoScalingGroupNames:[r_id],MaxRecords:1};
    asgsvc.describeAutoScalingGroups(p,function(e,asg_data) {
      if(e){console.log(e,e.stack);process.exit(1);}
      //console.log(JSON.stringify(asg_data));
      src_asg=asg_data.AutoScalingGroups[0];
      var p={LaunchConfigurationNames:[src_asg.LaunchConfigurationName],MaxRecords:1};
      asgsvc.describeLaunchConfigurations(p,function(e,lc_data){
        if(e){console.log(e,e.stack);process.exit(1);}
        //console.log(JSON.stringify(lc_data));
        var p=lc_data.LaunchConfigurations[0];
        p['LaunchConfigurationName']=res;
         p['UserData']=new Buffer(ud).toString('base64');
        ['LaunchConfigurationARN','CreatedTime','KernelId','RamdiskId'].forEach(function(item,index){ delete p[item];});
        //console.log(JSON.stringify(p));
        asgsvc.deleteLaunchConfiguration({ LaunchConfigurationName: res });
        asgsvc.createLaunchConfiguration(p,function(e,new_lc) {
          if(e){console.log(e,e.stack);process.exit(1);}
          //console.log(JSON.stringify(new_lc));
          var p=asg_data.AutoScalingGroups[0];
          p['AutoScalingGroupName']=res;p['LaunchConfigurationName']=res;
          p['MaxSize']=1;p['MinSize']=1;p['DesiredCapacity']=1;
          p['Tags']=[{Key:'Client',PropagateAtLaunch:true,Value: c_id },{Key:'Name',PropagateAtLaunch:true,Value:res}];
          ['AutoScalingGroupARN','Instances','CreatedTime','SuspendedProcesses','EnabledMetrics'].forEach(function(item,index){ delete p[item];});
          asgsvc.createAutoScalingGroup(p,function(e,data){if(e){console.log(e,e.stack);pubSNS('Failed');process.exit(1);}else{
          var npa = {AutoScalingGroupName: res,NotificationTypes: ['autoscaling:EC2_INSTANCE_LAUNCH','autoscaling:EC2_INSTANCE_LAUNCH_ERROR','autoscaling:EC2_INSTANCE_TERMINATE','autoscaling:EC2_INSTANCE_TERMINATE_ERROR'],TopicARN: '%{snstopic}'};
          asgsvc.putNotificationConfiguration(npa, function(err, data) {if (err) console.log(err, err.stack);});
          pubSNS('Initialised');}});
        });
      });
    });
  });
};