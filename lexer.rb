require_relative 'literals/literal'
require_relative 'literals/heredoc'
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

    attr_reader :filename,
                :__end__seen

    attr_accessor :cond,
                  :cmdarg,
                  :in_cmd,
                  :lpar_beg,
                  :paren_nest,
                  :in_kwarg

    def data
      @data.dup
    end

    def data=(data)
      @data = data
      reset
    end

    def reset
      @p     = 0
      @cs    = BOF
      @ts    = nil
      @te    = nil
      @act   = 0
      @stack = []
      @top   = 0

      @tokens      = []
      @__end__seen = false
      @literals    = []
      @line_jump   = 0
      @in_cmd      = false
      @paren_nest  = 0
      @cond        = 0
      @cmdarg      = 0
      @lpar_beg    = 0
      @in_kwarg    = false

      if (i = @data.index(/[\0\x04\x1a]/))
        @data = @data[0, i]
      end

      @lines       = @data.each_char
                         .each_with_index
                         .select { |c, _| c == "\n" }
                         .map(&:last)
                         .each_with_index
                         .map { |p, l| [p+1, l+1] }
      @lines.unshift [0, 0]
      @lines << [ @data.length + 1, @lines.count ]

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

    def location(pos = @ts)
      line = @lines.bsearch { |l| l.first > pos }
      [line.last, pos - @lines[line.last - 1].first + 1]
    end

    def next_token
      return [false, false] if eof?
      advance if @tokens.empty?
      raise IndexError, 'Stack is full' if @top > 10
      @tokens.shift || [false, false]
    end

    def push_cmdarg(val)
      @cmdarg = (@cmdarg << 1) | (val ? 1 : 0)
    end

    def lexpop_cmdarg
      @cmdarg = (@cmdarg >> 1) | (@cmdarg & 1)
    end

    def pop_cmdarg
      @cmdarg >>= 1
    end

    def cmdarg?
      (@cmdarg & 1) == 1
    end

    def push_cond(val)
      @cond = (@cond << 1) | (val ? 1 : 0)
    end

    def lexpop_cond
      @cond = (@cond >> 1) | (@cond & 1)
    end

    def pop_cond
      @cond >>= 1
    end

    def cond?
      (@cond & 1) == 1
    end

    def state
      STATES[@cs]
    end

    def state=(state)
      raise NameError, "state #{state.inspect} not defined" unless STATES.has_value?(state)
      @cs = self.class.const_get(state)
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

      def fcalled_by?(*states, offset: 0, reject: true)

        c = if reject
          stack = @stack[0...@top].reject { |state| state == COMMON_EXPR }
          top = stack.length - 1
          stack[top - offset]
        else
          @stack[@top - 1 - offset]
        end

        states.include?(c)
      end

      def gen_token(token_type, token: nil, location: nil, ts: @ts, te: @te, ots: 0, ote: 0, **options)
        token    ||= current_token(ts: ts, te: te, ots: ots, ote: ote)
        location ||= location(ts)

        if token_type == OPERATORS && token[-1] == '='
          token = token[0..-2]
          token = OPERATORS[token] || KEYWORDS[token] || token
          token_type = :tOP_ASGN
        elsif token_type.is_a?(Hash)
          token_type = token_type[token]
          token_type, @cs = process_reserved(*token_type) if token_type.is_a?(Array)
        end

        if token.length == 1
          if token[0] == '(' || token[0] == '['
            @paren_nest += 1
            unless @cs == EXPR_FNAME || @cs == EXPR_DOT
              push_cond false
              push_cmdarg false
            end

          elsif token[0] == ')' || token[0] == ']'
            @paren_nest -= 1
            lexpop_cond
            lexpop_cmdarg

          elsif token[0] == '{'
            @literals.last.brace_count += 1 unless @literals.empty?
            push_cond false
            push_cmdarg false
            if token_type == :kLAMBEG
              @lpar_beg = 0
              @paren_nest -= 1
            end

          elsif token[0] == '}'
            lexpop_cond
            lexpop_cmdarg
            @cs = EXPR_ENDARG
            lit = @literals.last
            if lit
              if lit.brace_count == 0
                token_type = :tSTRING_DEND
                lit.content_start = @te
                @cs = lit.state
              else
                lit.brace_count -= 1
              end
            end
          end
        end

        token = [token_type, [token] + location]
        token.last << options unless options.empty?
        @tokens << token
        token
      end

      def process_reserved(token_type, state, alt_type = nil)
        return [token_type, state] if @cs == EXPR_FNAME

        @in_cmd ||= state == EXPR_BEG

        if token_type == :kDO
          if @lpar_beg > 0 && @lpar_beg == @paren_nest
            @lpar_beg = 0
            @paren_nest -= 1
            return [:kDO_LAMBDA, state]
          end

          return [:kDO_COND,  state] if cond?

          if (cmdarg? && @cs != EXPR_ENDARG) || @cs == EXPR_BEG || @cs == EXPR_ENDARG
            return [:kDO_BLOCK, state]
          end

          return [:kDO, state]
        end

        return [token_type, state] if @cs == EXPR_BEG || @cs == EXPR_LABELARG

        return [alt_type, EXPR_BEG] if alt_type && alt_type != token_type

        [token_type, state]
      end

      def gen_heredoc_token(ts = @ts)
        @literals << heredoc = Heredoc.new(current_token(ts: ts), @te)
        gen_token(heredoc.type, token: heredoc.full_id, location: location(ts))
        heredoc
      end

      def gen_interpolation_tokens(type)
        lit = @literals.last
        lit.commit_indent
        return unless lit.interpolates?
        tok = current_token(ots: 1)
        gen_string_content_token(- tok.length - 1)
        gen_token(:tSTRING_DVAR, token: '#', location: location(@ts))
        gen_token(type, token: tok, location: location(@ts + 1))
        lit.content_start = @te
      end

      def gen_literal_token(ts = @ts)
        token = current_token(ts: ts)

        can_label = token =~ /^["']$/ &&
          (
            (!@in_cmd && (@cs == EXPR_BEG || @cs == EXPR_ENDFN || fcalled_by?(EXPR_BEG, EXPR_ENDFN))) ||
            @cs == EXPR_ARG ||
            @cs == EXPR_CMDARG ||
            @cs == EXPR_LABELARG ||
            fcalled_by?(EXPR_ARG, EXPR_CMDARG, EXPR_LABELARG)
          )

        @literals << lit = Literal.new(token, @te, can_label)
        gen_token(lit.type, token: token, location: location(ts))
      end

      def gen_number_token(num_type, num_base, num_flags, ts: @ts)
        num_type = case num_flags.last
          when :rational  then :tRATIONAL
          when :imaginary then :tIMAGINARY
          else num_type
        end
        gen_token(num_type, ts: ts, num_base: num_base)
      end

      def gen_string_content_token(ote = @ts - @te)
        lit = @literals.last
        tok = current_token(ts: lit.content_start, ote: ote)
        return false if tok.length == 0
        gen_token(:tSTRING_CONTENT, token: tok, location: location(lit.content_start))
        true
      end

      def gen_string_end_token
        lit = @literals.pop
        tok = current_token
        if lit.delimiter == '/'
          gen_token(:tREGEXP_END, token: tok)
        elsif tok[-1] == ':'
          gen_token(:tLABEL_END, token: tok)
        elsif lit.dedents?
          gen_token(:tSTRING_END, token: tok, dedent: lit.indent)
        else
          gen_token(:tSTRING_END, token: tok)
        end
      end

      def keyword_token(token_type, lts, lte, next_state, token: nil)
        #fexec @te = lte;
        @p = (@te = lte) - 1 if lte >= 0
        pop_fcall if fcalled_by?(COMMON_EXPR, reject: false) || @cs == COMMON_EXPR
        #fnext *next_state;
        current_state = @cs
        token = gen_token(token_type, token: token, ts: lts >= 0 ? lts : @ts)
        @cs = next_state if current_state == @cs
        token
      end

      def next_bol!
        return @line_jump if @line_jump > @p

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

    OPERATORS = {
        '*'   => :kMUL,
        '**'  => :kPOW,
        '+'   => :kPLUS,
        '-'   => :kMINUS,
        '&'   => :kBIN_AND,
        '::'  => :kCOLON2,
        '('   => :kLPAREN2,
        '['   => :kLBRACK2,
        '{'   => :kLBRACE2
    }

    KEYWORDS = {
      '!'   => :kNOTOP,
      '!='  => :kNEQ,
      '!@'  => :kNOTOP,
      '!~'  => :kNMATCH,
      '&'   => :kAMPER,
      '&&'  => :kANDOP,
      '&.'  => :kANDDOT,
      '('   => :kLPAREN,
      ')'   => :kRPAREN,
      '*'   => :kSTAR,
      '**'  => :kDSTAR,
      '+'   => :kUPLUS,
      '+@'  => :kUPLUS,
      ','   => :kCOMMA,
      '-'   => :kUMINUS,
      '->'  => :kLAMBDA,
      '-@'  => :kUMINUS,
      '.'   => :kDOT,
      '..'  => :kDOT2,
      '...' => :kDOT3,
      '/'   => :kDIV,
      ':'   => :kCOLON,
      '::'  => :kCOLON3,
      ';'   => :kSEMICOLON,
      '<'   => :kLESS,
      '<<'  => :kLSHIFT,
      '<='  => :kLEQ,
      '<=>' => :kCMP,
      '='   => :kASSIGN,
      '=='  => :kEQ,
      '===' => :kEQQ,
      '=>'  => :kASSOC,
      '=~'  => :kMATCH,
      '>'   => :kGREATER,
      '>='  => :kGEQ,
      '>>'  => :kRSHIFT,
      '?'   => :kQMARK,
      '['   => :kLBRACK,
      '[]'  => :kAREF,
      '[]=' => :kASET,
      ']'   => :kRBRACK,
      '^'   => :kXOR,
      '`'   => :kBACKTICK,
      '{'   => :kLBRACE,
      '|'   => :kPIPE,
      '||'  => :kOROP,
      '}'   => :kRBRACE,
      '~'   => :kNEG,
      '~@'  => :kNEG,
      '%'   => :kPERCENT,
      '\\'  => :kBACKSLASH,
    }

    RESERVED = {
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
      'if'           => [:kIF,           EXPR_BEG, :kIF_MOD],
      'in'           => [:kIN,           EXPR_BEG],
      'module'       => [:kMODULE,       EXPR_BEG],
      'next'         => [:kNEXT,         EXPR_MID],
      'nil'          => [:kNIL,          EXPR_END],
      'not'          => [:kNOT,          EXPR_ARG],
      'or'           => [:kOR,           EXPR_BEG],
      'redo'         => [:kREDO,         EXPR_END],
      'rescue'       => [:kRESCUE,       EXPR_MID, :kRESCUE_MOD],
      'retry'        => [:kRETRY,        EXPR_END],
      'return'       => [:kRETURN,       EXPR_MID],
      'self'         => [:kSELF,         EXPR_END],
      'super'        => [:kSUPER,        EXPR_ARG],
      'then'         => [:kTHEN,         EXPR_BEG],
      'true'         => [:kTRUE,         EXPR_END],
      'undef'        => [:kUNDEF,        EXPR_FNAME],
      'unless'       => [:kUNLESS,       EXPR_BEG, :kUNLESS_MOD],
      'until'        => [:kUNTIL,        EXPR_BEG, :kUNTIL_MOD],
      'when'         => [:kWHEN,         EXPR_BEG],
      'while'        => [:kWHILE,        EXPR_BEG, :kWHILE_MOD],
      'yield'        => [:kYIELD,        EXPR_ARG],
      '__ENCODING__' => [:k__ENCODING__, EXPR_END],
      '__FILE__'     => [:k__FILE__,     EXPR_END],
      '__LINE__'     => [:k__LINE__,     EXPR_END],
    }
  end
end