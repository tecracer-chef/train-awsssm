# train-awsssm - Train Plugin for using AWS Systems Manager Agent

This plugin allows applications that rely on Train to communicate via AWS SSM.

## Requirements

The instance in question must run on AWS and you need to have all AWS credentials
set up for the shell which executes the command. Please check the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
for appropriate configuration files and environment variables.

You need the [SSM agent to be installed](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) on the machine (most current AMIs already
have this integrated) and the machine needs to have the managed policy
`AmazonSSMManagedInstanceCore` or a least privilege equivalent attached as
IAM profile.

Commands will be executed under the `ssm-user` user.

## Installation

You will have to build this gem yourself to install it as it is not yet on
Rubygems.Org. For this there is a rake task which makes this a one-liner:

```bash
rake install:local
```

## Transport parameters

| Option               | Explanation                                   | Default          |
| -------------------- | --------------------------------------------- | ---------------- |
| `host`               | IP or DNS name of instance                    | (required)       |
| `execution_timeout`  | Maximum time until timeout                    | 60               |
| `recheck_invocation` | Interval of rechecking AWS command invocation | 1.0              |
| `recheck_execution`  | Interval of rechecking completion of command  | 1.0              |

## Example use

```ruby
require "train-awsssm"
train  = Train.create("awsssm", {
            host:     '172.16.3.12',
            logger:   Logger.new($stdout, level: :info)
         })
conn   = train.connection
result = conn.run_command("apt upgrade -y")
conn.close
```
