module Mint
  module BaseLiteral
    attr_accessor :brace_count,
                  :content_start

    def initialize
      @brace_count = 0
    end

    def commit_indent
      # do nothing
    end

    def dedents?
      false
    end

    def delimiter?
      raise 'Not Implemented'
    end

    def indent
      0
    end

    def indent=(_)
      # do nothing
    end

    def interpolates?
      raise 'Not Implemented'
    end

    def line_indent
      0 # do nothing
    end

    def line_indent=(_)
      # do nothing
    end

    def regexp?
      false
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

    def words?
      false
    end
  end


  class Literal
    include BaseLiteral

    STRING_BEG = {
      '%W' => :tWORDS_BEG,
      '%w' => :tQWORDS_BEG,
      '%I' => :tSYMBOLS_BEG,
      '%i' => :tQSYMBOLS_BEG,
      '%x' => :tXSTRING_BEG,
      '`'  => :tXSTRING_BEG,
      '%r' => :tREGEXP_BEG,
      '/'  => :tREGEXP_BEG,
      '%s' => :tSYMBEG,
      ':'  => :tSYMBEG
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

    def delimiter?(delimiter)
      end_delimiter[-1] == delimiter
    end

    def end_delimiter
      Literal::STRING_END[@delimiter[-1]] || @delimiter
    end

    def interpolates?
      @delimiter !~ /^('|%[qwis])/
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

    def unterminated_string_message
      'unterminated string meets end of file'
    end

    def words?
      @delimiter =~ /^%[WwIi]/
    end
  end


  class Heredoc
    include BaseLiteral

    # indent type '<<~' removes left margin:
    #     margin = heredoc_content.scan(/^ +/).map(&:size).min
    #     heredoc_content.gsub(/^ {#{margin}}/, '')
  
    attr_reader :indent_type, :id, :id_delimiter

    attr_accessor :indent, :line_indent, :restore

    alias_method :delimiter, :id

    def initialize(indent_type, id_delimiter, id, restore)
      @indent_type, @id_delimiter, @id, @restore = indent_type, id_delimiter, id, restore
      @indent, @line_indent = -1, 0
      super()
    end

    def full_id
      "<<#{@indent_type}#{@id_delimiter}#{@id}#{@id_delimiter}"
    end

    def commit_indent
      return unless dedents?
      @indent = @line_indent if @indent == -1 || (0 <= @line_indent && @line_indent < @indent)
      @line_indent = -1
    end

    def dedents?
      @indent_type == '~'
    end

    def delimiter?(delimiter)
      @regexp ||= (@indent_type == '') ? /#@id$/ : /[\t\v\f\r ]*#@id$/

      (delimiter =~ @regexp) == 0
    end

    def interpolates?
      @id_delimiter != "'"
    end

    def state
      Lexer::HEREDOC_DELIMITER
    end

    def type
      @id_delimiter == '`' ? :tXSTRING_BEG : :tSTRING_BEG
    end
    
    def unterminated_string_message
      %(can't find string "#@id" anywhere before EOF)
    end

    # def processed_content(tab_width)
    #   return super unless dedents?
    #
    #   indent = 1 << 31
    #   line_indent = 0
    #
    #   raw_content.each_char do |c|
    #     case
    #       when c == Lexer::NL
    #         line_indent = 0
    #
    #       when line_indent < 0
    #         # don't do anything!
    #
    #       when c == ' '
    #         line_indent += 1
    #
    #       when c == ?\t
    #         line_indent += tab_width
    #
    #       else
    #         indent = line_indent if line_indent < indent
    #         line_indent = -1
    #     end
    #   end
    #   indent = line_indent if 0 <= line_indent && line_indent < indent # last line
    #
    #   return raw_content if indent == 0
    #
    #   line_indent = indent
    #   content = String.new
    #   raw_content.each_char do |c|
    #     case
    #       when c == Lexer::NL
    #         line_indent = indent
    #         content += c
    #
    #       when line_indent > 0
    #         line_indent -= c == ?\t ? tab_width : 1
    #
    #       else
    #         content += c
    #     end
    #   end
    #
    #   content
    # end
  end
end

