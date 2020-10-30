# train-awsssm - Train Plugin for using AWS Systems Manager Agent

This plugin allows applications that rely on Train to communicate via AWS SSM with Linux instances.

Windows is currently not yet supported

## Requirements

The instance in question must run on AWS and you need to have all AWS credentials set up for the shell which executes the command. Please check the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) for appropriate configuration files and environment variables.

You need the [SSM agent to be installed](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) on the machine (most current AMIs already have this integrated) and the machine needs to have the managed policy `AmazonSSMManagedInstanceCore` or a least privilege equivalent attached as IAM profile.

Commands will be executed under the `root` user.

## Installation

If you use this Gem as a plain transport you can use `gem install train-awsssm` but if you need it for InSpec you will need to do it via `inspec plugin install train-awsssm`, as InSpec does not use the global/user Gem directory by default.

You can build and install this gem on your local system as well via a Rake task: `rake install:local`.

## Transport parameters

| Option               | Explanation                                   | Default          |
| -------------------- | --------------------------------------------- | ---------------- |
| `host`               | IP, DNS name or EC2 ID of instance            | (required)       |
| `execution_timeout`  | Maximum time until timeout                    | 60               |
| `recheck_invocation` | Interval of rechecking AWS command invocation | 1.0              |
| `recheck_execution`  | Interval of rechecking completion of command  | 1.0              |

## Limitations

Currently, this transport is limited to executing commands via the `AWS-RunShellScript` command which means there is no file upload/download capability.

Support for proper use of the AWS Session Manager, which allows complete tunneling, is planned.

## Example use

```ruby
require "train-awsssm"
train  = Train.create("awsssm", {
            host:     "172.16.3.12",
            logger:   Logger.new($stdout, level: :info)
         })
conn   = train.connection
result = conn.run_command("apt upgrade -y")
conn.close
```
