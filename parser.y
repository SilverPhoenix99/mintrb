class Mint::Parser

token
  kALIAS       kAMPER      kAND        kANDDOT      kANDOP        kAPP_BEGIN      kAPP_END      kAREF
  kASET        kASSIGN     kASSOC      kBACKSLASH   kBACKTICK     kBEGIN          kBIN_AND      kBREAK
  kCASE        kCLASS      kCMP        kCOLON       kCOLON2       kCOLON3         kCOMMA        kDEF
  kDEFINED     kDIV        kDO         kDOT         kDOT2         kDOT3           kDO_BLOCK     kDO_COND
  kDO_LAMBDA   kDSTAR      kELSE       kELSIF       kEND          kENSURE         kEQ           kEQQ
  kFALSE       kFOR        kGEQ        kGREATER     kIF           kIF_MOD         kIN           kLAMBDA
  kLAMBEG      kLBRACE     kLBRACE2    kLBRACE_ARG  kLBRACK       kLBRACK2        kLEQ          kLESS
  kLPAREN      kLPAREN2    kLPAREN_ARG kLSHIFT      kMATCH        kMINUS          kMODULE       kMUL
  kNEG         kNEQ        kNEXT       kNIL         kNL           kNMATCH         kNOT          kNOTOP
  kOR          kOROP       kPERCENT    kPIPE        kPLUS         kPOW            kQMARK        kRBRACE
  kRBRACK      kREDO       kRESCUE     kRESCUE_MOD  kRETRY        kRETURN         kRPAREN       kRSHIFT
  kSELF        kSEMICOLON  kSPACE      kSTAR        kSUPER        kTHEN           kTRUE         kUMINUS
  kUMINUS_NUM  kUNDEF      kUNLESS     kUNLESS_MOD  kUNTIL        kUNTIL_MOD      kUPLUS        kWHEN
  kWHILE       kWHILE_MOD  kXOR        kYIELD       k__ENCODING__ k__FILE__       k__LINE__     tBACK_REF
  tCHAR        tCONSTANT   tCVAR       tFID         tFLOAT        tGVAR           tIDENTIFIER   tIMAGINARY
  tINTEGER     tIVAR       tLABEL      tLABEL_END   tNTH_REF      tOP_ASGN        tQSYMBOLS_BEG tQWORDS_BEG
  tRATIONAL    tREGEXP_BEG tREGEXP_END tSPACE       tSTRING_BEG   tSTRING_CONTENT tSTRING_DBEG  tSTRING_DEND
  tSTRING_DVAR tSTRING_END tSYMBEG     tSYMBOLS_BEG tWORDS_BEG    tXSTRING_BEG

prechigh
  right     kNOTOP kNEG kUPLUS
  right     kPOW
  right     kUMINUS_NUM kUMINUS
  left      kMUL kDIV kPERCENT
  left      kPLUS kMINUS
  left      kLSHIFT kRSHIFT
  left      kBIN_AND
  left      kPIPE kXOR
  left      kGREATER kGEQ kLESS kLEQ
  nonassoc  kCMP kEQ kEQQ kNEQ kMATCH kNMATCH
  left      kANDOP
  left      kOROP
  nonassoc  kDOT2 kDOT3
  right     kQMARK kCOLON
  left      kRESCUE_MOD
  right     kASSIGN tOP_ASGN
  nonassoc  kDEFINED
  right     kNOT
  left      kOR kAND
  nonassoc  kIF_MOD kUNLESS_MOD kWHILE_MOD kUNTIL_MOD
  nonassoc  kLBRACE_ARG
  nonassoc  tLOWEST
preclow

rule

program :
    top_compstmt

top_compstmt :
    top_stmts opt_terms

top_stmts :
    { result = [] } # nothing
  | top_stmt
  | top_stmts terms top_stmt { result = val[0] + [val[2]] }
  | error top_stmt { result = val[1] }

top_stmt :
    stmt
  | kAPP_BEGIN kLBRACE2 top_compstmt kRBRACE { result = val[0], val[2] }

bodystmt :
    compstmt opt_rescue opt_else opt_ensure
    {
      compstmt, opt_rescue, opt_else, opt_ensure = val

      ( warn "else without rescue is useless"; opt_else = [] ) if opt_rescue.empty? && !opt_else.empty?

      if opt_ensure.empty?
        if opt_rescue.empty?
          result = compstmt
        else
          result = [:kENSURE, 'ensure', -1, -1], compstmt, opt_rescue, opt_else, []
        end
      else
        result = opt_ensure[0], compstmt, opt_rescue, opt_else, opt_ensure[1]
      end
    }

compstmt :
    stmts opt_terms

stmts :
    { result = [] } # nothing
  | stmt_or_begin
  | stmts terms stmt_or_begin { result = val[0] + [val[2]] }
  | error stmt { result = val[1] }

stmt_or_begin :
    stmt
  | kAPP_BEGIN
    {
      raise SyntaxError, "BEGIN is permitted only at toplevel"
    }
    kLBRACE2 top_compstmt kRBRACE

