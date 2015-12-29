require_relative 'literal'
require_relative 'gen/lexer'

module Mint
  class Lexer
    include Enumerable

    NL = ?\n

    STATES = {}
    instance_variables.select { |v| v =~ /^@_?Lex_/ }.each do |var|
      class_eval "def #{ var[1..-1] }; self.class.instance_variable_get('#{ var }') end"
      if var =~ /^@Lex_en_/
        const_set(var[8..-1], instance_variable_get(var))
        STATES[const_get(var[8..-1])] = :"#{var[8..-1]}"
      end
    end
    STATES.freeze

    def initialize(data = '', filename = '(string)')
      self.data = data
      @filename = filename
      @tab_width = 8
    end

    attr_reader :filename
    attr_reader :__end__seen

    def data
      @data.dup
    end

    def data=(data)
      @data = data
      reset
    end

    def reset
      @p     = 0
      @cs    = BOL
      @ts    = nil
      @te    = nil
      @act   = 0
      @stack = [EXPR_BEG]
      @top   = 1

      @tokens      = []
      @__end__seen = false
      @literals    = []
      @line_jump   = nil
      @in_cmd      = false
      @lines       = @data.each_char.each_with_index.select { |c, _| c == "\n" }.map(&:last)

      nil
    end

    def each
      return enum_for(:each) unless block_given?
      loop do
        t = next_token
        yield t
        break unless t.first
      end
    end

    def eof?
      @p > @data.length
    end

    def next_token
      return [false, false] if eof?
      advance if @tokens.empty?
      @tokens.shift || [false, false]
    end

    def state
      STATES[@cs]
    end

    def state=(state)
      raise NameError, "state #{state.inspect} not defined" unless STATES.has_value?(state)
      @cs = const_get(state)
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

      REJECTED_CALLS = [COMMON_EXPR, OPERATOR_EXPR]
      def fcalled_by?(*states, offset: 0, reject: true)

        c = if reject
          stack = @stack[0...@top].reject { |state| REJECTED_CALLS.include?(state) }
          top = stack.length - 1
          stack[top - offset]
        else
          @stack[@top - 1 - offset]
        end

        states.include?(c)
      end

      def gen_token(type, tok = current_token, **options)
        @tokens << ( options.empty? ? [type, tok] : [type, tok, options] )
      end

      def gen_heredoc_token(indent, delimiter, id)
        @literals << heredoc = Heredoc.new(indent, delimiter, id, @te)
        gen_token(heredoc.type, heredoc.full_id)
        heredoc
      end

      def gen_interpolation_tokens(type, tok = current_token(ots: 1))
        lit = @literals.last
        lit.commit_indent
        return unless lit.interpolates?
        gen_string_content_token(- tok.length - 1)
        gen_token(:tSTRING_DVAR, '#')
        gen_token(type, tok)
        lit.content_start = @te
      end

      def gen_keyword_token(tok = current_token)
        unless @literals.empty?
          @literals.last.brace_count += 1 if tok == '{'
          @literals.last.brace_count -= 1 if tok == '}'
        end
        key = KEYWORDS[tok]
        if key.is_a?(Array)
          key, state = *key
          @cs = state
          @in_cmd = true if state == EXPR_BEG
        end
        gen_token(key, tok)
      end

      def gen_literal_token(tok: current_token)
        @literals << lit = Literal.new(tok, @te)
        gen_token(lit.type, tok)
      end

      def gen_number_token(num_type, num_base, num_flags)
        num_type = case num_flags.last
          when :rational  then :tRATIONAL
          when :imaginary then :tIMAGINARY
          else num_type
        end
        gen_token(num_type, current_token.lstrip, num_base: num_base)
      end

      def gen_op_asgn_token(tok = current_token(ote: -1))
        @cs = EXPR_BEG if %w(**).include?(tok)
        gen_token(:tOP_ASGN, KEYWORDS[tok] || tok)
      end

      def gen_string_content_token(ote = -token_length)
        lit = @literals.last
        # add content to buffer
        lit.content_buffer << current_token(ts: lit.content_start, ote: ote)
        return false if lit.words? && lit.content_buffer.length == 0
        gen_token(:tSTRING_CONTENT, lit.content_buffer)
        lit.clear_buffer
        true
      end

      def gen_string_end_token
        lit = @literals.pop
        tok = current_token
        if lit.delimiter == '/'
          gen_token(:tREGEXP_END, tok)
        elsif tok[-1] == ':'
          gen_token(:tLABEL_END, tok)
        elsif lit.dedents?
          gen_token(:tSTRING_END, tok, dedent: lit.indent)
        else
          gen_token(:tSTRING_END, tok)
        end
      end

      LABELS1 = [EXPR_BEG, EXPR_ENDFN]
      LABELS2 = [EXPR_ARG, EXPR_CMDARG]
      def label_possible?
        (LABELS1.include?(@cs) && !@in_cmd) || LABELS2.include?(@cs)
      end

      # def label_suffix?(n = 0)
      #   peek(n) == ':' && peek(n + 1) == ':'
      # end

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

      def peek(n = 0)
        c = @data[@p + n]
        (c && c.ord) || 0
      end

      def push_fcall(state = @cs)
        @stack[@top] = state
        @top += 1
      end

      def pop_fcall
        @top -= 1
      end

      def space_seen?
        @ts > 0 && @data[@ts - 1] =~ / \f\r\t\v/
      end

      def token_length
        @te - @ts
      end

    KEYWORDS = {
      'alias'        => [:kALIAS,        EXPR_FNAME],
      'and'          => [:kAND,          EXPR_BEG],
      'BEGIN'        => [:kAPP_BEGIN,    EXPR_END],
      'begin'        => [:kBEGIN,        EXPR_BEG],
      'break'        => [:kBREAK,        EXPR_MID],
      'case'         => [:kCASE,         EXPR_BEG],
      'class'        => [:kCLASS,        EXPR_CLASS],
      'def'          => [:kDEF,          EXPR_FNAME],
      'defined?'     => [:kDEFINED,      EXPR_ARG],
      'do'           => [:kDO,           EXPR_BEG],
      'else'         => [:kELSE,         EXPR_BEG],
      'elsif'        => [:kELSIF,        EXPR_BEG],
      'END'          => [:kAPP_END,      EXPR_END],
      'end'          => [:kEND,          EXPR_END],
      'ensure'       => [:kENSURE,       EXPR_BEG],
      'false'        => [:kFALSE,        EXPR_END],
      'for'          => [:kFOR,          EXPR_BEG],
      'if'           => [:kIF,           EXPR_BEG],
      'in'           => [:kIN,           EXPR_BEG],
      'module'       => [:kMODULE,       EXPR_BEG],
      'next'         => [:kNEXT,         EXPR_MID],
      'nil'          => [:kNIL,          EXPR_END],
      'not'          => [:kNOT,          EXPR_ARG],
      'or'           => [:kOR,           EXPR_BEG],
      'redo'         => [:kREDO,         EXPR_END],
      'rescue'       => [:kRESCUE,       EXPR_MID],
      'retry'        => [:kRETRY,        EXPR_END],
      'return'       => [:kRETURN,       EXPR_MID],
      'self'         => [:kSELF,         EXPR_END],
      'super'        => [:kSUPER,        EXPR_ARG],
      'then'         => [:kTHEN,         EXPR_BEG],
      'true'         => [:kTRUE,         EXPR_END],
      'undef'        => [:kUNDEF,        EXPR_FNAME],
      'unless'       => [:kUNLESS,       EXPR_BEG],
      'until'        => [:kUNTIL,        EXPR_BEG],
      'when'         => [:kWHEN,         EXPR_BEG],
      'while'        => [:kWHILE,        EXPR_BEG],
      'yield'        => [:kYIELD,        EXPR_ARG],
      '__ENCODING__' => [:k__ENCODING__, EXPR_END],
      '__FILE__'     => [:k__FILE__,     EXPR_END],
      '__LINE__'     => [:k__LINE__,     EXPR_END],
      '!'            => :kNOTOP,
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
      '`'            => :kBACKTICK,
      '{'            => :kLBRACE,
      '|'            => :kPIPE,
      '||'           => :kOROP,
      '}'            => :kRBRACE,
      '~'            => :kNEG,
      '~@'           => :kFNAME_NEG,
      '%'            => :kPERCENT
    }
  end
end