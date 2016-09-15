'use strict';
exports.handler = (event, context, callback) => {
    var message = JSON.parse(event.Records[0].Sns.Message);
    var subject = event.Records[0].Sns.Subject;
    console.log('From SNS:', message);
    var SnsPublishTime = event.Records[0].Sns.Timestamp;
    var aws = require('aws-sdk');
    var ddb = new aws.DynamoDB({params: {TableName: '%{tableName}'}});
    var accountName = message.AccountName;
    var timeStamp = SnsPublishTime;
    var processName = message.ProcessName;
    var moStatus = message.Status;
    if (subject !== null && subject.indexOf('Auto Scaling:') >= 0) {
        processName = 'Autoscaling-Group';
        moStatus = message.Description;
        accountName= message.AutoScalingGroupName;
        accountName = accountName.replace("%{stackname}-","");
    }
    var itemParams = {Item: {accountName: {S: accountName},timeStamp: {S: timeStamp}, processName: {S: processName},moStatus: {S: moStatus}  }};
    console.log(itemParams);
    ddb.putItem(itemParams, function() {
        context.done(null,'');
     });
    callback(null, message);
};