stmt :
    kALIAS fitem { @lexer.state = :EXPR_FNAME } fitem { result = val[0], val[1], val[3] }
  | kALIAS tGVAR tGVAR { result = val }
  | kALIAS tGVAR tBACK_REF { result = val }
  | kALIAS tGVAR tNTH_REF
    {
      raise SyntaxError, "can't make alias for the number variables"
    }
  | kUNDEF undef_list     { result = val }
  | stmt kIF_MOD expr     { result = val[1], val[2], val[0], [] }
  | stmt kUNLESS_MOD expr { result = val[1], val[2], val[0], [] }
  | stmt kWHILE_MOD expr  { result = val[1], val[2], val[0] }
  | stmt kUNTIL_MOD expr  { result = val[1], val[2], val[0] }
  | stmt kRESCUE_MOD stmt { result = [:kENSURE, 'ensure', -1, -1], val[0], [val[1], val[2]], [], [] }
  | kAPP_END kLBRACE2 compstmt kRBRACE
    {
      warn "END in method; use at_exit" if @in_def || @in_single
      result = val[0], val[2]
    }
  | command_asgn
  | mlhs kASSIGN command_call { result = val[1], val[0], val[2] }
  | var_lhs tOP_ASGN command_call { result = val[1], val[0], val[2] }
  | primary kLBRACK2 opt_call_args rbracket tOP_ASGN command_call { result = val[4], [ val[1], val[0], val[2] ], val[5] }
  | primary call_op tIDENTIFIER tOP_ASGN command_call { result = val[3], [ val[1], val[2], val[0] ], val[4] }
  | primary call_op tCONSTANT tOP_ASGN command_call   { result = val[3], [ val[1], val[2], val[0] ], val[4] }
  | primary kCOLON2 tCONSTANT tOP_ASGN command_call   { result = val[3], [ val[1], val[2], val[0] ], val[4] }
  | primary kCOLON2 tIDENTIFIER tOP_ASGN command_call { result = val[3], [ val[1], val[2], val[0] ], val[4] }
  | backref tOP_ASGN command_call { result = val[1], val[0], val[2] }
  | lhs kASSIGN mrhs { result = val[1], val[0], val[2] }
  | mlhs kASSIGN mrhs_arg { result = val[1], val[0], val[2] }
  | expr

command_asgn :
    lhs kASSIGN command_call { result = val[1], val[0], val[2] }
  | lhs kASSIGN command_asgn { result = val[1], val[0], val[2] }

expr :
    command_call
  | expr kAND expr      { result = val[1], val[0], val[2] }
  | expr kOR expr       { result = val[1], val[0], val[2] }
  | kNOT opt_nl expr    { result = val[0], val[2] }
  | kNOTOP command_call { result = val[0], val[2] }
  | arg

command_call :
    command
  | block_command

block_command :
    block_call
  | block_call call_op2 operation2 command_args
    {
      result = val[1], val[0], val[2], val[3]
    }

cmd_brace_block :
    kLBRACE_ARG opt_block_param compstmt kRBRACE { result = val[0], val[1], val[2] }

fcall :
    operation

command :
    fcall command_args    =tLOWEST
    {
      puts "command > fcall command_args"
      result = vcall_node, [], val[0], val[1]
    }
  | fcall command_args cmd_brace_block
    {
      puts "fcall command_args cmd_brace_block"
      #block_dup_check($2,$3);
      result = vcall_node, [], val[0], val[1] + [val[2]]
    }
  | primary call_op operation2 command_args    =tLOWEST
    {
      result = val[1], val[0], val[2], val[3]
    }
  | primary call_op operation2 command_args cmd_brace_block
    {
      #block_dup_check($4,$5);
      result = val[1], val[0], val[2], val[3] + [val[4]]
    }
  | primary kCOLON2 operation2 command_args    =tLOWEST
    {
      result = val[1], val[0], val[2], val[3]
    }
  | primary kCOLON2 operation2 command_args cmd_brace_block
    {
      #block_dup_check($4,$5);
      result = val[1], val[0], val[2], val[3] + [val[4]]
    }
  | kSUPER command_args { result = vcall_node, [], val[0], val[1] }
  | kYIELD command_args { result = vcall_node, [], val[0], val[1] }
  | kRETURN call_args   { result = vcall_node, [], val[0], val[1] }
  | kBREAK call_args    { result = vcall_node, [], val[0], val[1] }
  | kNEXT call_args     { result = vcall_node, [], val[0], val[1] }

mlhs :
    mlhs_basic
  | kLPAREN mlhs_inner rparen { result = val[1] }

mlhs_inner :
    mlhs_basic
  | kLPAREN mlhs_inner rparen { result = val[1] }

mlhs_basic :
    mlhs_head
  | mlhs_head mlhs_item                        { result = val[0] + val[1] }
  | mlhs_head kSTAR mlhs_node                  { result = val[0] + [[val[1], val[2]]] }
  | mlhs_head kSTAR mlhs_node kCOMMA mlhs_post { result = val[0] + [[val[1], val[2]]] + val[4] }
  | mlhs_head kSTAR                            { result = val[0] + [[val[1], []]] }
  | mlhs_head kSTAR kCOMMA mlhs_post           { result = val[0] + [[val[1], []]] + val[3] }
  | kSTAR mlhs_node                            { result = [val] }
  | kSTAR mlhs_node kCOMMA mlhs_post           { result = [[val[0], val[1]]] + val[2] }
  | kSTAR                                      { result = [[val[0], []]] }
  | kSTAR kCOMMA mlhs_post                     { result = [[val[0], []]] + val[2] }

mlhs_item :
    mlhs_node
  | kLPAREN mlhs_inner rparen { result = val[1] }

mlhs_head :
    mlhs_item kCOMMA
  | mlhs_head mlhs_item kCOMMA  { result = val[0] + val[1] }

mlhs_post :
    mlhs_item
  | mlhs_post kCOMMA mlhs_item { result = val[0] + val[1] }

