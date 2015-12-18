require 'rspec'

RSpec.configure do |conf|
  conf.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }
end