require_relative '../literal'
require_relative 'spec_helper'

RSpec.describe Mint::Heredoc do

  describe 'tilde' do
    subject { Mint::Heredoc.new('~', '', 'AA', 0) }

    it 'dedents 2 spaces' do
      subject.raw_content << "   aaa\n  aa"
      subject.processed_content(8).should == " aaa\naa"
    end

    it 'dedents 3 spaces' do
      subject.raw_content << "   aaa\n    aa"
      subject.processed_content(8).should == "aaa\n aa"
    end
  end

end