mlhs_node :
    user_variable
    {
      # assignable($1, 0)
      assignable("mlhs_node > user_variable", val)
    }
  | keyword_variable
    {
      # assignable($1, 0)
      assignable("mlhs_node > keyword_variable", val)
    }
  | primary kLBRACK2 opt_call_args rbracket  { result = val[1], val[0], val[2] }
  | primary call_op tIDENTIFIER { result = val[1], val[0], val[2] }
  | primary kCOLON2 tIDENTIFIER { result = val[1], val[0], val[2] }
  | primary call_op tCONSTANT   { result = val[1], val[0], val[2] }
  | primary kCOLON2 tCONSTANT
    {
      raise SyntaxError, "dynamic constant assignment" if @in_def || @in_single
      result = val[1], val[0], val[2]
    }
  | kCOLON3 tCONSTANT
    {
      raise SyntaxError, "dynamic constant assignment" if @in_def || @in_single
      result = val
    }
  | backref
    {
      puts "mlhs_node > backref : #{val.inspect}"
      #backref_error($1);
    }

lhs :
    user_variable
    {
      # assignable($1, 0)
      assignable("lhs > user_variable", val)
    }
  | keyword_variable
    {
      # assignable($1, 0)
      assignable("lhs > keyword_variable", val)
    }
  | primary kLBRACK2 opt_call_args rbracket { result = val[1], val[0], val[2] }
  | primary call_op tIDENTIFIER { result = val[1], val[0], val[2] }
  | primary kCOLON2 tIDENTIFIER { result = val[1], val[0], val[2] }
  | primary call_op tCONSTANT   { result = val[1], val[0], val[2] }
  | primary kCOLON2 tCONSTANT
    {
      raise SyntaxError, "dynamic constant assignment" if @in_def || @in_single
      result = val[1], val[0], val[2]
    }
  | kCOLON3 tCONSTANT
    {
      raise SyntaxError, "dynamic constant assignment" if @in_def || @in_single
      result = val
    }
  | backref
    {
      puts "lhs > backref : #{val.inspect}"
      #backref_error($1);
    }

cname :
    tIDENTIFIER
    {
      raise SyntaxError, "class/module name must be CONSTANT"
    }
  | tCONSTANT

cpath :
    kCOLON3 cname { result = val }
  | cname
  | primary kCOLON2 cname { result = val[1], val[0], val[2] }

fname :
    tIDENTIFIER
  | tCONSTANT
  | tFID
  | op { @lexer.state = :EXPR_ENDFN }
  | reswords { @lexer.state = :EXPR_ENDFN }

fsym :
    fname
  | symbol

fitem :
    fsym
  | dsym

undef_list :
    fitem { result = val }
  | undef_list kCOMMA { @lexer.state = :EXPR_FNAME } fitem { result = val[0] + [val[1]] }

op :
    kPIPE
  | kXOR
  | kBIN_AND
  | kCMP
  | kEQ
  | kEQQ
  | kMATCH
  | kNMATCH
  | kGREATER
  | kGEQ
  | kLESS
  | kLEQ
  | kNEQ
  | kLSHIFT
  | kRSHIFT
  | kPLUS
  | kMINUS
  | kMUL
  | kSTAR
  | kDIV
  | kPERCENT
  | kPOW
  | kDSTAR
  | kNOTOP
  | kNEG
  | kUPLUS
  | kUMINUS
  | kAREF
  | kASET
  | kBACKTICK

reswords :
    k__LINE__
  | k__FILE__
  | k__ENCODING__
  | kAPP_BEGIN
  | kAPP_END
  | kALIAS
  | kAND
  | kBEGIN
  | kBREAK
  | kCASE
  | kCLASS
  | kDEF
  | kDEFINED
  | kDO
  | kELSE
  | kELSIF
  | kEND
  | kENSURE
  | kFALSE
  | kFOR
  | kIN
  | kMODULE
  | kNEXT
  | kNIL
  | kNOT
  | kOR
  | kREDO
  | kRESCUE
  | kRETRY
  | kRETURN
  | kSELF
  | kSUPER
  | kTHEN
  | kTRUE
  | kUNDEF
  | kWHEN
  | kYIELD
  | kIF
  | kUNLESS
  | kWHILE
  | kUNTIL

arg :
    lhs kASSIGN arg { result = val[1], val[0], val[2] }
  | lhs kASSIGN arg kRESCUE_MOD arg
    {
      result = [:kENSURE, 'ensure', -1, -1], [val[1], val[0], val[2]], [val[3], val[4]], [], []
    }
  | var_lhs tOP_ASGN arg { result = val[1], val[0], val[2] }
  | var_lhs tOP_ASGN arg kRESCUE_MOD arg
    {
      result = [:kENSURE, 'ensure', -1, -1], [val[1], val[0], val[2]], [val[3], val[4]], [], []
    }
  | primary kLBRACK2 opt_call_args rbracket tOP_ASGN arg
    {
      result = val[4], [val[1], val[0], val[2]], val[5]
    }
  | primary call_op tIDENTIFIER tOP_ASGN arg
    {
      result = val[3], [val[1], val[0], val[2]], val[4]
    }
  | primary call_op tCONSTANT tOP_ASGN arg
    {
      result = val[3], [val[1], val[0], val[2]], val[4]
    }
  | primary kCOLON2 tIDENTIFIER tOP_ASGN arg
    {
      result = val[3], [val[1], val[0], val[2]], val[4]
    }
  | primary kCOLON2 tCONSTANT tOP_ASGN arg
    {
      result = val[3], [val[1], val[0], val[2]], val[4]
    }
  | kCOLON3 tCONSTANT tOP_ASGN arg
    {
      result = val[2], [val[0], val[1]], val[3]
    }
  | backref tOP_ASGN arg { result = val[1], val[0], val[2] }
  | arg kDOT2 arg        { result = val[1], val[0], val[2] }
  | arg kDOT3 arg        { result = val[1], val[0], val[2] }
  | arg kPLUS arg        { result = val[1], val[0], val[2] }
  | arg kMINUS arg       { result = val[1], val[0], val[2] }
  | arg kMUL arg         { result = val[1], val[0], val[2] }
  | arg kDIV arg         { result = val[1], val[0], val[2] }
  | arg kPERCENT arg     { result = val[1], val[0], val[2] }
  | arg kPOW arg         { result = val[1], val[0], val[2] }
  | kUMINUS_NUM simple_numeric kPOW arg
    {
      result = val[2], [val[0], val[1]], val[3]
    }
  | kUPLUS arg           { result = val[0], val[1] }
  | kUMINUS arg          { result = val[0], val[1] }
  | arg kPIPE arg        { result = val[1], val[0], val[2] }
  | arg kXOR arg         { result = val[1], val[0], val[2] }
  | arg kBIN_AND arg     { result = val[1], val[0], val[2] }
  | arg kCMP arg         { result = val[1], val[0], val[2] }
  | arg kGREATER arg     { result = val[1], val[0], val[2] }
  | arg kGEQ arg         { result = val[1], val[0], val[2] }
  | arg kLESS arg        { result = val[1], val[0], val[2] }
  | arg kLEQ arg         { result = val[1], val[0], val[2] }
  | arg kEQ arg          { result = val[1], val[0], val[2] }
  | arg kEQQ arg         { result = val[1], val[0], val[2] }
  | arg kNEQ arg         { result = val[1], val[0], val[2] }
  | arg kMATCH arg       { result = val[1], val[0], val[2] }
  | arg kNMATCH arg      { result = val[1], val[0], val[2] }
  | kNOTOP arg           { result = val[0], val[1] }
  | kNEG arg             { result = val[0], val[1] }
  | arg kLSHIFT arg      { result = val[1], val[0], val[2] }
  | arg kRSHIFT arg      { result = val[1], val[0], val[2] }
  | arg kANDOP arg       { result = val[1], val[0], val[2] }
  | arg kOROP arg        { result = val[1], val[0], val[2] }
  | kDEFINED opt_nl { @in_defined = true } arg
    {
      @in_defined = false
      result = val[0], val[3]
    }
  | arg kQMARK arg opt_nl kCOLON arg
    {
      result = val[1], val[0], val[2], val[5]
    }
  | primary

