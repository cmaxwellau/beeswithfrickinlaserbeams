var aws = require('aws-sdk');
var response = require('cfn-response');
var https = require('https');

exports.handler = function(event, context) {
  aws.config.region = event.ResourceProperties.Region;
  console.log(JSON.stringify(event));
  if ((event.RequestType == 'Create') || (event.RequestType == 'Update')) {
    var S3 = new aws.S3();


    var params = {
      Bucket: event.ResourceProperties.Bucket,
      Key: event.ResourceProperties.Key,
      Body: "body",
      ACL:  event.ResourceProperties.ACL,
      ContentType: event.ResourceProperties.ContentType,
      GrantRead: event.ResourceProperties.GrantRead
    };

    S3.upload(params, function(e, data) {
      if (e) {
        response.send(event, context, response.FAILED, e);
        console.log(e);
        return;
      }
    });
  }
  response.send(event, context, response.SUCCESS);
  return;
};