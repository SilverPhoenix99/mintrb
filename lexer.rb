require_relative 'literal'
require_relative 'gen/lexer'

module Mint
  class Lexer
    include Enumerable

    NL = ?\n

    def initialize(data, filename = '(string)')
      self.data = data
      @filename = filename
      @tab_width = 8
    end

    def data=(data)
      @data = data
      reset
    end

    def reset
      @p     = 0
      @cs    = self.class.Lex_en_BOL
      @ts    = nil
      @te    = nil
      @act   = 0
      @stack = []
      @top   = 0

      @tokens      = []
      @__end__seen = false
      @literals    = []
      @line_jump   = nil
      @lines       = @data.each_char.each_with_index.select { |c, _| c == "\n" }.map(&:last)

      nil
    end

    def eof?
      @p > @data.length
    end

    def next_token
      return [false, false] if eof?
      return @tokens.shift unless @tokens.empty?
      advance
      @tokens.shift || [false, false]
    end

    def each
      return enum_for(:each) unless block_given?
      loop do
        t = next_token
        yield t
        break unless t.first
      end
    end

    attr_reader :filename
    attr_reader :__end__seen

    instance_variables.select { |v| v =~ /^@_?Lex_/ }.each do |var|
      class_eval "def #{ var[1..-1] }; self.class.instance_variable_get('#{ var }') end"
    end

    class << self
      attr_accessor :tab_width
    end
    @tab_width = 8

    def tab_width
      @tab_width || self.class.tab_width
    end

    attr_writer :tab_width

    private

      def current_token(ts: @ts, te: @te, ots: 0, ote: 0)
        @data[(ts + ots)...(te + ote)]
      end

      def fcalled_by?(state)
        @stack[@top-1] == state
      end

      def gen_token(type, tok = current_token, **options)
        @tokens << ( options.empty? ? [type, tok] : [type, tok, options] )
      end

      def gen_number_token(num_type, num_base, num_flags)
        num_type = case num_flags.last
          when :rational  then :tRATIONAL
          when :imaginary then :tIMAGINARY
          else num_type
        end
        gen_token(num_type, current_token, num_base: num_base)
      end

      def gen_keyword_token(tok = current_token)
        unless @literals.empty?
          @literals.last.brace_count += 1 if tok == '{'
          @literals.last.brace_count -= 1 if tok == '}'
        end
        key = KEYWORDS[tok]
        key, @cs = key if key.is_a?(Array)
        gen_token(key, tok)
      end

      def gen_op_asgn_token(tok = current_token(ote: -1))
        gen_token(:tOP_ASGN, tok)
      end

      def gen_literal_token(tok: current_token)
        delimiter = Literal::STRING_END[tok[-1]] || tok
        @literals << lit = Literal.new(delimiter, @te)
        gen_token(lit.type, tok)
      end

      def gen_heredoc_token(indent, delimiter, id)
        @literals << heredoc = Heredoc.new(indent, delimiter, id, @te)
        gen_token(heredoc.type, heredoc.full_id)
        @literals.last
      end

      def gen_interpolation_tokens(type, tok = current_token(ots: 1))
        lit = @literals.last
        return false unless lit.interpolates?
        gen_string_content_token(- tok.length - 1)
        gen_token(:tSTRING_DVAR, '#')
        gen_token(type, tok)
        lit.content_start = @te
        true
      end

      def gen_string_content_token(ote = -token_length)
        lit = @literals.last
        # add content to buffer
        lit.content_buffer << current_token(ts: lit.content_start, ote: ote)
        gen_token(:tSTRING_CONTENT, lit.content_buffer)
        lit.clear_buffer
      end

      def gen_string_end_token
        lit = @literals.pop
        if lit.dedents?
          gen_token(:tSTRING_END, current_token, dedent: lit.indent)
        else
          gen_token(:tSTRING_END, current_token)
        end
      end

      # This method should only be called at an `fexec'
      def next_bol!
        if @line_jump
          p = @line_jump
          @line_jump = nil
          return p
        end

        p = @p
        loop do
          c = @data[p]
          break p+1 if !c || c == NL
          p += 1
        end
      end

      def token_length
        @te - @ts
      end

    KEYWORDS = {
      'alias'        => :kALIAS,
      'and'          => :kAND,
      'BEGIN'        => :kAPP_BEGIN,
      'begin'        => :kBEGIN,
      'break'        => :kBREAK,
      'case'         => :kCASE,
      'class'        => [:kCLASS, self.Lex_en_CLASS],
      'def'          => :kDEF,
      'defined?'     => :kDEFINED,
      'do'           => :kDO,
      'else'         => :kELSE,
      'elsif'        => :kELSIF,
      'END'          => :kAPP_END,
      'end'          => :kEND,
      'ensure'       => :kENSURE,
      'false'        => :kFALSE,
      'for'          => :kFOR,
      'if'           => :kIF,
      'in'           => :kIN,
      'module'       => :kMODULE,
      'next'         => :kNEXT,
      'nil'          => :kNIL,
      'not'          => :kNOT,
      'or'           => :kOR,
      'redo'         => :kREDO,
      'rescue'       => :kRESCUE,
      'retry'        => :kRETRY,
      'return'       => :kRETURN,
      'self'         => :kSELF,
      'super'        => :kSUPER,
      'then'         => :kTHEN,
      'true'         => :kTRUE,
      'undef'        => :kUNDEF,
      'unless'       => :kUNLESS,
      'until'        => :kUNTIL,
      'when'         => :kWHEN,
      'while'        => :kWHILE,
      'yield'        => :kYIELD,
      '__ENCODING__' => :k__ENCODING__,
      '__FILE__'     => :k__FILE__,
      '__LINE__'     => :k__LINE__,
      '!'            => :kNOT,
      '!='           => :kNEQ,
      '!@'           => :kFNAME_NOT,
      '!~'           => :kNMATCH,
      '&'            => :kAMPER,
      '&&'           => :kANDOP,
      '&.'           => :kANDDOT,
      '('            => :kLPAREN,
      ')'            => :kRPAREN,
      '*'            => :kSTAR,
      '**'           => :kPOW,
      '+'            => :kPLUS,
      '+@'           => :kFNAME_PLUS,
      ','            => :kCOMMA,
      '-'            => :kMINUS,
      '->'           => :kLAMBDA,
      '-@'           => :kFNAME_MINUS,
      '.'            => :kDOT,
      '..'           => :kDOT2,
      '...'          => :kDOT3,
      '/'            => :kDIV,
      ':'            => :kCOLON,
      '::'           => :kCOLON2,
      ';'            => :kSEMICOLON,
      '<'            => :kLESS,
      '<<'           => :kLSHIFT,
      '<='           => :kLEQ,
      '<=>'          => :kCMP,
      '='            => :kASSIGN,
      '=='           => :kEQ,
      '==='          => :kEQQ,
      '=>'           => :kASSOC,
      '=~'           => :kMATCH,
      '>'            => :kGREATER,
      '>='           => :kGEQ,
      '>>'           => :kRSHIFT,
      '?'            => :kQMARK,
      '['            => :kLBRACK,
      '[]'           => :kAREF,
      '[]='          => :kASET,
      ']'            => :kRBRACK,
      '^'            => :kXOR,
      '{'            => :kLBRACE,
      '|'            => :kPIPE,
      '||'           => :kOROP,
      '}'            => :kRBRACE,
      '~'            => :kNEG,
      '~@'           => :kFNAME_NEG
    }
  end
end