aref_args :
    { result = [] } # nothing
  | args trailer
  | args kCOMMA assocs trailer { result = val[0] + val[2] }
  | assocs trailer

paren_args :
    kLPAREN2 opt_call_args rparen { result = val[1] }

opt_paren_args :
    { result = [] } # nothing
  | paren_args

opt_call_args :
    { result = [] } # nothing
  | call_args
  | args kCOMMA
  | args kCOMMA assocs kCOMMA { result = val[0] + val[2] }
  | assocs kCOMMA

call_args :
    command                          { result = val }
  | args opt_block_arg               { result = val[0] + [val[1]] }
  | assocs opt_block_arg             { result = val[0] + [val[1]] }
  | args kCOMMA assocs opt_block_arg { result = val[0] + val[1] + [val[2]] }
  | block_arg                        { result = val }

command_args :
    {
      push_cmdarg
      @lexer.push_cmdarg true
    }
    call_args
    {
      pop_cmdarg
      result = val[1]
    }

block_arg :
  kAMPER arg { result = val }

opt_block_arg :
    kCOMMA block_arg  { result = val[1] }
  | { result = [] } # nothing

args :
    arg                   { result = val }
  | kSTAR arg             { result = [val] }
  | args kCOMMA arg       { result = val[0] + [val[1]] }
  | args kCOMMA kSTAR arg { result = val[0] + [ [val[2], val[3]] ]  }

mrhs_arg :
    mrhs
  | arg

mrhs :
    args kCOMMA arg       { result = val[0] + [val[1]] }
  | args kCOMMA kSTAR arg { result = val[0] + [ [val[2], val[3]] ] }
  | kSTAR arg             { result = val }

primary :
    literal
  | strings
  | xstring
  | regexp
  | words
  | qwords
  | symbols
  | qsymbols
  | var_ref
  | backref
  | tFID
  | kBEGIN
    {
      push_cmdarg
      @lexer.cmdarg = 0
    }
    bodystmt kEND { pop_cmdarg; result = val[0], val[1] }
  | kLPAREN_ARG { @lexer.state = :EXPR_ENDARG } rparen { result = [] }
  | kLPAREN_ARG
    {
      push_cmdarg
      @lexer.cmdarg = 0
    }
    expr { @lexer.state = :EXPR_ENDARG } rparen
    {
      pop_cmdarg
      result = val[1]
    }
  | kLPAREN compstmt kRPAREN   { result = val[1] }
  | primary kCOLON2 tCONSTANT  { result = val[1], val[0], val[2] }
  | kCOLON3 tCONSTANT          { result = val }
  | kLBRACK aref_args kRBRACK  { result = val[0], val[1] }
  | kLBRACE assoc_list kRBRACE { result = val[0], val[1] }
  | kRETURN
  | kYIELD kLPAREN2 call_args rparen { result = val[0], val[2] }
  | kYIELD kLPAREN2 rparen           { result = val[0], [] }
  | kYIELD
  | kDEFINED opt_nl kLPAREN2 { @in_defined = true } expr { @in_defined = false } rparen { result = val[0], val[4] }
  | kNOT kLPAREN2 expr rparen { result = val[0], val[2] }
  | kNOT kLPAREN2 rparen      { result = val[0], [] }
  | fcall brace_block
    {
      puts "primary > fcall brace_block"
      result = vcall_node, [], val[0], [val[1]]
    }
  | method_call
  | method_call brace_block
    {
      result = val[0], val[1], val[2], val[3] + [val[1]]
    }
  | kLAMBDA lambda { result = [val[0]] + val[1] }
  | kIF expr then compstmt if_tail kEND { result = val[0], val[1], val[3], val[4] }
  | kUNLESS expr then compstmt opt_else kEND { result = val[0], val[1], val[3], val[4] }
  | kWHILE { @lexer.push_cond true } expr do { @lexer.pop_cond } compstmt kEND { result = val[0], val[2], val[5] }
  | kUNTIL { @lexer.push_cond true } expr do { @lexer.pop_cond } compstmt kEND { result = val[0], val[2], val[5] }
  | kCASE expr opt_terms case_body kEND { result = val[0], val[1], val[3] }
  | kCASE opt_terms case_body kEND { result = val[0], [], val[2] }
  | kFOR for_var kIN { @lexer.push_cond true } expr do { @lexer.pop_cond } compstmt kEND
  {
    result = val[0], val[1], val[4], val[7]
  }
  | kCLASS cpath superclass
    {
      raise SyntaxError, "class definition in method body" if @in_def || @in_single
    }
    bodystmt kEND
    {
      result = val[1]
      result = val[2][0], result, val[2][1] unless val[2].empty?
      result = val[0], result, val[3]
    }
  | kCLASS kLSHIFT expr
    {
      push_def
      @in_def = false
      push_single
      @in_single = false
    }
    term bodystmt kEND
    {
      pop_def
      pop_single

      result = val[0], [val[1], val[2]], val[5]
    }
  | kMODULE cpath
    {
      raise SyntaxError, "module definition in method body" if @in_def || @in_single
    }
    bodystmt kEND { result = val[0], val[1], val[2] }
  | kDEF fname
    {
      push_def
      @in_def = true
    }
    f_arglist bodystmt kEND
    {
      pop_def
      result = val[0], [], [], val[1], val[3], val[4]
    }
  | kDEF singleton dot_or_colon { @lexer.state = :EXPR_FNAME } fname
    {
      push_single
      @in_single = true
      @lexer.state = :EXPR_ENDFN
    }
    f_arglist bodystmt kEND
    {
      pop_single
      result = val[0], val[1], val[2], val[4], val[5], val[6]
    }
  | kBREAK
  | kNEXT
  | kREDO
  | kRETRY

