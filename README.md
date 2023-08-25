# train-awsssm - Train Plugin for using AWS Systems Manager Agent

This plugin allows applications that rely on Train to communicate via AWS SSM with Linux/Windows instances.

## Requirements

The instance in question must run on AWS and you need to have all AWS credentials set up for the shell which executes the command. Please check the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) for appropriate configuration files and environment variables.

You need the [SSM agent to be installed](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) on the machine (most current AMIs already have this integrated) and the machine needs to have the managed policy `AmazonSSMManagedInstanceCore` or a least privilege equivalent attached as IAM profile.

Commands will be executed under the `root`/`Administrator` users.

To confirm or troubleshoot the aws-ssm connection, reference the troubleshooting steps in [this AWS article](https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-managed-instances.html#instances-missing-solution-1).

## Installation

If you use this Gem as a plain transport you can use `gem install train-awsssm` but if you need it for InSpec you will need to do it via `inspec plugin install train-awsssm`, as InSpec does not use the global/user Gem directory by default.

You can build and install this gem on your local system as well via a Rake task: `rake install:local`.

## Transport parameters

| Option               | Explanation                                       | Default          |
| -------------------- | ------------------------------------------------- | ---------------- |
| `host`               | IP, DNS name or EC2 ID of instance                | (required)       |
| `mode`               | Mode for connection, only 'run-command' currently | run-command      |
| `execution_timeout`  | Maximum time until timeout                        | 60               |
| `recheck_invocation` | Interval of rechecking AWS command invocation     | 1.0              |
| `recheck_execution`  | Interval of rechecking completion of command      | 1.0              |
| `instance_pagesize`  | Paging size for EC2 instance retrieval            | 100              |

## Limitations

Currently, this transport is limited to executing commands via the `AWS-RunShellScript` command which means there is no file upload/download capability.

Support for proper use of the AWS Session Manager, which allows complete tunneling, is planned.

## Example use

### In Code

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

### Using the InSpec CLI

```bash
# Using aws-instance-id
inspec exec <path-to-profile> --target awsssm://<aws-instance-id>
# Or use target IP
inspec exec <path-to-profile> --target awsssm://<aws-target-ip>

# Examples
inspec exec https://github.com/mitre/redhat-enterprise-linux-7-stig-baseline/archive/main.tar.gz --target awsssm://i-00f1868f8f3b4eb03
inspec exec https://github.com/mitre/redhat-enterprise-linux-7-stig-baseline/archive/main.tar.gz --target awsssm://10.20.30.40
```
