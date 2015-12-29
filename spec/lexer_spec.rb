require_relative '../lexer'
require_relative 'spec_helper'

RSpec.describe Mint::Lexer do
  subject { Mint::Lexer.new }

  describe 'Variables' do
    it 'parses instance variables' do
      subject.data = '@a'
      subject.to_a.should == [[:tIVAR, '@a'], [false, false]]
    end

    it 'parses class variables' do
      subject.data = '@@a1'
      subject.to_a.should == [[:tCVAR, '@@a1'], [false, false]]
    end

    it 'parses global variables' do
      subject.data = "$abc\n$1\n$`"
      subject.to_a.should == [
          [:tGVAR,     '$abc'],
          [:kNL,       "\n"],
          [:tNTH_REF,  '$1'],
          [:kNL,       "\n"],
          [:tBACK_REF, '$`'],
          [false, false]
      ]
    end
  end

  describe 'Comment' do
    it 'line comments' do
      subject.data = "@a \# a comment\n$:"
      subject.to_a.should == [
          [:tIVAR, '@a'],
          [:kNL,   "\n"],
          [:tGVAR, '$:'],
          [false, false]
      ]
    end

    it 'block comments' do
      subject.data = "@a\n=begin\n\#{blah}\n=end\n$:"
      subject.to_a.should == [
          [:tIVAR, '@a'],
          [:kNL,   "\n"],
          [:tGVAR, '$:'],
          [false, false]
      ]
    end
  end

  describe 'String' do

    it 'parses simple strings' do
      subject.data = %q|"a simple string"|
      subject.to_a.should == [
          [:tSTRING_BEG,     '"'],
          [:tSTRING_CONTENT, 'a simple string'],
          [:tSTRING_END,     '"'],
          [false, false]
      ]
    end

    it 'double quote strings have interpolation' do
      subject.data = %|"let's try \#@var \#{@interpolation}"|
      subject.to_a.should == [
          [:tSTRING_BEG,     '"'],
          [:tSTRING_CONTENT, "let's try "],
          [:tSTRING_DVAR,    '#'],
          [:tIVAR,           '@var'],
          [:tSTRING_CONTENT, ' '],
          [:tSTRING_DBEG,    '#{'],
          [:tIVAR,           '@interpolation'],
          [:tSTRING_DEND,    '}'],
          [:tSTRING_CONTENT, ''],
          [:tSTRING_END,     '"'],
          [false, false]
      ]
    end

    it "single quote strings don't have interpolation" do
      subject.data = %q|'no #@var_interpolation'|
      subject.to_a.should == [
          [:tSTRING_BEG,     "'"],
          [:tSTRING_CONTENT, 'no #@var_interpolation'],
          [:tSTRING_END,     "'"],
          [false, false]
      ]
    end

    it 'parses regular expressions' do
      subject.data = '/abc/'
      subject.to_a.should == [
          [:tREGEXP_BEG,     '/'],
          [:tSTRING_CONTENT, 'abc'],
          [:tREGEXP_END, '/'],
          [false, false]
      ]
    end

    it 'parses simple %strings' do
      subject.data = "%= \t="
      subject.to_a.should == [
          [:tSTRING_BEG,     '%='],
          [:tSTRING_CONTENT, " \t"],
          [:tSTRING_END,     '='],
          [false, false]
      ]
    end

    it 'parses %strings with text' do
    subject.data = "%q< hello world\t>"
    subject.to_a.should == [
        [:tSTRING_BEG,     '%q<'],
        [:tSTRING_CONTENT, " hello world\t"],
        [:tSTRING_END,     '>'],
        [false, false]
    ]
    end

    it 'parses %regexp' do
      subject.data = '%r(this regexp)'
      subject.to_a.should == [
          [:tSTRING_BEG,     '%r('],
          [:tSTRING_CONTENT, 'this regexp'],
          [:tSTRING_END,     ')'],
          [false, false]
      ]
    end
  end

  describe 'Heredocs' do

    it 'parses empty heredocs' do
      subject.data = "<<AAA\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA'],
          [:tSTRING_CONTENT, ''],
          [:tSTRING_END,     'AAA'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'parses heredocs with single new line' do
      subject.data = "<<AAA\n\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA'],
          [:tSTRING_CONTENT, "\n"],
          [:tSTRING_END,     'AAA'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'parses simple heredocs' do
      subject.data = "<<AAA\nhello world\nAAA"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<AAA'],
          [:tSTRING_CONTENT, "hello world\n"],
          [:tSTRING_END,     'AAA'],
          [:kNL,             "\n"],
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
          [:tSTRING_BEG,     '<<-AAA'],
          [:tSTRING_CONTENT, ''],
          [:tSTRING_END,     ' AAA'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'has the right heredoc content' do
      subject.data = "<<XX, <<YY\nxxx\nXX\nyyy\nYY"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX'],
          [:tSTRING_CONTENT, "xxx\n"],
          [:tSTRING_END,     "XX\n"],
          [:kCOMMA,          ','],
          [:tSTRING_BEG,     '<<YY'],
          [:tSTRING_CONTENT, "yyy\n"],
          [:tSTRING_END,     'YY'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'parses embedded heredocs' do
      subject.data = "<<XX\nxxx\n\#{ <<YY }zzz\nyyy\nYY\nwww\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX'],
          [:tSTRING_CONTENT, "xxx\n"],
          [:tSTRING_DBEG,    '#{'],
          [:tSTRING_BEG,     '<<YY'],
          [:tSTRING_CONTENT, "yyy\n"],
          [:tSTRING_END,     "YY\n"],
          [:tSTRING_DEND,    '}'],
          [:tSTRING_CONTENT, "zzz\nwww\n"],
          [:tSTRING_END,     'XX'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'parses multiple embedded heredocs' do
      subject.data = "<<XX\nxxx \#{ <<YY } www\ny \#{ <<ZZ + 'iii' } y\nzzz\nZZ\nYY\naaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<XX'],
          [:tSTRING_CONTENT, 'xxx '],
          [:tSTRING_DBEG,    '#{'],
          [:tSTRING_BEG,     '<<YY'],
          [:tSTRING_CONTENT, 'y '],
          [:tSTRING_DBEG,    '#{'],
          [:tSTRING_BEG,     '<<ZZ'],
          [:tSTRING_CONTENT, "zzz\n"],
          [:tSTRING_END,     "ZZ\n"],
          [:kPLUS,           '+'],
          [:tSTRING_BEG,     "'"],
          [:tSTRING_CONTENT, 'iii'],
          [:tSTRING_END,     "'"],
          [:tSTRING_DEND,    '}'],
          [:tSTRING_CONTENT, " y\n"],
          [:tSTRING_END,     "YY\n"],
          [:tSTRING_DEND,    '}'],
          [:tSTRING_CONTENT, " www\naaa\n"],
          [:tSTRING_END,     'XX'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'has dedent = 2' do
      subject.data = "<<~XX\n  aaa\n   aaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX'],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n"],
          [:tSTRING_END,     'XX', dedent: 2],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'has dedent = 2 again' do
      subject.data = "<<~XX\n  aaa\n   aaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX'],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n"],
          [:tSTRING_END,     'XX', dedent: 2],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'has interpolation which interferes with dedent' do
      # even if @a = '  aaa', dedent will be 1
      subject.data = "<<~XX\n  aaa\n   aaa\n \#@a\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<~XX'],
          [:tSTRING_CONTENT, "  aaa\n   aaa\n "],
          [:tSTRING_DVAR,    '#'],
          [:tIVAR,           '@a'],
          [:tSTRING_CONTENT, "\n"],
          [:tSTRING_END,     'XX', dedent: 1],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it "accepts ' as heredoc identifier" do
      subject.data = "<<'XX'\naaa\nXX"
      subject.to_a.should == [
          [:tSTRING_BEG,     "<<'XX'"],
          [:tSTRING_CONTENT, "aaa\n"],
          [:tSTRING_END,     'XX'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'accepts " as heredoc identifier' do
      subject.data = %'<<"XX"\naaa\nXX'
      subject.to_a.should == [
          [:tSTRING_BEG,     '<<"XX"'],
          [:tSTRING_CONTENT, "aaa\n"],
          [:tSTRING_END,     'XX'],
          [:kNL,             "\n"],
          [false, false]
      ]
    end

    it 'accepts ` as heredoc identifier' do
      subject.data = "<<`XX`\naaa\nXX"
      subject.to_a.should == [
          [:tXSTRING_BEG,    '<<`XX`'],
          [:tSTRING_CONTENT, "aaa\n"],
          [:tSTRING_END,     'XX'],
          [:kNL,             "\n"],
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
          [:tIDENTIFIER, 'a'],
          [:tOP_ASGN,    :kPLUS],
          [:tINTEGER,    '1', num_base: 10],
          [false, false]
      ]
    end

    it 'foo -= 1.0' do
      subject.data = 'foo -= 1.0'
      subject.to_a.should == [
          [:tIDENTIFIER, 'foo'],
          [:tOP_ASGN,    :kMINUS],
          [:tFLOAT,      '1.0', num_base: 10],
          [false, false]
      ]
    end

    it 'x.bar *= 0b100_000' do
      subject.data = 'x.bar *= 0b100_000'
      subject.to_a.should == [
          [:tIDENTIFIER, 'x'],
          [:kDOT,        '.'],
          [:tIDENTIFIER, 'bar'],
          [:tOP_ASGN,    :kSTAR],
          [:tINTEGER,    '0b100_000', num_base: 2],
          [false, false]
      ]
    end
  end

  describe 'Dot and Anddot' do
    it 'dot without \\n' do
      subject.data = "a.\n\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kDOT,        '.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

    it 'anddot without \\n' do
      subject.data = "a&.\n\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kANDDOT,     '&.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

    it 'dot with a single \\n' do
      subject.data = "a\n.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kDOT,        '.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

    it 'anddot with a single \\n' do
      subject.data = "a\n&.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kANDDOT,     '&.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

    it 'dot with multiple \\n' do
      subject.data = "a\n\n.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kNL,         "\n"],
          [:kDOT,        '.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

    it 'anddot with multiple \\n' do
      subject.data = "a\n\n&.\n\nb"
      subject.to_a.should == [
          [:tIDENTIFIER, 'a'],
          [:kNL,         "\n"],
          [:kANDDOT,     '&.'],
          [:tIDENTIFIER, 'b'],
          [false, false]
      ]
    end

  end

  it 'parses methods' do
    subject.data = 'def a; :a end'
    subject.to_a.should == [
        [:kDEF,        'def'],
        [:tIDENTIFIER, 'a'],
        [:kSEMICOLON,  ';'],
        [:tSYMBEG,     ':'],
        [:tIDENTIFIER, 'a'],
        [:kEND,        'end'],
        [false, false]
    ]
  end

  it 'parses classes' do
    subject.data = "class X\ndef f; :f end\nend"
    subject.to_a.should == [
        [:kCLASS,      'class'],
        [:tCONSTANT,   'X'],
        [:kNL,         "\n"],
        [:kDEF,        'def'],
        [:tIDENTIFIER, 'f'],
        [:kSEMICOLON,  ';'],
        [:tSYMBEG,     ':'],
        [:tIDENTIFIER, 'f'],
        [:kEND,        'end'],
        [:kNL,         "\n"],
        [:kEND,        'end'],
        [false, false]
    ]
  end
end