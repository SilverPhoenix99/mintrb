
%%{
#%

# Character classes are in lowercase. e.g.: eof
# Machines/scanners are in uppercase. e.g.: EXPR_BEG
# Actions are in CamelCase. e.g.: DoEof

# The first state is BOL (beginning of line)




# AMBIGUOUS:
# 'a/' - can be a method with a regexp or a value with a div
# 'a -1' - can be a(1.-@) or a.-(1)

# TODO: magic comments


machine Lex;
access @;
variable p @p;
getkey peek; # not the most efficient

# ------------------------------------------------------------------------------
#
# Character Classes
#

c_eof      = 0 | 0x4 | 0x1A; # '\0' | ^D | ^Z
nl         = '\n';
wspace     = (space - nl) | '\\\n';
nl_zlen    = nl | zlen;
nl_eof     = nl | c_eof;
nl_wspace  = nl | wspace;
unicode    = any - ascii;

ident_start = lower | '_' | unicode;
ident_char  = ident_start | digit | upper;

string_term = [QqWwIixrs];


# ------------------------------------------------------------------------------
#
# Comments
#

line_comment = '#' (any - nl_eof)*;


# ------------------------------------------------------------------------------
#
# Numerics
#

# TODO: error => numeric literal without digits

action RacSuf { (num_flags ||= []) << :rational }
action CmxSuf { (num_flags ||= []) << :imaginary }
action IntNum { num_type = :tINTEGER }
action FloNum { num_type = :tFLOAT }
action TrailU { raise SyntaxError, "trailing `_' in number" }

bdigit = [01];
odigit = [0-7];

udigits = digit ( '_'? digit )* ('_' %TrailU)? ; # digits with leading `_' like in 1_000_00

bin_number  =   '0' [bB]   bdigit ( '_'? bdigit )* ('_' %TrailU)? %{ num_base =  2; };
oct_number  =   '0' [oO_]? odigit ( '_'? odigit )* ('_' %TrailU)? %{ num_base =  8; };
dec_number  =   '0' [dD]   udigits                                %{ num_base = 10; };
hex_number  =   '0' [xX]   xdigit ( '_'? xdigit )* ('_' %TrailU)? %{ num_base = 16; };
int_number  = ( '0' | [1-9] ( '_'? digit )* )      ('_' %TrailU)? %{ num_base = 10; };

sign = [+\-];

real_frac = '.' udigits;
real_exp  = [eE] sign? udigits;


real_number =
  int_number
  (
      real_exp
    | real_frac ( real_exp | ('r' %RacSuf)? )?
  ) %FloNum
;

rationable_number = (
    bin_number
  | oct_number
  | dec_number
  | hex_number
  | int_number
) %IntNum ('r' %RacSuf)? ;

number = ( rationable_number | real_number ) ('i' %CmxSuf)? ;

unary_sign = wspace+ sign ( any - (nl_wspace | digit | '=') );


# ------------------------------------------------------------------------------
#
# Identifiers
#

identifier = ident_start ident_char*;
constant   = upper ident_char*;
back_ref   = '$' [''``&+];
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

any_var =
    back_ref %{ token_type = :tBACK_REF }
  | nth_ref  %{ token_type = :tNTH_REF  }
  | gvar     %{ token_type = :tGVAR     }
  | cvar     %{ token_type = :tCVAR     }
  | ivar     %{ token_type = :tIVAR     }
;

heredoc_ident = '<<' [\-~]? ( ['"`'] | ident_char+ );

keyword = 'class'
        | 'BEGIN'
        | 'END'
        | 'alias'
        | 'and'
        | 'begin'
        | 'break'
        | 'case'
        | 'def'
        #| 'defined?' # keyword is used inline due to special '?=' CHAR rule
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
;

operator = '**'
         | '*'
         | '!='
         | '!~'
         | '!'
         | '==='
         | '=='
         | '=~'
         | '=>'
         | '='
         | '<=>'
         | '<='
         | '<<'
         | '<'
         | '>='
         | '>>'
         | '>'
         | '&'
         | '|'
         | '+'
         | '-'
         | '/'
         | '^'
         | '~'
         | '%'
         | '('
         | '['
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


#-------------------------------------------------------------------------------
# Actions

action EofBreak { fbreak; }

action EofLiteralError { raise SyntaxError, @literals.last.unterminated_string_message }

action NewLine {
  if @line_jump
    fexec @line_jump;
    @line_jump = nil
  end
  fcall BOL;
}

action Number {
  # TODO maybe: tUMINUS_NUM
  gen_number_token(num_type, num_base, num_flags || [])
  if fcalled_by?(COMMON_EXPR, OPERATOR_EXPR, reject: false)
    pop_fcall
  end
  fnext EXPR_END;
  fbreak;
}

action UnarySign {
  fexec @te -= 1;
  gen_keyword_token(current_token.lstrip)
  fnext EXPR_BEG;
  fbreak;
}

action StringStart {
  gen_literal_token
  unless REJECTED_CALLS.include?(@cs)
    push_fcall # this is so that strings can identify who called them if needed
  end
  fnext STRING_CONTENT;
  fbreak;
}

action Heredoc {
  indent, id = current_token.match(/^<<([-~]?)(.+)$/).captures

  if id.length == 1 && '\'"`'.include?(id)
    delimiter = id
    id_start = @te
    fcall HEREDOC_IDENTIFIER;
  end

  lit = gen_heredoc_token(indent, '', id)
  fexec lit.content_start = next_bol!;
  push_fcall
  fnext HEREDOC_CONTENT;
  fbreak;
}


# Machines #####################################################################


#
# Main/Entry - Beginning Of Line ###############################################
# Callable state (i.e., it must only be executed through a fcall)
#
BOL := |*
  c_eof => EofBreak;
  nl+; # no op

  '=begin' ( wspace (any - nl)* )? nl => {
    block_comment_start = @ts
    fhold;
    # BLOCK_COMMENT does fret. it must return to BOL.
    fcall BLOCK_COMMENT;
  };

  '__END__' nl_eof => {
    fexec pe;
    @__end__seen = true;
    # no fret or pop_fcall: it's EOF
    fbreak;
  };

  any => {
    fhold;
    # Returns to caller (BOL ends at beginning of a line).
    # \n sensitive states must take care of it,
    # or they must setup the return state (fcall or push_fcall).
    fret;
  };
*|;


# Expressions ##################################################################
# Expressions are not callable.
# They are transitioned to through fnext or fgoto.

EXPR_BEG := |*
  wspace+; # ignore
  nl => NewLine; # call BOL, return, and try again

  sign number   => Number;
  heredoc_ident => Heredoc;
  '/'           => StringStart;

  '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  '%' string_term? (ascii - alnum - c_eof) => StringStart;

  ( 'defined?' | keyword ) ':' [^:] => { # ignore last char

    fexec @te -= 1;

    if @in_cmd
      # label not allowed
      fexec @te -= 1; # remove ':'
      gen_keyword_token
    else
      gen_token(:tLABEL)
      fnext EXPR_LABELARG;
    end

    fbreak;
  };

    'defined?' [^=:]
  | keyword [^:] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?]       %{ type = :tFID } )? ':' [^:] => { # ignore last char

    fexec @te -= 1;

    if @in_cmd
      # label not allowed
      fexec @te -= 1; # remove ':'
      gen_token(type)
      fnext EXPR_CMDARG;
    else
      gen_token(:tLABEL)
      fnext EXPR_LABELARG;
    end

    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=:] %{ type = :tFID } )? => {

    if type == :tFID
      fexec @te -= 1;
    end

    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;

  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_ARG := |*
  # TODO EXPR_ARG is always accepting EXPR_LABEL. Verify when not to allow EXPR_LABEL with EXPR_ARG

  unary_sign            => UnarySign;
  wspace+ sign number   => Number;
  wspace+ heredoc_ident => Heredoc;
  wspace+ '/'           => StringStart;

  wspace+ '::' => {
    gen_keyword_token('::')
    fnext EXPR_BEG;
    fbreak;
  };

  '?' space => { # exclude '?\\\n': it resolves to '\n' as if '?\\n'
    fhold;
    gen_keyword_token('?')
    fnext EXPR_BEG;
    fbreak;
  };

  wspace* '%=' => {
    fexec @te - 2;
    fcall COMMON_EXPR;
  };

  wspace+ '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  wspace+ '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  wspace+ '%' string_term? (ascii - alnum - c_eof) => StringStart;

  (
      'defined?'
    | keyword
    | ( identifier | constant ) [!?]?
  ) ':' [^:] => { # ignore last char
    fexec @te -= 1;
    gen_token(:tLABEL)
    fnext EXPR_LABELARG;
    fbreak;
  };

    'defined?' [^=:]
  | keyword [^:] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=:] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

