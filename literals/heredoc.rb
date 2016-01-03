require_relative 'base_literal'

module Mint
  class Heredoc
    include BaseLiteral

    attr_accessor :indent,
                  :line_indent,
                  :restore # only in heredoc (not inherited)

    alias_method :id, :delimiter

    def initialize(indent_type, id_delimiter, id, restore)
      # indent_type '' doesn't allow whitespace before delimiter,
      # i.e., the delimiter must be isolated in a line

      # indent_type '-' allows whitespace before delimiter

      # indent type '~' removes left margin:
      #     margin = heredoc_content.scan(/^ +/).map(&:size).min
      #     heredoc_content.gsub(/^ {#{margin}}/, '')
      # it also allows whitespace before delimiter

      @indent_type, @id_delimiter, @restore = indent_type, id_delimiter, restore
      @indent, @line_indent = -1, 0
      super(id)
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
      @regexp ||= (@indent_type == '') ? /#@delimiter$/ : /[\t\v\f\r ]*#@delimiter$/

      (delimiter =~ @regexp) == 0
    end

    def end_delimiter
      @delimiter
    end

    def full_id
      "<<#{@indent_type}#{@id_delimiter}#{@delimiter}#{@id_delimiter}"
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

    def unterminated_message
      %(can't find string "#@delimiter" anywhere before EOF)
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