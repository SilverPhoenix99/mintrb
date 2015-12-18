
%%{
#%

# Character classes are in lowercase. e.g.: eof
# Machines/scanners are in uppercase. e.g.: EXPR
# Actions are in CamelCase. e.g.: DoEof

# The first state is BOL (beginning of line)




# AMBIGUOUS:
# 'a/' - can be a method with a regexp or a value with a div
# 'a -1' - can be a(1.-@) or a.-(1)

# TODO: magic comments

# TODO: error => numeric literal without digits
# TODO: error => trailing `_' in number

# TODO: qmark = '?'
#    can be a char '?a'
#    can be ternary a ? b : c

# TODO: ":'" and ':"' for string-y symbols
# TODO: labels: "'label':" '"label":'

# TODO: distinguish between % operator and % string
# TODO: distinguish between / operator and regexp
# TODO: distinguish between << left shift and heredoc

# REGEX rules:
#  a / 1/       <- assumes div
#  a /=1/       <- assumes op_asgn
#  a(/ 1/)      <- assumes regex
#  a(/=1/)      <- assumes regex
#  / 1/         <- assumes regex
#  a = / 1/     <- assumes regex
#  a + / 1/     <- assumes regex


machine Lex;
access @;
variable p @p;
getkey (@data[@p] || "\0").ord; # not the most efficient

# ------------------------------------------------------------------------------
#
# Character Classes
#

c_eof      = 0 | 0x4 | 0x1A; # '\0' | ^D | ^Z
wspace     = [ \f\r\t\v] | '\\\n';
#wspace2    = '\\\n'; # skip as being a space instead of a new line
nl         = '\n';
nl_zlen    = nl | zlen;
nl_eof     = nl | c_eof;
nl_wspace  = nl | wspace;
unicode    = any - ascii;
ident_char = alnum | '_' | unicode;

string_term = [QqWwIixrs];

#vcall = nl? '&'? '.' [^\.];
#sstring = ( '%' 'q'? )? "'" ( [^\\''] | '\\' any )* "'";


# ------------------------------------------------------------------------------
#
# Comments
#

line_comment = '#' (any - nl_eof)*;


# ------------------------------------------------------------------------------
#
# Numerics
#

bdigit = [01];
odigit = [0-7];

udigits = digit ( '_'? digit )*; # digits with leading `_' like in 1_000_00

bin_number  =   '0' [bB]   bdigit ( '_'? bdigit )* %{ num_base =  2; };
oct_number  =   '0' [oO_]? odigit ( '_'? odigit )* %{ num_base =  8; };
dec_number  =   '0' [dD]   udigits                 %{ num_base = 10; };
hex_number  =   '0' [xX]   xdigit ( '_'? xdigit )* %{ num_base = 16; };
int_number  = ( '0' | [1-9] ( '_'? digit )* )      %{ num_base = 10; };

sign = [+\-];

real_frac = '.' udigits;
real_exp  = [eE] sign? udigits;

action rac_suf { (num_flags ||= []) << :rational }
action cmx_suf { (num_flags ||= []) << :imaginary }
action int_num { num_type = :tINTEGER }
action flo_num { num_type = :tFLOAT }

real_number =
  int_number
  (
      real_exp
    | real_frac ( real_exp | ('r' %rac_suf)? )?
  ) %flo_num
;

rationable_number = (
    bin_number
  | oct_number
  | dec_number
  | hex_number
  | int_number
) %int_num ('r' %rac_suf)? ;

number = sign? ( rationable_number | real_number ) ('i' %cmx_suf)? ;


# ------------------------------------------------------------------------------
#
# Identifiers
#

identifier = ( lower | '_' | unicode ) ident_char*;
constant   = upper ident_char*;
back_ref   = '$' ['&`+'];
nth_ref    = '$' ( '0' | [1-9] digit* );

gvar = '$' (
      identifier
    | constant
    | [~*$&?!@/\\;,.=:<>""]
    | '-' (alnum | '_' )
    | '0' ident_char+
  );

cvar = '@@' ( identifier | constant );
ivar = '@' ( identifier | constant );

keyword = 'class'
        | 'BEGIN'
        | 'END'
        | 'alias'
        | 'and'
        | 'begin'
        | 'break'
        | 'case'
        | 'def'
        | 'defined?'
        | 'do'
        | 'else'
        | 'elsif'
        | 'end'
        | 'ensure'
        | 'false'
        | 'for'
        | 'if'
        | 'in'
        | 'module'
        | 'next'
        | 'nil'
        | 'not'
        | 'or'
        | 'redo'
        | 'rescue'
        | 'retry'
        | 'return'
        | 'self'
        | 'super'
        | 'then'
        | 'true'
        | 'undef'
        | 'unless'
        | 'until'
        | 'when'
        | 'while'
        | 'yield'
        | '__ENCODING__'
        | '__FILE__'
        | '__LINE__'
        | '!'
        | '!='
        | '!@'
        | '!~'
        | '&'
        | '&&'
        | '&.'
        | '('
        | ')'
        | '*'
        | '**'
        | '+'
        | '+@'
        | ','
        | '-'
        | '->'
        | '-@'
        | '.'
        | '..'
        | '...'
        | '/'
        | ':'
        | '::'
        | ';'
        | '<'
        | '<<'
        | '<='
        | '<=>'
        | '='
        | '=='
        | '==='
        | '=>'
        | '=~'
        | '>'
        | '>='
        | '>>'
        | '?'
        | '['
        | '[]'
        | '[]='
        | ']'
        | '^'
        | '{'
        | '|'
        | '||'
        | '}'
        | '~'
        | '~@'
;

op_asgn = '&&='
        | '&='
        | '**='
        | '*='
        | '||='
        | '|='
        | '+='
        | '-='
        | '/='
        | '^='
        | '%='
        | '<<='
        | '>>='
;


# Machines #####################################################################


#
# Main/Entry - Beginning Of Line
#
BOL := |*
  '=begin' ( wspace (any - nl)* )? nl => {
    block_comment_start = @ts
    fgoto BLOCK_COMMENT;
  };

  '__END__' nl_eof => {
    fexec pe;
    @__end__seen = true;
    fbreak;
  };

  nl+; # no op

  c_eof => { fbreak; };

  any - nl_eof => {
    fhold;
    fgoto EXPR;
  };
*|;


#
# Expressions
#
EXPR := |*
  nl => {
    if @line_jump
      fexec @line_jump;
      @line_jump = nil
    end
    fgoto BOL;
  };

  wspace+ | line_comment; # no op

  '%' string_term? alnum => {
    raise SyntaxError, 'unknown type of %string'
  };

  ['"`/'] | '%' string_term? (any - alnum) => {
    gen_literal_token
    fnext STRING_CONTENT;
    fbreak;
  };

  '}' => {
    if @literals.empty? || @literals.last.brace_count > 0
      gen_keyword_token
    else
      gen_token(:tSTRING_DEND, '}')
      @literals.last.content_start = @te
      fnext *@literals.last.state;
    end
    fbreak;
  };

  '<<' [\-~]? ident_char+ => {
    indent, id = current_token.match(/^<<([-~]?)(.+)$/).captures
    lit = gen_heredoc_token(indent, '', id)
    fexec lit.content_start = next_bol!;
    fnext HEREDOC_CONTENT;
    fbreak;
  };

  '<<' [\-~]? ['"`'] => {
    indent, delimiter = current_token.match(/^<<([-~]?)(['"`])$/).captures
    id_start = @te
    fgoto HEREDOC_IDENTIFIER;
  };

  number     => { gen_number_token(num_type, num_base, num_flags || []); fbreak; };
  keyword    => { gen_keyword_token;       fbreak; };
  op_asgn    => { gen_op_asgn_token;       fbreak; };
  back_ref   => { gen_token(:tBACK_REF);   fbreak; };
  nth_ref    => { gen_token(:tNTH_REF);    fbreak; };
  gvar       => { gen_token(:tGVAR);       fbreak; };
  cvar       => { gen_token(:tCVAR);       fbreak; };
  ivar       => { gen_token(:tIVAR);       fbreak; };
  identifier => { gen_token(:tIDENTIFIER); fbreak; };
  constant   => { gen_token(:tCONSTANT);   fbreak; };

  c_eof => { fbreak; };
*|;


# Heredoc identifier: <<'ID' | <<"ID" | <<`ID`
# There is no interpolation inside the identifier
# Heredocs of type <<' have no interpolation
HEREDOC_IDENTIFIER := |*

  # This is different from MRI: MRI accepts \n in identifiers,
  # but then it can't find the identifier anywhere after. (MRI bug?)
  # In this case, \n isn't accepted in identifiers.
  nl_eof => {
    raise SyntaxError, 'unterminated here document identifier'
  };

  ['"`'] => {
    if current_token == delimiter
      id = current_token(ts: id_start, ote: -1)
      lit = gen_heredoc_token(indent, delimiter, id)
      fexec lit.content_start = next_bol!;
      fnext HEREDOC_CONTENT;
      fbreak;
    end
  };

  # not a delimiter
  any - ( ['"`'] | c_eof );
*|;


HEREDOC_CONTENT := |*

  c_eof => { raise SyntaxError, @literals.last.unterminated_string_message };

  (any - nl_eof)* nl_eof => {
    lit    = @literals.last
    regexp = if lit.indent == ''
               /#{lit.delimiter}$/
             else
               /[\t\n\v\f\r ]*#{lit.delimiter}$/
             end

    if (current_token =~ regexp) == 0
      # found delimiter => end of heredoc
      gen_string_content_token
      gen_string_end_token
      @line_jump = @te
      fexec lit.restore;
      fnext EXPR;
      fbreak;
    end

    @p = @ts
    fhold;
    fcall COMMON_CONTENT;
  };

*|;


#
# Strings
#
STRING_CONTENT := |*

  c_eof => { raise SyntaxError, @literals.last.unterminated_string_message };

  alnum;

  any - alnum => {
    if current_token == @literals.last.delimiter
      gen_string_content_token
      gen_string_end_token
      fnext EXPR;
      fbreak;
    end

    fhold;
    fcall COMMON_CONTENT;
  };

*|;


COMMON_CONTENT := |*
  c_eof              => { raise SyntaxError, @literals.last.unterminated_string_message };
  '\\' (any - c_eof);
  '#' back_ref       => { gen_interpolation_tokens(:tBACK_REF); fret; };
  '#' nth_ref        => { gen_interpolation_tokens(:tNTH_REF);  fret; };
  '#' gvar           => { gen_interpolation_tokens(:tGVAR);     fret; };
  '#' cvar           => { gen_interpolation_tokens(:tCVAR);     fret; };
  '#' ivar           => { gen_interpolation_tokens(:tIVAR);     fret; };

  '#{' => {
    if @literals.last.interpolates?
      gen_string_content_token
      gen_token(:tSTRING_DBEG)
      @top -= 1
      fnext EXPR;
      fbreak;
    end
  };

  nl => {
    if @line_jump
      fexec @line_jump;
      # content in @te..@line_jump isn't included
      @literals.last.content_buffer << current_token(ts: @literals.last.content_start)
      @literals.last.content_start = @line_jump
      @line_jump = nil
    end
    fret;
  };

  any - nl_eof => {
    if @stack[@top-1] == self.Lex_en_STRING_CONTENT
      fret;
    end
  };
*|;


#
# Block comments (=begin ... \n=end)
#
BLOCK_COMMENT := |*

  c_eof => {
    raise SyntaxError, 'embedded document meets end of file'
  };

  nl '=end' ( wspace (any - nl_eof)* )? nl_eof => {
    #gen_token(:tCOMMENT, current_token(ts: block_comment_start));
    fnext BOL;
    fbreak;
  };

  any - c_eof; # append

*|;



# These scanners are only accessed by explicitly calling them.
# The parsers are responsible to setting special states like the ones below.

#
# Keyword 'class' or after '.' | '&.'
# '<<' is singleton class and not heredoc
#
CLASS := |*
  '<<' => {
    gen_keyword_token
    @top -= 1
    fnext EXPR;
    fbreak;
  };

  any - '<' => { fhold; fret; };
*|;


# ------------------------------------------------------------------------------

}%%
#%

module Mint
  class Lexer

    %%{ write data; }%%

    private

      def advance
        eof = pe = @data.length + 1

        %%{ write exec; }%%

        nil
      end

  end
end