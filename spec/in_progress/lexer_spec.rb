require_relative '../../lexer'
require_relative '../spec_helper'

RSpec.describe Mint::Lexer do
  subject { Mint::Lexer.new }

  it do
    subject.data = '%w(a b)'
    subject.to_a.should == [
        [:tSTRING_BEG,     '%w('],
        [:tSTRING_CONTENT, 'a'],
        [:tWORDS_SEP,      ' '],
        [:tSTRING_CONTENT, 'b'],
        [:tSTRING_END,     ')'],
        [false, false]
    ]
  end
end