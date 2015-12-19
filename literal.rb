module Mint
  module BaseLiteral
    attr_accessor :brace_count,
                  :content_start

    def initialize
      @brace_count = 0
    end

    def raw_content
      @content_buffer ||= String.new
    end

    def processed_content(tab_width)
      raw_content.dup
    end

    def delimiter?
      raise 'Not Implemented'
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

    def delimiter?(delimiter)
      @delimiter[-1] == delimiter
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

    def processed_content(tab_width)
      return super unless @indent == '~'

      indent = 1 << 31
      line_indent = 0

      raw_content.each_char do |c|
        case
          when c == Lexer::NL
            line_indent = 0

          when line_indent < 0
            # don't do anything!

          when c == ' '
            line_indent += 1

          when c == ?\t
            line_indent += tab_width

          else
            indent = line_indent if line_indent < indent
            line_indent = -1
        end
      end
      indent = line_indent if 0 <= line_indent && line_indent < indent # last line

      return raw_content if indent == 0

      line_indent = indent
      content = String.new
      raw_content.each_char do |c|
        case
          when c == Lexer::NL
            line_indent = indent
            content += c

          when line_indent > 0
            line_indent -= c == ?\t ? tab_width : 1

          else
            content += c
        end
      end

      content
    end

    def delimiter?(delimiter)
      @regexp ||= (@indent == '') ? /#@id$/ : /[\t\n\v\f\r ]*#@id$/

      (delimiter =~ @regexp) == 0
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

