# beeswithfrickinlaserbeams
This repo is a demonstration of what can be achieved with CloudFormation and CFNDSL when using multiple AWS Services, in particular Lambda, AutoScaling, Javascript SDK and SSM.

I wrote it to be a substitute for bees with machine guns without the SSH.

Two cool features are the Lambda functions to create a file in an S3 bucket from scratch, and another to create one from a wget :)

It is definitely not to be used in a production situation! You have full responsibility for how you use it

# Requirements
cfndsl
rake
aws cll

# Building
Clone this repo
cd into cloudformation
rake

# Deploying 
Create your stack from the json output

# Security Features
There are really any.... this is a PoC

# Warranty
No warranty of any sort provided, implied nor offered. But feel free to raise an issue :D

camm@amazon.com
