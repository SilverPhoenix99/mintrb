require_relative '../lexer'
require_relative 'spec_helper'

RSpec.describe Mint::Lexer do
  subject { Mint::Lexer.new }

  describe 'Variables' do
    it 'parses instance variables' do
      subject.data = '@a'
      subject.to_a.should == [[:tIVAR, '@a', [1, 1]], [false, false]]
    end

    it 'parses class variables' do
      subject.data = '@@a1'
      subject.to_a.should == [[:tCVAR, '@@a1', [1, 1]], [false, false]]
    end

    it 'parses global variables' do
      subject.data = "$abc\n$1\n$`"
      subject.to_a.should == [
          [:tGVAR,     '$abc', [1, 1]],
          [:kNL,       "\n",   [1, 5]],
          [:tNTH_REF,  '$1',   [2, 1]],
          [:kNL,       "\n",   [2, 3]],
          [:tBACK_REF, '$`',   [3, 1]],
          [false, false]
      ]
    end
  end

  describe 'Comment' do
    it 'line comments' do
      subject.data = "@a \# a comment\n$:"
      subject.to_a.should == [
          [:tIVAR, '@a', [1,  1]],
          [:kNL,   "\n", [1, 15]],
          [:tGVAR, '$:', [2,  1]],
          [false, false]
      ]
    end

    it 'block comments' do
      subject.data = "@a\n=begin\n\#{blah}\n=end\n$:"
      subject.to_a.should == [
          [:tIVAR, '@a', [1, 1]],
          [:kNL,   "\n", [1, 3]],
          [:tGVAR, '$:', [5, 1]],
          [false, false]
      ]
    end
  end

  describe 'String' do

    it 'parses simple strings' do
      subject.data = %q|"a simple string"|
      subject.to_a.should == [
          [:tSTRING_BEG,     '"',               [1,  1]],
          [:tSTRING_CONTENT, 'a simple string', [1,  2]],
          [:tSTRING_END,     '"',               [1, 17]],
          [false, false]
      ]
    end

    it 'double quote strings have interpolation' do
      subject.data = %|"let's try \#@var \#{@interpolation}"|
      subject.to_a.should == [
          [:tSTRING_BEG,     '"',              [1,  1]],
          [:tSTRING_CONTENT, "let's try ",     [1,  2]],
          [:tSTRING_DVAR,    '#',              [1, 12]],
          [:tIVAR,           '@var',           [1, 13]],
          [:tSTRING_CONTENT, ' ',              [1, 17]],
          [:tSTRING_DBEG,    '#{',             [1, 18]],
          [:tIVAR,           '@interpolation', [1, 20]],
          [:tSTRING_DEND,    '}',              [1, 34]],
          [:tSTRING_CONTENT, '',               [1, 35]],
          [:tSTRING_END,     '"',              [1, 35]],
          [false, false]
      ]
    end

    it "single quote strings don't have interpolation" do
      subject.data = %q|'no #@var_interpolation'|
      subject.to_a.should == [
          [:tSTRING_BEG,     "'",                      [1,  1]],
          [:tSTRING_CONTENT, 'no #@var_interpolation', [1,  2]],
          [:tSTRING_END,     "'",                      [1, 24]],
          [false, false]
      ]
    end

    it 'parses regular expressions' do
      subject.data = '/abc/'
      subject.to_a.should == [
          [:tREGEXP_BEG,     '/',   [1, 1]],
          [:tSTRING_CONTENT, 'abc', [1, 2]],
          [:tREGEXP_END,     '/',   [1, 5]],
          [false, false]
      ]
    end

    it 'parses simple %strings' do
      subject.data = "%= \t="
      subject.to_a.should == [
          [:tSTRING_BEG,     '%=',  [1, 1]],
          [:tSTRING_CONTENT, " \t", [1, 3]],
          [:tSTRING_END,     '=',   [1, 5]],
          [false, false]
      ]
    end

    it 'parses %strings with text' do
    subject.data = "%q< hello world\t>"
    subject.to_a.should == [
        [:tSTRING_BEG,     '%q<',            [1,  1]],
        [:tSTRING_CONTENT, " hello world\t", [1,  4]],
        [:tSTRING_END,     '>',              [1, 17]],
        [false, false]
    ]
    end

    it 'parses %regexp' do
      subject.data = '%r(this regexp)'
      subject.to_a.should == [
          [:tREGEXP_BEG,     '%r(',         [1,  1]],
          [:tSTRING_CONTENT, 'this regexp', [1,  4]],
          [:tSTRING_END,     ')',           [1, 15]],
          [false, false]
      ]
    end
  end

  describe 'Words' do
    it 'splits words' do
      subject.data = '%w{a b}'
      subject.to_a.should == [
          [:tQWORDS_BEG,     '%w{', [1, 1]],
          [:tSTRING_CONTENT, 'a',   [1, 4]],
          [:tSPACE,          ' ',   [1, 5]],
          [:tSTRING_CONTENT, 'b',   [1, 6]],
          [:tSTRING_END,     '}',   [1, 7]],
          [false, false]
      ]
    end

    it 'splits words with interpolation' do
      subject.data = %|%W{a\n  b  foo\#{ @c }bar  }|
      subject.to_a.should == [
          [:tWORDS_BEG,      '%W{',  [1,  1]],
          [:tSTRING_CONTENT, 'a',    [1,  4]],
          [:tSPACE,          "\n  ", [1,  5]],
          [:tSTRING_CONTENT, 'b',    [2,  3]],
          [:tSPACE,          '  ',   [2,  4]],
          [:tSTRING_CONTENT, 'foo',  [2,  6]],
          [:tSTRING_DBEG,    '#{',   [2,  9]],
          [:tIVAR,           '@c',   [2, 12]],
          [:tSTRING_DEND,    '}',    [2, 15]],
          [:tSTRING_CONTENT, 'bar',  [2, 16]],
          [:tSPACE,          '  ',   [2, 19]],
          [:tSTRING_END,     '}',    [2, 21]],
          [false, false]
      ]
    end

    it 'empty words' do
      subject.data = '%w{}'
      subject.to_a.should == [
          [:tQWORDS_BEG,     '%w{', [1, 1]],
          [:tSTRING_END,     '}',   [1, 4]],
          [false, false]
      ]
    end

    it 'empty words with spaces' do
      subject.data = "%w{ \t\n}"
      subject.to_a.should == [
          [:tQWORDS_BEG,     '%w{', [1, 1]],
          [:tSTRING_END,     '}',   [2, 1]],
          [false, false]
      ]
    end
  end

  describe 'Heredocs' do

    it 'parses empty heredocs' do
      subject.data = "<<AAA\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA', [1, 1]],
          [:tSTRING_CONTENT, '',      [2, 1]],
          [:tSTRING_END,     'AAA',   [2, 1]],
          [:kNL,             "\n",    [1, 6]],
          [false, false]
      ]
    end

    it 'parses heredocs with single new line' do
      subject.data = "<<AAA\n\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA', [1, 1]],
          [:tSTRING_CONTENT, "\n",    [2, 1]],
          [:tSTRING_END,     'AAA',   [3, 1]],
          [:kNL,             "\n",    [1, 6]],
          [false, false]
      ]
    end

    it 'parses simple heredocs' do
      subject.data = "<<AAA\nhello world\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA',         [1, 1]],
          [:tSTRING_CONTENT, "hello world\n", [2, 1]],
          [:tSTRING_END,     'AAA',           [3, 1]],
          [:kNL,             "\n",            [1, 6]],
          [false, false]
      ]
    end

    it "doesn't find end of heredoc" do
      expect do
        subject.data = "<<AAA\n AAA"
        subject.to_a
      end.to raise_error SyntaxError, %q(can't find string "AAA" anywhere before EOF)
    end

    it 'finds the end of heredoc' do
      subject.data = "<<-AAA\n AAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<-AAA', [1, 1]],
          [:tSTRING_CONTENT, '',       [2, 1]],
          [:tSTRING_END,     ' AAA',   [2, 1]],
          [:kNL,             "\n",     [1, 7]],
          [false, false]
      ]
    end

    it 'has the right heredoc content' do
      subject.data = "<<XX, <<YY\nxxx\nXX\nyyy\nYY"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX',  [1,  1]],
          [:tSTRING_CONTENT, "xxx\n", [2,  1]],
          [:tSTRING_END,     "XX\n",  [3,  1]],
          [:kCOMMA,          ',',     [1,  5]],
          [:tSTRING_BEG,     '<<YY',  [1,  7]],
          [:tSTRING_CONTENT, "yyy\n", [4,  1]],
          [:tSTRING_END,     'YY',    [5,  1]],
          [:kNL,             "\n",    [1, 11]],
          [false, false]
      ]
    end

    it 'parses embedded heredocs' do
      subject.data = "<<XX\nxxx\n\#{ <<YY }zzz\nyyy\nYY\nwww\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX',       [1,  1]],
          [:tSTRING_CONTENT, "xxx\n",      [2,  1]],
          [:tSTRING_DBEG,    '#{',         [3,  1]],
          [:tSTRING_BEG,     '<<YY',       [3,  4]],
          [:tSTRING_CONTENT, "yyy\n",      [4,  1]],
          [:tSTRING_END,     "YY\n",       [5,  1]],
          [:tSTRING_DEND,    '}',          [3,  9]],
          [:tSTRING_CONTENT, "zzz\nwww\n", [3, 10]],
          [:tSTRING_END,     'XX',         [7,  1]],
          [:kNL,             "\n",         [1,  5]],
          [false, false]
      ]
    end

    it 'parses multiple embedded heredocs' do
      subject.data = "<<XX\nxxx \#{ <<YY } www\ny \#{ <<ZZ + 'iii' } y\nzzz\nZZ\nYY\naaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX',        [1,  1]],
          [:tSTRING_CONTENT, 'xxx ',        [2,  1]],
          [:tSTRING_DBEG,    '#{',          [2,  5]],
          [:tSTRING_BEG,     '<<YY',        [2,  8]],
          [:tSTRING_CONTENT, 'y ',          [3,  1]],
          [:tSTRING_DBEG,    '#{',          [3,  3]],
          [:tSTRING_BEG,     '<<ZZ',        [3,  6]],
          [:tSTRING_CONTENT, "zzz\n",       [4,  1]],
          [:tSTRING_END,     "ZZ\n",        [5,  1]],
          [:kPLUS,           '+',           [3, 11]],
          [:tSTRING_BEG,     "'",           [3, 13]],
          [:tSTRING_CONTENT, 'iii',         [3, 14]],
          [:tSTRING_END,     "'",           [3, 17]],
          [:tSTRING_DEND,    '}',           [3, 19]],
          [:tSTRING_CONTENT, " y\n",        [3, 20]],
          [:tSTRING_END,     "YY\n",        [6,  1]],
          [:tSTRING_DEND,    '}',           [2, 13]],
          [:tSTRING_CONTENT, " www\naaa\n", [2, 14]],
          [:tSTRING_END,     'XX',          [8,  1]],
          [:kNL,             "\n",          [1,  5]],
          [false, false]
      ]
    end

    it 'has dedent = 2' do
      subject.data = "<<~XX\n  aaa\n   aaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX',           [1, 1]],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n", [2, 1]],
          [:tSTRING_END,     'XX',              [4, 1], dedent: 2],
          [:kNL,             "\n",              [1, 6]],
          [false, false]
      ]
    end

    it 'has dedent = 2 again' do
      subject.data = "<<~XX\n  aaa\n   aaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX',           [1, 1]],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n", [2, 1]],
          [:tSTRING_END,     'XX',              [4, 1], dedent: 2],
          [:kNL,             "\n",              [1, 6]],
          [false, false]
      ]
    end

    it 'has interpolation which interferes with dedent' do
      # even if @a = '  aaa', dedent will be 1
      subject.data = "<<~XX\n  aaa\n   aaa\n \#@a\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX',            [1, 1]],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n ", [2, 1]],
          [:tSTRING_DVAR,    '#',                [4, 2]],
          [:tIVAR,           '@a',               [4, 3]],
          [:tSTRING_CONTENT, "\n",               [4, 5]],
          [:tSTRING_END,     'XX',               [5, 1], dedent: 1],
          [:kNL,             "\n",               [1, 6]],
          [false, false]
      ]
    end

    it "accepts ' as heredoc identifier" do
      subject.data = "<<'XX'\naaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     "<<'XX'", [1, 1]],
          [:tSTRING_CONTENT, "aaa\n",  [2, 1]],
          [:tSTRING_END,     'XX',     [3, 1]],
          [:kNL,             "\n",     [1, 7]],
          [false, false]
      ]
    end

    it 'accepts " as heredoc identifier' do
      subject.data = %'<<"XX"\naaa\nXX'
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<"XX"', [1, 1]],
          [:tSTRING_CONTENT, "aaa\n",  [2, 1]],
          [:tSTRING_END,     'XX',     [3, 1]],
          [:kNL,             "\n",     [1, 7]],
          [false, false]
      ]
    end

    it 'accepts ` as heredoc identifier' do
      subject.data = "<<`XX`\naaa\nXX"
      subject.to_a.should == [
          [:tXSTRING_BEG,    '<<`XX`', [1, 1]],
          [:tSTRING_CONTENT, "aaa\n",  [2, 1]],
          [:tSTRING_END,     'XX',     [3, 1]],
          [:kNL,             "\n",     [1, 7]],
          [false, false]
      ]
    end

  end

  describe 'Numeric' do

    it 'throws trailing underscore error in integers' do
      expect do
        subject.data = '11_'
        subject.to_a
      end.to raise_error SyntaxError, "trailing `_' in number"
    end

    it 'throws trailing underscore error in integer part of a float' do
      expect do
        subject.data = '1_.11'
        subject.to_a
      end.to raise_error SyntaxError, "trailing `_' in number"
    end

    it 'throws trailing underscore error in fractional part of a float' do
      expect do
        subject.data = '1.11_'
        subject.to_a
      end.to raise_error SyntaxError, "trailing `_' in number"
    end

    it 'throws trailing underscore error in exponential part of a float' do
      expect do
        subject.data = '1.11e1_'
        subject.to_a
      end.to raise_error SyntaxError, "trailing `_' in number"
    end

  end

  describe 'Operator assign' do
    it 'a += 1' do
      subject.data = 'a += 1'
      subject.to_a.should == [
          [:tIDENTIFIER, 'a',    [1, 1]],
          [:tOP_ASGN,    :kPLUS, [1, 3]],
          [:tINTEGER,    '1',    [1, 6], num_base: 10],
          [false, false]
      ]
    end

    it 'foo -= 1.0' do
      subject.data = 'foo -= 1.0'
      subject.to_a.should == [
          [:tIDENTIFIER, 'foo',   [1, 1]],
          [:tOP_ASGN,    :kMINUS, [1, 5]],
          [:tFLOAT,      '1.0',   [1, 8], num_base: 10],
          [false, false]
      ]
    end

    it 'x.bar *= 0b100_000' do
      subject.data = 'x.bar *= 0b100_000'
      subject.to_a.should == [
          [:tIDENTIFIER, 'x',         [1,  1]],
          [:kDOT,        '.',         [1,  2]],
          [:tIDENTIFIER, 'bar',       [1,  3]],
          [:tOP_ASGN,    :kSTAR,      [1,  7]],
          [:tINTEGER,    '0b100_000', [1, 10], num_base: 2],
          [false, false]
      ]
    end
  end

  describe 'Dot and Anddot' do
    it 'dot without \\n' do
      subject.data = "a.\n\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a', [1, 1]],
          [:kDOT,        '.', [1, 2]],
          [:tIDENTIFIER, 'b', [4, 1]],
          [false, false]
      ]
    end

    it 'anddot without \\n' do
      subject.data = "a&.\n\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a',  [1, 1]],
          [:kANDDOT,     '&.', [1, 2]],
          [:tIDENTIFIER, 'b',  [4, 1]],
          [false, false]
      ]
    end

    it 'dot with a single \\n' do
      subject.data = "a\n.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a', [1, 1]],
          [:kDOT,        '.', [2, 1]],
          [:tIDENTIFIER, 'b', [4, 1]],
          [false, false]
      ]
    end

    it 'anddot with a single \\n' do
      subject.data = "a\n&.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a',  [1, 1]],
          [:kANDDOT,     '&.', [2, 1]],
          [:tIDENTIFIER, 'b',  [4, 1]],
          [false, false]
      ]
    end

    it 'dot with multiple \\n' do
      subject.data = "a\n\n.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a',  [1, 1]],
          [:kNL,         "\n", [1, 2]],
          [:kDOT,        '.',  [3, 1]],
          [:tIDENTIFIER, 'b',  [5, 1]],
          [false, false]
      ]
    end

    it 'anddot with multiple \\n' do
      subject.data = "a\n\n&.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a',  [1, 1]],
          [:kNL,         "\n", [1, 2]],
          [:kANDDOT,     '&.', [3, 1]],
          [:tIDENTIFIER, 'b',  [5, 1]],
          [false, false]
      ]
    end

  end

  it 'parses methods' do
    subject.data = 'def a; :a end'
    subject.to_a.should == [
        [:kDEF,        'def', [1,  1]],
        [:tIDENTIFIER, 'a',   [1,  5]],
        [:kSEMICOLON,  ';',   [1,  6]],
        [:tSYMBEG,     ':',   [1,  8]],
        [:tIDENTIFIER, 'a',   [1,  9]],
        [:kEND,        'end', [1, 11]],
        [false, false]
    ]
  end

  it 'parses classes' do
    subject.data = "class X\ndef f; :f end\nend"
    subject.to_a.should == [
        [:kCLASS,      'class', [1,   1]],
        [:tCONSTANT,   'X',     [1,   7]],
        [:kNL,         "\n",    [1,   8]],
        [:kDEF,        'def',   [2,   1]],
        [:tIDENTIFIER, 'f',     [2,   5]],
        [:kSEMICOLON,  ';',     [2,   6]],
        [:tSYMBEG,     ':',     [2,   8]],
        [:tIDENTIFIER, 'f',     [2,   9]],
        [:kEND,        'end',   [2,  11]],
        [:kNL,         "\n",    [2,  14]],
        [:kEND,        'end',   [3,   1]],
        [false, false]
    ]
  end
end