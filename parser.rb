require_relative 'gen/parser'
require_relative 'lexer'

module Mint
  class Parser
    attr_reader :lexer

    def initialize(data = '', filename = '(string)')
      @lexer = Mint::Lexer.new(data, filename)
      @in_def = false
      @in_defined = false
      @in_def = false
      @in_single = false
      @cmdarg_stack = []
      @cond_stack = []
      @def_stack = []
      @single_stack = []
      @lpar_beg_stack = []
      @in_kwarg_stack = []
    end

    protected

      def next_token
        @lexer.next_token.tap { |tok| tok.last.unshift tok.first if tok.first }
      end

      def push_cmdarg
        @cmdarg_stack.push @lexer.cmdarg
      end

      def pop_cmdarg
        @lexer.cmdarg = @cmdarg_stack.pop
      end

      def push_cond
        @cond_stack.push @lexer.cond
      end

      def pop_cond
        @lexer.cond = @cond_stack.pop
      end

      def push_def
        @def_stack.push @in_def
      end

      def pop_def
        @in_def = @def_stack.pop
      end

      def push_single
        @single_stack.push @in_single
      end

      def pop_single
        @in_single = @single_stack.pop
      end

      def push_lpar_beg
        @lpar_beg_stack.push @lexer.lpar_beg
      end

      def pop_lpar_beg
        @lexer.lpar_beg = @lpar_beg_stack.pop
      end

      def push_kwarg
        @in_kwarg_stack.push @lexer.in_kwarg
      end

      def pop_kwarg
        @lexer.in_kwarg = @in_kwarg_stack.pop
      end

      def assignable(caller, val)
        puts "#{__method__} : #{caller} : #{val.inspect}"

=begin
        switch (id) {
          case keyword_self:
            yyerror("Can't change the value of self");
            return;
          case keyword_nil:
            yyerror("Can't assign to nil");
            return;
          case keyword_true:
            yyerror("Can't assign to true");
            return;
          case keyword_false:
            yyerror("Can't assign to false");
            return;
          case keyword__FILE__:
            yyerror("Can't assign to __FILE__");
            return;
          case keyword__LINE__:
            yyerror("Can't assign to __LINE__");
            return;
          case keyword__ENCODING__:
            yyerror("Can't assign to __ENCODING__");
            return;
        }

        switch (id_type(id)) {
          case ID_LOCAL:
          case ID_GLOBAL:
          case ID_INSTANCE:
          case ID_CLASS:

          case ID_CONST:
            if (in_def || in_single)
              yyerror("dynamic constant assignment");
            return;

          default:
            yyerror("identifier %s is not valid to set", id_type(id))
        }

=end
      end

      def gettable(caller, val)
        puts "#{__method__} : #{caller} : #{val.inspect}"

=begin
        switch (id) {
            case keyword_self:
            case keyword_nil:
            case keyword_true:
            case keyword_false:
            case keyword__FILE__:
            case keyword__LINE__:
            case keyword__ENCODING__:
              return;
          }
          switch (id_type(id)) {
            case ID_LOCAL:
            case ID_GLOBAL:
            case ID_INSTANCE:
            case ID_CONST:
            case ID_CLASS:
              return;
          }
          compile_error(PARSER_ARG "identifier %"PRIsVALUE" is not valid to get", rb_id2str(id));
=end
      end

      def formal_argument(caller, val)
        puts "#{__method__} : #{caller} : #{val.inspect}"

=begin
        switch (id_type(lhs)) {
          case ID_LOCAL:
            break;
          case ID_CONST:
            yyerror("formal argument cannot be a constant");
            return;
          case ID_INSTANCE:
            yyerror("formal argument cannot be an instance variable");
            return;
          case ID_GLOBAL:
            yyerror("formal argument cannot be a global variable");
            return;
          case ID_CLASS:
            yyerror("formal argument cannot be a class variable");
            return;
          default:
            yyerror("formal argument must be local variable");
            return;
        }
=end
      end

      def vcall_node
        [:kDOT, '.', -1, -1]
      end

  end
end

require_relative 'gen/parser'