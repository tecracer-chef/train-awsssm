lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "train-awsssm/version"

Gem::Specification.new do |spec|
  spec.name          = "train-awsssm"
  spec.version       = TrainPlugins::AWSSSM::VERSION
  spec.authors       = ["Thomas Heinen"]
  spec.email         = ["theinen@tecracer.de"]
  spec.summary       = "Train Transport for AWS Systems Manager Agents"
  spec.description   = "Train plugin to use the AWS Systems Manager Agent to execute commands on machines without SSH/WinRM"
  spec.homepage      = "https://github.com/tecracer-chef/train-awsssm"
  spec.license       = "Apache-2.0"

  spec.files         = Dir["lib/**/**/**"]
  spec.files        += ["README.md", "CHANGELOG.md"]

  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.6"

  spec.add_development_dependency "bump", "~> 0.10"
  spec.add_development_dependency "chefstyle", "~> 2.0"
  spec.add_development_dependency "guard", "~> 2.17"
  spec.add_development_dependency "mdl", "~> 0.11"
  spec.add_development_dependency "rake", "~> 13.0"
end
