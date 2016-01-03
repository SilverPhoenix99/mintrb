require_relative '../../literals/literal'
require_relative '../../literals/base_literal'
require_relative '../../literals/heredoc'
require_relative '../spec_helper'

RSpec.describe Mint::Heredoc do
  subject { Mint::Lexer.new }

  # TODO %q|"\#{ <<AA }"\nfoo\nAA\n.upcase| must return "FOO\n"
end