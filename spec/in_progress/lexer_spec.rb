require_relative '../../lexer'
require_relative '../spec_helper'

RSpec.describe Mint::Lexer do
  subject { Mint::Lexer.new }

  it do
    subject.data = 'alias a b rescue foo'
    subject.to_a[3].first.should == :kRESCUE_MOD
  end
end