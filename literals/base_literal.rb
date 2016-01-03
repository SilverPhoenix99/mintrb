module Mint
  module BaseLiteral

    attr_reader :delimiter

    attr_accessor :brace_count,
                  :content_start

    def initialize(delimiter)
      @delimiter = delimiter
      @brace_count = 0
    end

    def can_label?;           false                   end
    def commit_indent;                                end # do nothing
    def dedents?;             false                   end
    def delimiter?;           raise 'Not Implemented' end
    def end_delimiter;        raise 'Not Implemented' end
    def indent;               0                       end
    def indent=(_)                                    end # do nothing
    def interpolates?;        raise 'Not Implemented' end
    def line_indent;          0                       end
    def line_indent=(_)                               end # do nothing
    def regexp?;              false                   end
    def state;                raise 'Not Implemented' end
    def type;                 raise 'Not Implemented' end
    def unterminated_message; raise 'Not Implemented' end
    def words?;               false                   end
  end
end