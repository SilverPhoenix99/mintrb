require_relative '../lexer'
require_relative 'spec_helper'

RSpec.describe Mint::Lexer do
  subject { Mint::Lexer.new('') }

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
        [:tNTH_REF,  '$1'],
        [:tBACK_REF, '$`'],
        [false, false]
    ]
  end

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

  it 'parses empty heredocs' do
    subject.data = "<<AAA\nAAA"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<AAA'],
        [:tSTRING_CONTENT, ''],
        [:tSTRING_END,     'AAA'],
        [false, false]
    ]
  end

  it 'parses simple heredocs' do
    subject.data = "<<AAA\n\nAAA"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<AAA'],
        [:tSTRING_CONTENT, "\n"],
        [:tSTRING_END,     'AAA'],
        [false, false]
    ]

    subject.data = "<<AAA\nhello world\nAAA"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<AAA'],
        [:tSTRING_CONTENT, "hello world\n"],
        [:tSTRING_END,     'AAA'],
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
        [false, false]
    ]
  end

  it 'has the right content' do
    subject.data = "<<XX <<YY\nxxx\nXX\nyyy\nYY"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<XX'],
        [:tSTRING_CONTENT, "xxx\n"],
        [:tSTRING_END,     "XX\n"],
        [:tSTRING_BEG,     '<<YY'],
        [:tSTRING_CONTENT, "yyy\n"],
        [:tSTRING_END,     'YY'],
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
        [false, false]
    ]
  end

  it 'has dedent = 2' do
    subject.data = "<<~XX\n  aaa\n   aaa\nXX"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<~XX'],
        [:tSTRING_CONTENT, "  aaa\n   aaa\n"],
        [:tSTRING_END,     'XX', dedent: 2],
        [false, false]
    ]
  end

  it 'has dedent = 2 again' do
    subject.data = "<<~XX\n  aaa\n   aaa\nXX"
    subject.to_a.should == [
        [:tSTRING_BEG,     '<<~XX'],
        [:tSTRING_CONTENT, "  aaa\n   aaa\n"],
        [:tSTRING_END,     'XX', dedent: 2],
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
        [false, false]
    ]
  end
end