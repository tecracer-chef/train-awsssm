require "aws-sdk-ec2"
require "aws-sdk-ssm"
require "resolv"
require "train"

module TrainPlugins
  module AWSSSM
    class Connection < Train::Plugins::Transport::BaseConnection
      attr_reader :instance_id, :options
      attr_writer :ssm, :ec2, :instances

      def initialize(options)
        super(options)

        check_options
      end

      def close
        logger.info format("[AWS-SSM] Closed connection to %s", options[:host])
      end

      def uri
        "aws-ssm://#{options[:host]}/"
      end

      def run_command_via_connection(cmd, &data_handler)
        logger.info format("[AWS-SSM] Sending command to %s", options[:host])
        exit_status, stdout, stderr = execute_on_channel(cmd, &data_handler)

        CommandResult.new(stdout, stderr, exit_status)
      end

      def file_via_connection(path)
        windows_instance? ? Train::File::Remote::Windows.new(self, path) : Train::File::Remote::Unix.new(self, path)
      end

      def execute_on_channel(cmd, &data_handler)
        logger.debug format("[AWS-SSM] Command: '%s'", cmd)

        result = execute_command(options[:host], cmd)

        stdout = result.standard_output_content || ""
        stderr = result.standard_error_content || ""
        exit_status = result.response_code

        [exit_status, stdout, stderr]
      end

      private

      # Return Systems Manager API client
      #
      # @return Aws::SSM::Client
      def ssm
        @ssm ||= ::Aws::SSM::Client.new
      end

      # Return EC2 API client
      #
      # @return Aws::EC2::Client
      def ec2
        @ec2 ||= ::Aws::EC2::Client.new
      end

      # Check if options are as needed
      #
      # @raise [ArgumentError] if any options were incorrectly configured
      def check_options
        unless options[:host]
          raise ArgumentError, format("Missing required option :host for train-awsssm")
        end

        unless supported_modes.include? options[:mode]
          raise ArgumentError, format("Wrong mode `%s`, supported: %s", options[:mode], supported_modes.join(", "))
        end

        address = options[:host]
        @instance_id = address.start_with?("i-") ? address : resolve_instance_id(address)

        raise ArgumentError, format("Instance %s is not running", instance_id) unless instance_running?
        raise ArgumentError, format("Instance %s is not managed by SSM or agent unreachable", instance_id) unless managed_instance?
      end

      # Resolve EC2 instance ID associated with a primary IP or a DNS entry
      #
      # @param [String] address Host or IP address
      # @return [String] Instance ID, if any
      # @raise [ArgumentError] if instance could not be resolved from address
      def resolve_instance_id(address)
        logger.debug format("[AWS-SSM] Trying to resolve address %s", address)

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

        raise ArgumentError, format("Could not resolve instance ID for address %s", address) if id.nil?

        logger.debug format("[AWS-SSM] Resolved address %s to instance ID %s", address, id)

        id
      rescue ::Aws::Errors::ServiceError => e
        raise ArgumentError, format("Error looking up Instance ID for %s: %s", address, e.message)
      end

      # List up EC2 instances in the account.
      #
      # @param [Boolean] cache Cache results
      # @return [Array] List of instances
      # @todo Implement paging
      def instances(caching: true)
        return @instances unless @instances.nil? || !caching

        results = []

        ec2_instances = ec2.describe_instances(max_results: options[:instance_pagesize])
        loop do
          results.concat ec2_instances.reservations.map(&:instances).flatten

          break unless ec2_instances.next_token

          ec2_instances = ec2.describe_instances(max_results: options[:instance_pagesize], next_token: ec2_instances.next_token)
        end

        @instances = results
      end

      # Check if this is an IP address
      #
      # @param [String] address Host, IP address or other input
      # @return [Boolean] If it is an IPv4 address
      def ip_address?(address)
        !!(address =~ Resolv::IPv4::Regex)
      end

      # Check if this is a DNS name
      #
      # @param [String] address Host, IP address or other input
      # @return [Boolean] If it is a DNS name
      def dns_name?(address)
        !ip_address?(address)
      end

      # Check if this is an internal/external AWS DNS entry
      #
      # @param [String] address Host, IP address or other input
      # @return [Boolean] If it is an Amazon-provided DNS name
      def amazon_dns?(dns)
        dns_name?(dns) && (dns.end_with?(".compute.amazonaws.com") || dns.end_with?(".compute.internal"))
      end

      # Request a command invocation and wait until it is registered with an ID
      #
      # @param [String] command_id Command ID from SSM
      def wait_for_invocation(command_id)
        invocation_result(command_id)

      # Retry until the invocation was created on AWS
      rescue ::Aws::SSM::Errors::InvocationDoesNotExist
        sleep options[:recheck_invocation]
        retry
      end

      # Return the result of a given command invocation
      #
      # @param [String] command_id Command ID from SSM
      # @return [Aws::SSM::Types::GetCommandInvocationResult] Invocation result
      def invocation_result(command_id)
        ssm.get_command_invocation(instance_id: instance_id, command_id: command_id)
      end

      # Return if a non-terminal command status was given
      #
      # @param [String] name status from invocation
      # @return [Boolean] If execution is still in progress
      # @see https://docs.aws.amazon.com/systems-manager/latest/userguide/monitor-commands.html
      def in_progress?(name)
        %w{Pending InProgress Delayed}.include? name
      end

      # Return if a terminal command status was given
      #
      # @param [String] name status from invocation
      # @return [Boolean] If execution is finished, aborted or timed out
      # @see https://docs.aws.amazon.com/systems-manager/latest/userguide/monitor-commands.html
      def terminal_state?(name)
        !in_progress?(name)
      end

      # Execute a command via SSM
      #
      # @param [String] address IP, Host or Instance ID
      # @param [String] command Command to execute
      # @return [Aws::SSM::Types::GetCommandInvocationResult] Invocation result
      # @raise [ArgumentError] if instance is not reachable
      # @raise [RuntimeError] if execution failed or timed out
      def execute_command(address, command)
        ssm_document = windows_instance? ? "AWS-RunPowerShellScript" : "AWS-RunShellScript"

        cmd = ssm.send_command(instance_ids: [instance_id], document_name: ssm_document, parameters: { "commands": [command] })
        cmd_id = cmd.command.command_id

        wait_for_invocation(cmd_id)
        logger.debug format("[AWS-SSM] Execution ID %s", cmd_id)

        start_time = Time.now
        result = invocation_result(cmd.command.command_id)

        until terminal_state?(result.status) || Time.now - start_time > options[:execution_timeout]
          result = invocation_result(cmd.command.command_id)
          sleep options[:recheck_execution]
        end

        if Time.now - start_time > options[:execution_timeout]
          raise format("Timeout waiting for execution")
        elsif !%w{Success Failed}.include? result.status
          # Failing commands is normal for InSpec
          raise format('Execution failed with state "%s": %s', result.status, result.standard_error_content || "unknown")
        end

        result
      end

      # Check if instance is Windows based.
      # Could also use the `train.connection.platform` mechanics, but they are very slow.
      #
      # @return [Boolean] If this is a Windows instance
      def windows_instance?
        ec2_instance_data.platform == "windows"
      end

      # Check if instance is running.
      #
      # @param [String] instance_id EC2 instance ID
      # @return [Boolean] If the instance is currently running
      def instance_running?
        ec2_instance_data.state.name == "running"
      end

      # Check if instance is reachable via SSM.
      #
      # @param [String] instance_id EC2 instance ID
      # @return [Boolean] If the instance is reachable
      def managed_instance?
        instance = ssm_instance_data
        return false unless instance

        instance.ping_status == "Online"
      end

      # Get instance data from SSM
      #
      # @param [String] instance_id EC2 instance ID
      # @return [Aws::SSM::Types::InstanceInformation] Available SSM instance data
      # @raise [ArgumentError] if instance ID could not be found
      def ssm_instance_data
        response = ssm.describe_instance_information(filters: [{ key: "InstanceIds", values: [instance_id] }])

        response.instance_information_list&.first
      rescue ::Aws::Errors::ServiceError => e
        raise ArgumentError, format("Error looking up SSM-managed instance %s: %s", instance_id, e.message)
      end

      # Get instance data from EC2
      #
      # @param [String] instance_id EC2 instance ID
      # @return [Aws::EC2::Types::Instance] Available instance data
      # @raise [ArgumentError] if instance ID could not be found
      def ec2_instance_data
        instances = ec2.describe_instances(instance_ids: [instance_id])

        instances.reservations.first.instances.first
      rescue ::Aws::Errors::ServiceError => e
        raise ArgumentError, format("Error looking up Instance %s: %s", instance_id, e.message)
      end

      # Supported run modes.
      #
      # @return [Array<String>] Supported modes
      def supported_modes
        %w{run-command}
      end
    end
  end
end