then :
    term
  | kTHEN
  | term kTHEN

do :
    term
  | kDO_COND

if_tail :
    opt_else
  | kELSIF expr then compstmt if_tail { result = val[0], val[1], val[3], val[4] }

opt_else :
    { result = [] } # nothing
  | kELSE compstmt { result = val }

for_var :
    lhs
  | mlhs

f_marg :
    f_norm_arg
    {
      assignable("f_marg > f_norm_arg", val)
      #assignable($1, 0);
    }
  | kLPAREN f_margs rparen { result = val[1] }

f_marg_list :
    f_marg                    { result = val }
  | f_marg_list kCOMMA f_marg { result = val[0] + [val[1]] }

f_margs :
    f_marg_list
  | f_marg_list kCOMMA kSTAR f_norm_arg
    {
      #assignable($4, 0);
      assignable("f_margs > f_marg_list kCOMMA kSTAR f_norm_arg", val)
      result = val[0] + [[val[2], val[3]]]
    }
  | f_marg_list kCOMMA kSTAR f_norm_arg kCOMMA f_marg_list
    {
      #assignable($4, 0);
      assignable("f_marg_list kCOMMA kSTAR f_norm_arg kCOMMA f_marg_list", val)
      result = val[0] + [[val[2], val[3]]] + val[5]
    }
  | f_marg_list kCOMMA kSTAR { result = val[0] + [[val[2], []]] }
  | f_marg_list kCOMMA kSTAR kCOMMA f_marg_list { result = val[0] + [[val[2], []]] + val[4] }
  | kSTAR f_norm_arg
    {
      #assignable($2, 0);
      assignable("kSTAR f_norm_arg", val)
      result = [val]
    }
  | kSTAR f_norm_arg kCOMMA f_marg_list
    {
      #assignable($2, 0);
      assignable("kSTAR f_norm_arg kCOMMA f_marg_list", val)
      result = [[val[0], val[1]]] + val[3]
    }
  | kSTAR { result = [[val[0], []]] }
  | kSTAR kCOMMA f_marg_list { result = [[val[0], []]] + val[2] }

block_args_tail :
    f_block_kwarg kCOMMA f_kwrest opt_f_block_arg
    {
      result = val[0] + [val[2]] + val[3]
    }
  | f_block_kwarg opt_f_block_arg
    {
      result = val[0] + val[1]
    }
  | f_kwrest opt_f_block_arg
    {
      result = [val[0]] + val[1]
    }
  | f_block_arg { result = val }

opt_block_args_tail :
    kCOMMA block_args_tail { result = val[1] }
  | { result = [] } # nothing

block_param :
    f_arg kCOMMA f_block_optarg kCOMMA f_rest_arg opt_block_args_tail
    {
      result = val[0] + val[2] + [val[4]] + val[5]
    }
  | f_arg kCOMMA f_block_optarg kCOMMA f_rest_arg kCOMMA f_arg opt_block_args_tail
    {
      result = val[0] + val[2] + [val[4]] + val[6] + val[7]
    }
  | f_arg kCOMMA f_block_optarg opt_block_args_tail
    {
      result = val[0] + val[2] + val[3]
    }
  | f_arg kCOMMA f_block_optarg kCOMMA f_arg opt_block_args_tail
    {
      result = val[0] + val[2] + val[4] + val[5]
    }
  | f_arg kCOMMA f_rest_arg opt_block_args_tail
    {
      result = val[0] + [val[2]] + val[3]
    }
  | f_arg kCOMMA
  | f_arg kCOMMA f_rest_arg kCOMMA f_arg opt_block_args_tail
    {
      result = val[0] + [val[2]] + val[4] + val[5]
    }
  | f_arg opt_block_args_tail
    {
      result = val[0] + val[1]
    }
  | f_block_optarg kCOMMA f_rest_arg opt_block_args_tail
    {
      result = val[0] + [val[2]] + val[3]
    }
  | f_block_optarg kCOMMA f_rest_arg kCOMMA f_arg opt_block_args_tail
    {
      result = val[0] + [val[2]] + val[4] + val[5]
    }
  | f_block_optarg opt_block_args_tail
    {
      result = val[0] + val[1]
    }
  | f_block_optarg kCOMMA f_arg opt_block_args_tail
    {
      result = val[0] + val[2] + val[3]
    }
  | f_rest_arg opt_block_args_tail
    {
      result = [val[0]] + val[1]
    }
  | f_rest_arg kCOMMA f_arg opt_block_args_tail
    {
      result = [val[0]] + val[2] + val[3]
    }
  | block_args_tail

