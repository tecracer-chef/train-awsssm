lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "train-awsssm/version"

Gem::Specification.new do |spec|
  spec.name          = "train-awsssm"
  spec.version       = TrainPlugins::AWSSSM::VERSION
  spec.authors       = ["Thomas Heinen"]
  spec.email         = ["theinen@tecracer.de"]
  spec.summary       = "Train Transport for AWS Systems Manager Agents"
  spec.description   = "Train plugin to use the AWS Systems Manager Agent to execute commands on machines without SSH/WinRM "
  spec.homepage      = "https://github.com/tecracer_theinen/train-awsssm"
  spec.license       = "Apache-2.0"

  spec.files = %w{
    README.md train-awsssm.gemspec Gemfile
  } + Dir.glob(
    "lib/**/*", File::FNM_DOTMATCH
  ).reject { |f| File.directory?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "train", "~> 2.0"
  spec.add_dependency "aws-sdk-ec2", "~> 1.129"
  spec.add_dependency "aws-sdk-ssm", "~> 1.69"

  spec.add_development_dependency "bump", "~> 0.8"
end