# After keyword 'class'
# '<<' is left shift (singleton class) and not heredoc
EXPR_CLASS := |*
  wspace+; # ignore
  nl => NewLine; # call BOL, return, and try again

    '<'
  | '<<' => {
    @in_cmd = true
    gen_keyword_token
    fnext EXPR_BEG;
    fbreak;
  };

  sign number => Number;
  '/'         => StringStart;

  '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  '%' string_term? (ascii - alnum - c_eof) => StringStart;

  'defined?' [^=] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  keyword => {
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_CMDARG := |*
  unary_sign            => UnarySign;
  wspace+ sign number   => Number;
  wspace+ heredoc_ident => Heredoc;
  wspace+ '/'           => StringStart;

  wspace+ '::' => {
    gen_keyword_token('::')
    fnext EXPR_BEG;
    fbreak;
  };

  '?' space => { # exclude '?\\\n': it resolves to '\n' as if '?\\n'
    fhold;
    gen_keyword_token('?')
    fnext EXPR_BEG;
    fbreak;
  };

  wspace* '%=' => {
    fexec @te - 2;
    fcall COMMON_EXPR;
  };

  wspace+ '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  wspace+ '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  wspace+ '%' string_term? (ascii - alnum - c_eof) => StringStart;

  (
      'defined?'
    | keyword
    | ( identifier | constant ) [!?]?
  ) ':' [^:] => { # ignore last char
    fexec @te -= 1;
    gen_token(:tLABEL)
    fnext EXPR_LABELARG;
    fbreak;
  };

    'defined?' [^=:]
  | keyword [^:] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=:] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_DOT := |*
  wspace+; # ignore
  nl => NewLine; # call BOL, return, and try again

  '`' => {
    gen_keyword_token
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  '::' => { gen_keyword_token; fbreak; };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=]  %{ type = :tFID } )?
  => {
    if type == :tFID
        fexec @te -= 1; # ignore last char
    end
    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  any => { fhold; fcall OPERATOR_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_END := |*
  wspace+; # ignore

  '::' => {
    gen_keyword_token
    fnext EXPR_DOT;
    fbreak;
  };

  ':' | '?' => {
    gen_keyword_token
    fnext EXPR_BEG;
    fbreak;
  };

  'defined?' [^=] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  keyword => {
    gen_keyword_token
    fbreak;
  };

  (   identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_ENDARG := |*
  wspace+; # ignore

  '::' => {
    gen_keyword_token
    fnext EXPR_DOT;
    fbreak;
  };

  ':' | '?' => {
    gen_keyword_token
    fnext EXPR_BEG;
    fbreak;
  };

  'defined?' [^=] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  keyword => {
    gen_keyword_token
    fbreak;
  };

  (   identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext EXPR_END;
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_ENDFN := |*
  wspace+; # ignore

  '::' => {
    gen_keyword_token
    fnext EXPR_DOT;
    fbreak;
  };

  ':' | '?' => {
    gen_keyword_token
    fnext EXPR_BEG;
    fbreak;
  };

  ( 'defined?' | keyword ) ':' [^:] => { # ignore last char

    fexec @te -= 1;

    if @in_cmd
      # label not allowed
      fexec @te -= 1; # remove ':'
      gen_keyword_token
    else
      gen_token(:tLABEL)
      fnext EXPR_LABELARG;
    end

    fbreak;
  };

  'defined?' [^=:] => {
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  keyword => {
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?]       %{ type = :tFID } )? ':' [^:] => { # ignore last char

    fexec @te -= 1;

    if @in_cmd
      # label not allowed
      fexec @te -= 1; # remove ':'
      gen_token(type)
      fnext EXPR_CMDARG;
    else
      gen_token(:tLABEL)
      fnext EXPR_LABELARG;
    end

    fbreak;
  };

  (   identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=:] %{ type = :tFID } )? => {

    if type == :tFID
      fexec @te -= 1;
    end

    gen_token(type)
    fnext EXPR_END;
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_FNAME := |*
  wspace+; # ignore
  nl => NewLine; # call BOL, return, and try again

  '`' => {
    gen_keyword_token
    fnext EXPR_ENDFN;
    fbreak;
  };

  '::' => {
    gen_keyword_token
    fnext EXPR_DOT;
    fbreak;
  };

  back_ref | nth_ref => {
    gen_token(:tGVAR)
    fnext EXPR_END;
    fbreak;
  };

  heredoc_ident => Heredoc;

  # gen_keyword_token changes the state
    'defined?' [^=] %{ ote = 1 }
  | keyword         %{ ote = 0 }
  => {
    if ote > 0
        fexec @te -= ote;
    end
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER; ote = 0 }
    | constant   %{ type = :tCONSTANT;   ote = 0 }
  )
  (
      [!?] [^=]  %{ type = :tFID;        ote = 1 } # ignore last char
    | '=' [^~>=] %{ type = :tIDENTIFIER; ote = 1 } # ignore last char
    | '==>'      %{ type = :tIDENTIFIER; ote = 2 } # ignore the '=>' part
  )? => {
    if ote > 0
        fexec @te -= ote;
    end
    gen_token(type)
    fnext EXPR_ENDFN;
    fbreak;
  };

  any => { fhold; fcall OPERATOR_EXPR; };
*|;

# ------------------------------------------------------------------------------

# Equivalent to EXPR_ARG|EXPR_LABELED in MRI.
EXPR_LABELARG := |*
  nl => {
    if @line_jump
      fexec @line_jump;
      @line_jump = nil
    end

    if @in_kwarg
      @in_cmd = true
      gen_token(:kNL)
      push_fcall
      fnext BOL;
      fbreak;
    end

    fcall BOL;
  };

  wspace* sign number   => Number;
  wspace* unary_sign    => UnarySign;
  wspace* heredoc_ident => Heredoc;
  wspace* '/'           => StringStart;

  '?' space => { # exclude '?\\\n': it resolves to '\n' as if '?\\n'
    fhold;
    gen_keyword_token('?')
    fnext EXPR_BEG;
    fbreak;
  };

  wspace* '%=' => {
    fexec @te - 2;
    fcall COMMON_EXPR;
  };

  wspace* '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  wspace* '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  wspace* '%' string_term? (ascii - alnum - c_eof) => StringStart;

  (
      'defined?'
    | keyword
    | ( identifier | constant ) [!?]?
  ) ':' [^:] => { # ignore last char
    fexec @te -= 1;
    gen_token(:tLABEL)
    fbreak;
  };

    'defined?' [^=:]
  | keyword [^:] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  (
      identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=:] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext EXPR_END;
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;

# ------------------------------------------------------------------------------

EXPR_MID := |*
  wspace+; # ignore

  sign number   => Number;
  heredoc_ident => Heredoc;
  '/'           => StringStart;

  '%' string_term? c_eof                   => { raise SyntaxError, 'unterminated quoted string meets end of file' };
  '%' string_term? (alnum | unicode)       => { raise SyntaxError, 'unknown type of %string' };
  '%' string_term? (ascii - alnum - c_eof) => StringStart;

  'defined?' [^=] => { # ignore last char
    fexec @te -= 1;
    gen_keyword_token
    fbreak;
  };

  keyword => {
    gen_keyword_token
    fbreak;
  };

  (   identifier %{ type = :tIDENTIFIER }
    | constant   %{ type = :tCONSTANT }
  ) ( [!?] [^=] %{ type = :tFID } )? => {
    if type == :tFID
      fexec @te -= 1;
    end
    gen_token(type)
    fnext *(@in_cmd ? EXPR_CMDARG : EXPR_ARG);
    fbreak;
  };

  any => { fhold; fcall COMMON_EXPR; };
*|;


#
# Shared expressions ###########################################################
#


# Expressions common to EXPR_DOT and EXPR_FNAME
OPERATOR_EXPR := |*

    [!+\-~] '@'
  | '[]='
  | '[]'
  | operator => {
    gen_keyword_token
    pop_fcall
    fnext EXPR_ARG;
    fbreak;
  };

  any => { fhold; fgoto COMMON_EXPR; };
*|;


# Expressions that can exist anywhere
COMMON_EXPR := |*
  c_eof => EofBreak;      # breaks with no fret (not needed at EOF)
  wspace+ | line_comment; # no op

  nl => {
    if @line_jump
      fexec @line_jump;
      @line_jump = nil
    end

    gen_token(:kNL)
    pop_fcall
    push_fcall EXPR_BEG
    fnext BOL;
    fbreak;
  };

  nl wspace* '.' [^.] => {
    fhold;
    pop_fcall

    if @line_jump
      fexec @line_jump;
      @line_jump = nil
      push_fcall EXPR_BEG
      fnext BOL;
    else
      gen_keyword_token('.')
      fnext EXPR_DOT;
    end

    fbreak;
  };

  nl wspace* '&.' => {
    pop_fcall

    if @line_jump
      fexec @line_jump;
      @line_jump = nil
      push_fcall EXPR_BEG
      fnext BOL;
    else
      gen_keyword_token('&.')
      fnext EXPR_DOT;
    end

    fbreak;
  };

    '.'
  | '&.' => {
    gen_keyword_token
    pop_fcall
    fnext EXPR_DOT;
    fbreak;
  };

  number => Number;

  '.' digit => {
    raise SyntaxError, 'no .<digit> floating literal anymore; put 0 before dot'
  };

  # TODO ' and " are accepted as labels when label_possible? == true
  [''""``/] => StringStart;

  op_asgn => {
    gen_op_asgn_token
    pop_fcall
    fnext EXPR_BEG;
    fbreak;
  };

    '&&'
  | '||'
  | '...'
  | '..'
  | '::'
  | ','
  | '\\'
  | operator => {
    gen_keyword_token
    pop_fcall
    fnext EXPR_BEG;
    fbreak;
  };

    '->'
  | ')'  => {
    gen_keyword_token
    pop_fcall
    fnext EXPR_ENDFN;
    fbreak;
  };

  ':' ( wspace+ | line_comment ) => {
    gen_keyword_token(':')
    pop_fcall
    fnext EXPR_BEG;
    fbreak;
  };

  ':' nl => {
    fhold;
    gen_keyword_token(':')

    # BOL will do a fret, and we want to continue in EXPR_BEG:
    pop_fcall
    push_fcall EXPR_BEG

    fnext BOL;
    fbreak;
  };

  ':' [''""] => StringStart;

  ':' => {
    gen_literal_token
    pop_fcall
    fnext EXPR_FNAME;
    fbreak;
  };

  ';' => {
    gen_keyword_token
    @in_cmd = true
    pop_fcall
    fnext EXPR_BEG;
    fbreak;
  };

  ']' => {
    gen_keyword_token
    pop_fcall
    fnext EXPR_ENDARG;
    fbreak;
  };

  '}' => {
    if @literals.empty? || @literals.last.brace_count > 0
      gen_keyword_token
      fnext EXPR_ENDARG;
    else
      gen_token(:tSTRING_DEND, '}')
      @literals.last.content_start = @te
      fnext *@literals.last.state;
    end
    fbreak;
  };

  #identifier    => { gen_token(:tIDENTIFIER); fbreak; };
  #constant      => { gen_token(:tCONSTANT);   fbreak; };

  any_var => {
    gen_token(token_type);
    pop_fcall
    fnext EXPR_END;
    fbreak;
  };

  '?' (alnum | '_') ident_char => {
    fexec @ts + 1; # don't consume identifier
    pop_fcall
    gen_keyword_token('?')
    fnext EXPR_BEG;
    fbreak;
  };

  '?' => {
    pop_fcall
    fgoto CHAR;
  };

  # if it failed to parse gvar/ivar/cvar:

  '$' ( c_eof | nl_wspace ) => {
    raise SyntaxError, "`$' without identifiers is not allowed as a global variable name"
  };

  '$' any => {
    raise SyntaxError, "`#{current_token}' is not allowed as a global variable name"
  };

  '@' ( c_eof | nl_wspace ) => {
    raise SyntaxError, "`@' without identifiers is not allowed as an instance variable name"
  };

  '@' any => {
    raise SyntaxError, "`#{current_token}' is not allowed as an instance variable name"
  };

  '@@' ( c_eof | nl_wspace ) => {
    raise SyntaxError, "`@@' without identifiers is not allowed as a class variable name"
  };

  '@' any => {
    raise SyntaxError, "`#{current_token}' is not allowed as a class variable name"
  };

  '?' space => { # exclude '?\\\n': it resolves to '\n' as if '?\\n'
    # this is different from MRI: in MRI it gives this as a warning,
    # but then it gives "SyntaxError: syntax error, unexpected '?'" from the parser
    i = " \n\f\r\t\v".index(current_token[-1])
    c = 'snfrtv'[i]
    raise SyntaxError, "invalid character syntax; use ?\\#{c}"
  };

  '?' c_eof => { raise SyntaxError, 'incomplete character syntax' };

  any - ident_char => { raise SyntaxError, "Invalid char `#{current_token}' in expression at #@ts"; };

  any => { raise "Don't know what to do with `#{current_token}' at #@ts" };
*|;


#
# Block comments ###############################################################
# =begin
#  ...
# =end
#
BLOCK_COMMENT := |*
  c_eof => { raise SyntaxError, 'embedded document meets end of file' };

  nl '=end' ( wspace (any - nl_eof)* )? nl_eof => {
    #gen_token(:tCOMMENT, current_token(ts: block_comment_start));
    fret;
  };

  any; # append
*|;


#
# Heredocs #####################################################################
#

#
# Heredoc identifier: <<'ID' | <<"ID" | <<`ID`
# There is no interpolation inside the identifier
# Heredocs of type <<' have no interpolation in content
# Heredoc existence condition:
#     ( [EXPR_BEG, EXPR_FNAME, EXPR_LABELARG, EXPR_MID].include?(@cs) )
#  || ( [EXPR_ARG, EXPR_CMDARG].include?(@cs) && ( @ts == 0 || @data[@ts - 1] =~ / \f\t\r\v/ ) )
HEREDOC_IDENTIFIER := |*

  # This is different from MRI: MRI accepts \n in identifiers,
  # but then it can't find the identifier anywhere after. (MRI bug)
  # In this case, \n isn't accepted in identifiers.
  nl_eof => { raise SyntaxError, 'unterminated here document identifier' };

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
  any;
*|;


HEREDOC_CONTENT := |*
  c_eof => EofLiteralError;

  (any - nl_eof)* nl_eof => {
    lit = @literals.last
    if lit.delimiter?(current_token)
      # found delimiter => end of heredoc
      gen_string_content_token
      gen_string_end_token
      @line_jump = @te
      fexec lit.restore;
      fnext EXPR_END;
      fbreak;
    end

    fexec @ts;
    fcall COMMON_CONTENT;
  };

*|;


#
# Strings ######################################################################
#
STRING_CONTENT := |*
  c_eof => EofLiteralError;

  alnum;

  ( any - alnum ) ':' [^:] => {
    fhold; # hold the last char [^:]

    # if it can't be labeled, then hold the last char ':'

    is_labeled = fcalled_by?(EXPR_ARG, EXPR_CMDARG, EXPR_LABELARG) || ( #!cond? && # TODO
                 fcalled_by?(EXPR_BEG, EXPR_ENDFN))

    tok = if is_labeled
            current_token(ote: -1)
          else
            fexec @te -= 1; # hold the last char ':'
            current_token
          end

    unless @literals.last.delimiter?(tok)
      fexec @ts;
      fcall COMMON_CONTENT;
    end

    # found delimiter => end string

    gen_string_content_token
    gen_string_end_token
    pop_fcall
    fnext *(is_labeled ? EXPR_BEG : EXPR_END);
    fbreak;
  };

  any => {
    unless @literals.last.delimiter?(current_token)
      fexec @ts;
      fcall COMMON_CONTENT;
    end

    # found delimiter => end string

    gen_string_content_token
    gen_string_end_token
    fnext EXPR_END;
    pop_fcall
    fbreak;
  };

*|;


#
# String Content ###############################################################
# Content that is common to strings and heredocs
#
COMMON_CONTENT := |*
  c_eof => EofLiteralError;

  '\\' (any - c_eof) => {
    @literals.last.commit_indent
  };

  '#' any_var => { gen_interpolation_tokens(token_type); fret; };

  '#{' => {
    @literals.last.commit_indent
    if @literals.last.interpolates?
      gen_string_content_token
      gen_token(:tSTRING_DBEG)
      pop_fcall
      fnext EXPR_BEG;
      fbreak;
    end
  };

  nl => {
    lit = @literals.last
    lit.line_indent = 0

    if @line_jump
      # content in @te..@line_jump isn't included
      lit.content_buffer << current_token(ts: lit.content_start)
      lit.content_start = @line_jump
      fexec @line_jump;
      @line_jump = nil
    end

    fret;
  };

  ' ' => {
    if @literals.last.dedents?
      @literals.last.tap do |lit|
        lit.line_indent += 1 if lit.line_indent >= 0
      end
    end

    if fcalled_by?(STRING_CONTENT)
      # no need to fhold -> if it reached here, then it wasn't the delimiter
      fret;
    end
  };

  '\t' => {
    if @literals.last.dedents?
      @literals.last.tap do |lit|
        if lit.line_indent >= 0
          w = lit.line_indent / tab_width + 1
          lit.line_indent = w * tab_width
        end
      end
    end

    if fcalled_by?(STRING_CONTENT)
      # no need to fhold -> if it reached here, then it wasn't the delimiter
      fret;
    end
  };

  any => {
    @literals.last.commit_indent
    if fcalled_by?(STRING_CONTENT)
      # no need to fhold -> if it reached here, then it wasn't the delimiter
      fret;
    end
  };
*|;

#
# Single characters (e.g.: ?a) #################################################
#

ctrl_char = '\\' ( 'c' | 'C-' );
meta_char = '\\M-';

control_escape = ctrl_char meta_char? | meta_char ctrl_char?;

unicode_escape = '\\u' xdigit{4}
               | '\\u{' xdigit{1,6} '}';

octal_escape = '\\' odigit{1,3};
hex_escape   = '\\x' xdigit{1,2};

CHAR := |*
  c_eof => { raise SyntaxError, 'incomplete character syntax' };

    unicode_escape
  | control_escape (ascii - '\\')
  | control_escape? (
        octal_escape
      | hex_escape
      | '\\' (ascii - [CMcux0-7])
  ) => {
    gen_char_token
    fnext EXPR_END;
    fbreak;
  };

  # MRI gives different errors:
  # it gives "unexpected tINTEGER" or "unexpected tIDENTIFIER"
  '\\u'      => { raise SyntaxError, 'invalid Unicode escape' };
  '\\x'      => { raise SyntaxError, 'invalid hex escape' };
  '\\' [cCM] => { raise SyntaxError, 'Invalid escape character syntax' };

  '\\' any => {
    gen_char_token(current_token(ots: 1))
    fnext EXPR_END;
    fbreak;
  };

  any => {
    gen_char_token
    fnext EXPR_END;
    fbreak;
  };
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