opt_block_param :
    { result = [] } # nothing
  | block_param_def { @lexer.in_cmd = true }

block_param_def :
    kPIPE opt_bv_decl kPIPE { result = val[1] }
  | kOROP { result = [] }
  | kPIPE block_param opt_bv_decl kPIPE { result = val[1] + val[2] }

opt_bv_decl :
    opt_nl
  | opt_nl kSEMICOLON bv_decls opt_nl { result = val[2] }

bv_decls :
    bvar
  | bv_decls kCOMMA bvar { result = val[0] + [val[2]] }

bvar :
    tIDENTIFIER
  | f_bad_arg

lambda :
    {
      push_lpar_beg
      @lexer.lpar_beg = @lexer.paren_nest += 1
    }
    f_larglist
    {
      push_cmdarg
      @lexer.cmdarg = 0
    }
    lambda_body
    {
      pop_lpar_beg
      pop_cmdarg
      @lexer.lexpop_cmdarg
      result = val
    }

f_larglist :
    kLPAREN2 f_args opt_bv_decl kRPAREN { result = val[1] + val[2] }
  | f_args

lambda_body :
    kLAMBEG compstmt kRBRACE { result = val[1] }
  | kDO_LAMBDA compstmt kEND { result = val[1] }

do_block :
    kDO_BLOCK opt_block_param compstmt kEND { result = val[0], val[1], val[2] }

block_call :
    command do_block
    {
      #if (nd_type($1) == NODE_YIELD)
      #    compile_error(PARSER_ARG "block given to yield");
      #block_dup_check($1->nd_args, $2);

      result = val[0][0], val[0][1], val[0][2], val[0][3] + [val[1]]
    }
  | block_call call_op2 operation2 opt_paren_args
    {
      result = val[1], val[0], val[2], val[3]
    }
  | block_call call_op2 operation2 opt_paren_args brace_block
    {
      #block_dup_check($4, $5);
      result = val[1], val[0], val[2], val[3] + [val[4]]
    }
  | block_call call_op2 operation2 command_args do_block
    {
      #block_dup_check($4, $5);
      result = val[1], val[0], val[2], val[3] + [val[4]]
    }

method_call :
    fcall paren_args                          { puts "method_call > fcall paren_args"; result = vcall_node, [], val[0], val[1] }
  | primary call_op operation2 opt_paren_args { result = val[1], val[0], val[2], val[3] }
  | primary kCOLON2 operation2 paren_args     { result = val[1], val[0], val[2], val[3] }
  | primary kCOLON2 operation3                { result = val[1], val[0], val[2], [] }
  | primary call_op paren_args                { result = val[1], val[0], [], val[2] }
  | primary kCOLON2 paren_args                { result = val[1], val[0], [], val[2] }
  | kSUPER paren_args                         { result = vcall_node, [], val[0], val[1] }
  | kSUPER                    { result = vcall_node, [], val[0] + { no_args: true }, [] }
  | primary kLBRACK2 opt_call_args rbracket   { result = vcall_node, val[0], val[1], val[2] }

brace_block :
    kLBRACE2 opt_block_param compstmt kRBRACE { result = val[0], val[1], val[2] }
  | kDO opt_block_param compstmt kEND         { result = val[0], val[1], val[2] }

case_body :
    kWHEN args then compstmt cases { result = [ [val[0], val[1], val[3]] ] + val[4] }

cases :
    opt_else
  | case_body

opt_rescue :
    kRESCUE exc_list exc_var then compstmt opt_rescue
    {
      result = [ [val[0], val[1], val[2], val[4]] ] + val[5]
    }
  | { result = [] } # nothing

exc_list :
    arg
  | mrhs
  | { result = [] } # nothing

exc_var :
    kASSOC lhs { result = val[1] }
  | { result = [] } # nothing

opt_ensure :
    kENSURE compstmt { result = val }
  | { result = [] } # nothing

literal :
    numeric
  | symbol
  | dsym

strings :
    string

string :
    tCHAR          { result = val[0], [] }
  | string1
  | string string1 { result = val[0] + [val[1]] }

string1 :
    tSTRING_BEG string_contents tSTRING_END
    {
      result = val[0]
      result += val[2].last if val[2].last.is_a?(Hash)
      result = result, val[1]
    }

xstring :
    tXSTRING_BEG xstring_contents tSTRING_END
    {
      result = val[0]
      result += val[2].last if val[2].last.is_a?(Hash)
      result = result, val[1]
    }

regexp :
    tREGEXP_BEG regexp_contents tREGEXP_END
    {
      result = val[0] + val[2].last, val[1]
    }

words :
    tWORDS_BEG kSPACE tSTRING_END    { result = val[0], [] }
  | tWORDS_BEG word_list tSTRING_END { result = val[0], val[1] }

word_list :
    { result = [] } # nothing
  | word_list word kSPACE { result = val[0] + val[1] }

word :
    string_content { result = val }
  | word string_content { result = val[0] + [val[1]] }

