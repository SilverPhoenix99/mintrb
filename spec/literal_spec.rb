require_relative '../literal'
require_relative 'spec_helper'

RSpec.describe Mint::Heredoc do

  describe 'tilde' do
    subject { Mint::Heredoc.new('~', '', 'AA', 0) }

  end

end