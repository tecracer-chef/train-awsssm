require "train-awsssm/connection"

module TrainPlugins
  module AWSSSM
    class Transport < Train.plugin(1)
      name "awsssm"

      option :host,               required: true
      option :mode,               default: "run-command"

      option :execution_timeout,  default: 60.0
      option :recheck_invocation, default: 1.0
      option :recheck_execution,  default: 1.0

      def connection(_instance_opts = nil)
        @connection ||= TrainPlugins::AWSSSM::Connection.new(@options)
      end
    end
  end
end
