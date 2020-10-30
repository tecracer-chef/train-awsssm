require "aws-sdk-ec2"
require "aws-sdk-ssm"
require "resolv"
require "train"

module TrainPlugins
  module AWSSSM
    class Connection < Train::Plugins::Transport::BaseConnection
      def initialize(options)
        super(options)

        check_options

        @ssm = Aws::SSM::Client.new
      end

      def close
        logger.info format("[AWS-SSM] Closed connection to %s", @options[:host])
      end

      def uri
        "aws-ssm://#{@options[:host]}/"
      end

      def run_command_via_connection(cmd, &data_handler)
        logger.info format("[AWS-SSM] Sending command to %s", @options[:host])
        exit_status, stdout, stderr = execute_on_channel(cmd, &data_handler)

        CommandResult.new(stdout, stderr, exit_status)
      end

      def execute_on_channel(cmd, &data_handler)
        logger.debug format("[AWS-SSM] Command: '%s'", cmd)

        result = execute_command(@options[:host], cmd)

        stdout = result.standard_output_content || ""
        stderr = result.standard_error_content || ""
        exit_status = result.response_code

        [exit_status, stdout, stderr]
      end

      private

      # Check if this is an IP address
      def ip_address?(address)
        !!(address =~ Resolv::IPv4::Regex)
      end

      # Check if this is a DNS name
      def dns_name?(address)
        !ip_address?(address)
      end

      # Check if this is an internal/external AWS DNS entry
      def amazon_dns?(dns)
        dns.end_with?(".compute.amazonaws.com") || dns.end_with?(".compute.internal")
      end

      # Resolve EC2 instance ID associated with a primary IP or a DNS entry
      def instance_id(address)
        logger.debug format("[AWS-SSM] Trying to resolve address %s", address)

        ec2 = Aws::EC2::Client.new
        instances = ec2.describe_instances.reservations.collect { |r| r.instances.first }

        # Resolve, if DNS name and not Amazon default
        if dns_name?(address) && !amazon_dns?(address)
          address = Resolv.getaddress(address)
          logger.debug format("[AWS-SSM] Resolved non-internal AWS address to %s", address)
        end

        # Check the primary IPs and hostnames for a match
        id = instances.detect do |i|
          [
            i.private_ip_address,
            i.public_ip_address,
            i.private_dns_name,
            i.public_dns_name,
          ].include?(address)
        end&.instance_id

        raise format("Could not resolve instance ID for address %s", address) if id.nil?

        logger.debug format("[AWS-SSM] Resolved address %s to instance ID %s", address, id)
        id
      end

      # Request a command invocation and wait until it is registered with an ID
      def wait_for_invocation(instance_id, command_id)
        invocation_result(instance_id, command_id)

      # Retry until the invocation was created on AWS
      rescue Aws::SSM::Errors::InvocationDoesNotExist
        sleep @options[:recheck_invocation]
        retry
      end

      # Return the result of a given command invocation
      def invocation_result(instance_id, command_id)
        @ssm.get_command_invocation(instance_id: instance_id, command_id: command_id)
      end

      # Return if a non-terminal command status was given
      # @see https://docs.aws.amazon.com/systems-manager/latest/userguide/monitor-commands.html
      def in_progress?(name)
        %w{Pending InProgress Delayed}.include? name
      end

      # Return if a terminal command status was given
      # @see https://docs.aws.amazon.com/systems-manager/latest/userguide/monitor-commands.html
      def terminal_state?(name)
        !in_progress?(name)
      end

      # Execute a command via SSM
      def execute_command(address, command)
        instance_id = if address.start_with? "i-"
                        address
                      else
                        instance_id(address)
                      end

        cmd = @ssm.send_command(instance_ids: [instance_id], document_name: "AWS-RunShellScript", parameters: { "commands": [command] })
        cmd_id = cmd.command.command_id

        wait_for_invocation(instance_id, cmd_id)
        logger.debug format("[AWS-SSM] Execution ID %s", cmd_id)

        start_time = Time.now
        result = invocation_result(instance_id, cmd.command.command_id)

        until terminal_state?(result.status) || Time.now - start_time > @options[:execution_timeout]
          result = invocation_result(instance_id, cmd.command.command_id)
          sleep @options[:recheck_execution]
        end

        if Time.now - start_time > @options[:execution_timeout]
          raise format("Timeout waiting for execution")
        elsif result.status != "Success"
          raise format('Execution failed with state "%s": %s', result.status, result.standard_error_content || "unknown")
        end

        result
      end

      # Check if options are as needed
      def check_options
        unless options[:host]
          raise format("Missing required option :host for train-awsssm")
        end
      end
    end
  end
end