symbols :
    tSYMBOLS_BEG kSPACE tSTRING_END      { result = val[0], [] }
  | tSYMBOLS_BEG symbol_list tSTRING_END { result = val[0], val[1] }

symbol_list :
    { result = [] } # nothing
  | symbol_list word kSPACE { result = val[0] + val[1] }

qwords :
    tQWORDS_BEG kSPACE tSTRING_END     { result = val[0], [] }
  | tQWORDS_BEG qword_list tSTRING_END { result = val[0], val[1] }

qsymbols :
    tQSYMBOLS_BEG kSPACE tSTRING_END    { result = val[0], [] }
  | tQSYMBOLS_BEG qsym_list tSTRING_END { result = val[0], val[1] }

qword_list :
    { result = [] } # nothing
  | qword_list tSTRING_CONTENT kSPACE { result = val[0] + [val[1]] }

qsym_list :
    { result = [] } # nothing
  | qsym_list tSTRING_CONTENT kSPACE { result = val[0] + [val[1]] }

string_contents :
    { result = [] } # nothing
  | string_contents string_content { result = val[0] + [val[1]] }

xstring_contents :
    { result = [] } # nothing
  | xstring_contents string_content { result = val[0] + [val[1]] }

regexp_contents :
    { result = [] } # nothing
  | regexp_contents string_content { result = val[0] + [val[1]] }

string_content :
    tSTRING_CONTENT
  | tSTRING_DVAR string_dvar { result = val }
  | tSTRING_DBEG
    {
      push_cond
      @lexer.cond = 0
      push_cmdarg
      @lexer.cmdarg = 0
    }
    compstmt tSTRING_DEND
    {
      pop_cond
      pop_cmdarg_stack
      result = val[0], val[2]
    }

string_dvar :
    tGVAR
  | tIVAR
  | tCVAR
  | backref

symbol :
    tSYMBEG sym { result = val }

sym :
    fname
  | tIVAR
  | tGVAR
  | tCVAR

dsym :
  tSYMBEG xstring_contents tSTRING_END { result = val[0], val[1] }

numeric :
    simple_numeric
  | kUMINUS_NUM simple_numeric   =tLOWEST { result = val[0], val[1] }

simple_numeric :
    tINTEGER
  | tFLOAT
  | tRATIONAL
  | tIMAGINARY

user_variable :
    tIDENTIFIER
  | tIVAR
  | tGVAR
  | tCONSTANT
  | tCVAR

keyword_variable :
    kNIL
  | kSELF
  | kTRUE
  | kFALSE
  | k__FILE__
  | k__LINE__
  | k__ENCODING__

var_ref :
    user_variable
    {
      gettable("var_ref > user_variable", val)
      #gettable($1);
    }
  | keyword_variable
    {
      gettable("var_ref > keyword_variable", val)
      #gettable($1);
    }

var_lhs :
    user_variable
    {
      assignable("var_lhs > user_variable", val);
      #assignable($1, 0);
    }
  | keyword_variable
    {
      assignable("var_lhs > keyword_variable", val)
      #assignable($1, 0);
    }

backref :
    tNTH_REF
  | tBACK_REF

superclass :
    kLESS
    {
      @lexer.state = :EXPR_BEG
      @lexer.in_cmd = true
    }
    expr term { result = val[0], val[1] }
  | { result = [] } # nothing

f_arglist :
    kLPAREN2 f_args rparen
    {
      @lexer.state = :EXPR_BEG
      @lexer.in_cmd = true
      result = val[1]
    }
  | {
      push_kwarg
      @lexer.in_kwarg = true
    }
    f_args term
    {
      pop_kwarg
      @lexer.state = :EXPR_BEG
      @lexer.in_cmd = true
      result = val[0]
    }

args_tail :
    f_kwarg kCOMMA f_kwrest opt_f_block_arg { result = val[0] + [val[2]] + val[3] }
  | f_kwarg opt_f_block_arg                 { result = val[0] + val[1] }
  | f_kwrest opt_f_block_arg                { result = [val[0]] + val[1] }
  | f_block_arg                             { result = val }

opt_args_tail :
    kCOMMA args_tail { result = val[1] }
  | { result = [] } # nothing

f_args :
    f_arg kCOMMA f_optarg kCOMMA f_rest_arg opt_args_tail { result = val[0] + val[2] + [val[4]] + val[5] }
  | f_arg kCOMMA f_optarg kCOMMA f_rest_arg kCOMMA f_arg opt_args_tail
    {
      result = val[0] + val[2] + [val[4]] + val[6] + val[7]
    }
  | f_arg kCOMMA f_optarg opt_args_tail { result = val[0] + val[2] + val[3] }
  | f_arg kCOMMA f_optarg kCOMMA f_arg opt_args_tail { result = val[0] + val[2] + val[4] + val[5] }
  | f_arg kCOMMA f_rest_arg opt_args_tail { result = val[0] + [val[2]] + val[3] }
  | f_arg kCOMMA f_rest_arg kCOMMA f_arg opt_args_tail { result = val[0] + [val[2]] + val[4] + val[5] }
  | f_arg opt_args_tail { result = val[0] + val[1] }
  | f_optarg kCOMMA f_rest_arg opt_args_tail { result = val[0] + [val[2]] + val[3] }
  | f_optarg kCOMMA f_rest_arg kCOMMA f_arg opt_args_tail { result = val[0] + [val[2]] + val[4] + val[5] }
  | f_optarg opt_args_tail { result = val[0] + val[1] }
  | f_optarg kCOMMA f_arg opt_args_tail { result = val[0] + val[2] + val[3] }
  | f_rest_arg opt_args_tail { result = [val[0]] + val[1] }
  | f_rest_arg kCOMMA f_arg opt_args_tail { result = [val[0]] + val[2] + val[3] }
  | args_tail
  | { result = [] } # nothing

