module Mint
  module BaseLiteral
    attr_accessor :brace_count,
                  :content_start

    def initialize
      @brace_count = 0
    end

    def content_buffer
      @content_buffer ||= String.new
    end

    def interpolates?
      raise 'Not Implemented'
    end

    def state
      raise 'Not Implemented'
    end

    def type
      raise 'Not Implemented'
    end

    def unterminated_string_message
      raise 'Not Implemented'
    end
  end

  class Literal
    include BaseLiteral

    STRING_BEG = {
      'W' => :tWORDS_BEG,
      'w' => :tQWORDS_BEG,
      'I' => :tSYMBOLS_BEG,
      'i' => :tQSYMBOLS_BEG,
      'x' => :tXSTRING_BEG,
      '`' => :tXSTRING_BEG,
      'r' => :tREGEXP_BEG,
      '/' => :tREGEXP_BEG,
      's' => :tSYMBEG
    }

    STRING_END = {
      '{' => '}',
      '<' => '>',
      '[' => ']',
      '(' => ')'
    }

    attr_reader :delimiter

    def initialize(delimiter, content_start)
      @delimiter, @content_start = delimiter, content_start
      super()
    end

    def interpolates?
      !(@delimiter =~ /^('|%[qwis])/)
    end

    def state
      Lexer.Lex_en_STRING_CONTENT
    end

    def type
      index = delimiter[0] == '%' ? 1 : 0
      STRING_BEG[delimiter[index]] || :tSTRING_BEG
    end
    
    def unterminated_string_message
      'unterminated string meets end of file'
    end
  end


  class Heredoc
    include BaseLiteral

    # indent type '<<~' removes left margin:
    #     margin = heredoc_content.scan(/^ +/).map(&:size).min
    #     heredoc_content.gsub(/^ {#{margin}}/, '')
  
    attr_reader :indent, :id, :id_delimiter

    attr_accessor :restore

    alias delimiter id

    def initialize(indent, id_delimiter, id, restore)
      @indent, @id_delimiter, @id, @restore = indent, id_delimiter, id, restore
      super()
    end

    def full_id
      "<<#{@indent}#{@id_delimiter}#{@id}#{@id_delimiter}"
    end

    def interpolates?
      @id_delimiter != "'"
    end

    def state
      Lexer.Lex_en_HEREDOC_CONTENT
    end

    def type
      @id_delimiter == '`' ? :tXSTRING_BEG : :tSTRING_BEG
    end
    
    def unterminated_string_message
      %(can't find string "#@id" anywhere before EOF)
    end
  end
end

