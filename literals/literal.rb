require_relative 'base_literal'

module Mint
  class Literal
    include BaseLiteral

    def initialize(delimiter, content_start, can_label = false)
      @delimiter, @content_start, @can_label = delimiter, content_start, can_label
      @end_delimiter = (STRING_END[@delimiter[-1]] || @delimiter)[-1]
      super(delimiter)
    end

    def can_label?
      @can_label
    end

    def delimiter?(delimiter)
      end_delimiter == delimiter
    end

    attr_reader :end_delimiter

    def interpolates?
      @delimiter =~ %r{^(/|`|:?"|%[^qwis])}
    end

    def regexp?
      @delimiter =~ %r{^(/|%r)}
    end

    def state
      Lexer::STRING_DELIMITER
    end

    def type
      delim = @delimiter[0] == '%' ? @delimiter[0..1] : @delimiter
      STRING_BEG[delim] || :tSTRING_BEG
    end

    def unterminated_message
      'unterminated string meets end of file'
    end

    def words?
      @delimiter =~ /^%[WwIi]/
    end


    STRING_BEG = {
        # '%' '%Q' '%q' '"' "'" => :tSTRING_BEG
        '%W' => :tWORDS_BEG,
        '%w' => :tQWORDS_BEG,
        '%I' => :tSYMBOLS_BEG,
        '%i' => :tQSYMBOLS_BEG,
        '%x' => :tXSTRING_BEG,
        '`'  => :tXSTRING_BEG,
        '%r' => :tREGEXP_BEG,
        '/'  => :tREGEXP_BEG,
        '%s' => :tSYMBEG,
        ":'" => :tSYMBEG,
        ':"' => :tSYMBEG
    }

    STRING_END = {
        '{' => '}',
        '<' => '>',
        '[' => ']',
        '(' => ')'
    }

  end
end