f_bad_arg :
    tCONSTANT
    {
      raise SyntaxError, "formal argument cannot be a constant"
    }
  | tIVAR
    {
      raise SyntaxError, "formal argument cannot be an instance variable"
    }
  | tGVAR
    {
      raise SyntaxError, "formal argument cannot be a global variable"
    }
  | tCVAR
    {
      raise SyntaxError, "formal argument cannot be a class variable"
    }

f_norm_arg :
    f_bad_arg
  | tIDENTIFIER
    {
      formal_argument("f_norm_arg > tIDENTIFIER", val);
      #formal_argument(get_id($1));
    }

f_arg_asgn :
    f_norm_arg

f_arg_item :
    f_arg_asgn { result = val }
  | kLPAREN f_margs rparen { result = val[1] }

f_arg :
    f_arg_item
  | f_arg kCOMMA f_arg_item { result = val[0] + val[1] }

f_label :
    tLABEL
    {
      formal_argument("f_label > tLABEL", val)
      #ID id = get_id($1);
      #arg_var(formal_argument(id));
    }

f_kw :
    f_label arg
    {
      assignable("f_kw > f_label arg", val)
      #assignable($1, $2);
      result = val
    }
  | f_label
    {
      assignable("f_kw > f_label", val)
      #assignable($1, (NODE *)-1);
      result = val[0], []
    }

f_block_kw :
    f_label primary
    {
      assignable("f_block_kw > f_label primary", val)
      #$$ = assignable($1, $2);
      result = val
    }
  | f_label
    {
      assignable("f_block_kw > f_label", val)
      #assignable($1, (NODE *)-1);
      result = val[0], []
    }

f_block_kwarg :
    f_block_kw { result = val }
  | f_block_kwarg kCOMMA f_block_kw { result = val[0] + [val[2]] }

f_kwarg :
    f_kw { result = val }
  | f_kwarg kCOMMA f_kw { result = val[0] + [val[2]] }

kwrest_mark :
    kPOW
  | kDSTAR

f_kwrest :
    kwrest_mark tIDENTIFIER { result = val }
  | kwrest_mark             { result = val[0], [] }

f_opt :
    f_arg_asgn kASSIGN arg
    {
      assignable("f_opt > f_arg_asgn kASSIGN arg", val)
      #assignable($1, $3);
      result = val[1], val[0], val[2]
    }

f_block_opt :
    f_arg_asgn kASSIGN primary
    {
      assignable("f_block_opt > f_arg_asgn kASSIGN primary", val)
      #assignable($1, $3);
      result = val[1], val[0], val[2]
    }

f_block_optarg :
    f_block_opt { result = val }
  | f_block_optarg kCOMMA f_block_opt { result = val[0] + [val[2]] }

f_optarg :
    f_opt { result = val }
  | f_optarg kCOMMA f_opt { result = val[0] + [val[2]] }

restarg_mark :
    kMUL
  | kSTAR

f_rest_arg :
    restarg_mark tIDENTIFIER
    {
      puts "f_rest_arg > restarg_mark tIDENTIFIER : #{val.inspect}"
      #if (id_type($2) != ID_LOCAL)
      #    yyerror("rest argument must be local variable");
      result = val
    }
  | restarg_mark { result = val[0], [] }

blkarg_mark :
    kBIN_AND
  | kAMPER

f_block_arg :
    blkarg_mark tIDENTIFIER
    {
      puts "f_block_arg > blkarg_mark tIDENTIFIER : #{val.inspect}"
      #if (id_type($2) != ID_LOCAL)
      #    yyerror("block argument must be local variable");
      result = val
    }

opt_f_block_arg :
    kCOMMA f_block_arg { result = val[1] }
  | { result = [] } # nothing

singleton :
    var_ref
  | kLPAREN2 expr rparen
    {
      puts "singleton > kLPAREN2 expr rparen : #{val.inspect}"
      #if ($2 == 0) {
      #  yyerror("can't define singleton method for ().");
      #switch (nd_type($2)) {
      #  case NODE_STR:
      #  case NODE_DSTR:
      #  case NODE_XSTR:
      #  case NODE_DXSTR:
      #  case NODE_DREGX:
      #  case NODE_LIT:
      #  case NODE_ARRAY:
      #  case NODE_ZARRAY:
      #    yyerror("can't define singleton method for literals");
      #}
      result = val[1]
    }

assoc_list :
    { result = [] } # nothing
  | assocs trailer { result = val[1] }

assocs :
    assoc { result = val }
  | assocs kCOMMA assoc { result = val[0] + [val[2]] }

assoc :
    arg kASSOC arg { result = val[1], val[0], val[2] }
  | tLABEL arg { result = val }
  | tSTRING_BEG string_contents tLABEL_END arg { result = [val[2], val[1], val[3]] }
  | kDSTAR arg { result = val }

operation :
    tIDENTIFIER
  | tCONSTANT
  | tFID

operation2 :
    tIDENTIFIER
  | tCONSTANT
  | tFID
  | op

operation3 :
    tIDENTIFIER
  | tFID
  | op

dot_or_colon :
    kDOT
  | kCOLON2

call_op :
    kDOT
  | kANDDOT

call_op2 :
    call_op
  | kCOLON2

opt_terms :
    { result = [] } # nothing
  | terms

opt_nl :
    { result = [] } # nothing
  | kNL

rparen :
    opt_nl kRPAREN

rbracket :
    opt_nl kRBRACK

trailer :
    { result = [] } # nothing
  | kNL
  | kCOMMA

term :
    kSEMICOLON { yyerrok; result = val }
  | kNL

terms :
    term
  | terms kSEMICOLON { yyerrok; result = val }

end
