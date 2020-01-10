libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "train-awsssm/version"

require "train-awsssm/transport"
require "train-awsssm/connection"
