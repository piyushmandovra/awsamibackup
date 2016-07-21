step1: Installation

Install aws cli if not already there
https://github.com/aws/aws-cli


step2: Use profiling

$vi .aws/config

and add following

[profile p-name]
output = table
region = us-east-1

$vi .aws/credentials

and add following

[p-name]
aws_access_key_id = key-id-value
aws_secret_access_key = access-key-value

