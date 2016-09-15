'use strict';
console.log('Loading function');
let AWS = require('aws-sdk'); 
AWS.config.region = '%{region}';
exports.handler = (event, context, callback) => {
//console.log('Received event:', JSON.stringify(event, null, 2));
 event.Records.forEach((record) => {
  console.log(record.eventID);
  console.log(record.eventName);
  console.log('DynamoDB Record: %j', record.dynamodb);
 });      
 var dynamodb = new AWS.DynamoDB({apiVersion: '2012-08-10'});
 var dbparams = {
  TableName:'%{tableName}'
 }
 dynamodb.scan(dbparams, function(err, data) {            
  if (err) console.log(err, err.stack); // an error occurred 
  else {
   console.log(data);
   var htmlData = '<html><table id="table"><thead><style>table, th, td {border: 1px solid black;border-collapse: collapse;} th, td {padding: 5px;text-align: left;}</style>';
   htmlData = htmlData + '<tr><th style=\'width: 200px;\'>Account Name</th><th style=\'width: 200px;\'>Date</th><th style=\'width: 200px;\' >Process Name</th><th style=\'width: 300px;\'>Status</th></tr></thead><tbody>';
   htmlData = htmlData + '<script src="https://code.jquery.com/jquery-2.1.0.js"></script>'
   htmlData = htmlData + '<input type="text" id="search" placeholder="Type to search">'
   for (var i =0; i < data.Items.length; i++) {
        var backgroundcolor = "";
        if (data.Items[i].moStatus.S.indexOf('Failed') > -1) {
            backgroundcolor ="red";
        }
        
        htmlData = htmlData + '<tr style=\'background-color: ' + backgroundcolor + ';\'><td>' + data.Items[i].accountName.S + '</td>'+'<td>' + data.Items[i].timeStamp.S + '</td>'+'<td>' + data.Items[i].processName.S + '</td>'+'<td>' + data.Items[i].moStatus.S + '</td></tr>';
   }
   htmlData = htmlData + '<script type="text/javascript">'
   htmlData = htmlData + '     var $rows = $(\'#table tr\').not(\'thead tr\');'
   htmlData = htmlData + '     $(\'#search\').keyup(function() {'
   htmlData = htmlData + '         var val = $.trim($(this).val()).replace(/ +/g, \' \').toLowerCase();'
   htmlData = htmlData + '        $rows.show().filter(function() {'
   htmlData = htmlData + '         var text = $(this).text().replace(/\s+/g, \' \').toLowerCase();'
   htmlData = htmlData + '       return !~text.indexOf(val);'
   htmlData = htmlData + '         }).hide();'
   htmlData = htmlData + '     });'
   htmlData = htmlData + '    </script>'
   htmlData = htmlData + '</tbody></table>';
   htmlData = htmlData + '<p>Last Updated at ' + new Date();
    var s3 = new AWS.S3();
    var s3params = {Bucket: '%{bucket}', Key: 'status.html', Body: htmlData, ContentType: 'text/html'}
    s3.putObject(s3params, function(err, data) {
     if (err) console.log(err, err.stack); // an error occurred
     else     console.log(data);           // successful response
    });
 }
 }); 
callback(null, 'done');
};