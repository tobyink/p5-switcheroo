use strict;
use warnings;

BEGIN {
	package PerlX::Switch;
	$INC{'PerlX/Switch.pm'} = __FILE__;
	
	use Exporter 'import';
	our @EXPORT = qw( switch );
	
	use Parse::Keyword { switch => \&_parse_switch };
	
	use match::simple qw( match );
	
	sub switch
	{
		my ($expr, $cases, $default) = @_;
		
		my $var = $expr->();
		local $_ = $var;
		
		CASE: for my $case ( @$cases )
		{
			my ($type, $condition, $block) = @$case;
			
			my $matched = 0;
			if ($type eq 'block')
			{
				$matched = !!$condition->();
			}
			else
			{
				my @terms = $condition->();
				TERM: for my $term (@terms)
				{
					match($var, $term) ? (++$matched && last TERM) : next TERM;
				}
			}
			
			return $block->() if $matched;
		}
		
		return $default->() if $default;
		return;
	}
	
	sub _parse_switch
	{
		my ($expr);
		
		lex_read_space;
		
		if (lex_peek eq '(')
		{
			lex_read(1);
			lex_read_space;
			$expr = parse_fullexpr;
			lex_read_space;
			die "syntax error; expected close parenthesis" unless lex_peek eq ')';
			lex_read(1);
			lex_read_space;
		}
		else
		{
			$expr = sub { our $_ };
		}
		
		die "syntax error; expected block" unless lex_peek eq '{';
		lex_read(1);
		lex_read_space;
		
		my @cases;
		while ( lex_peek(4) eq 'case' )
		{
			lex_read(4);
			push @cases, _parse_case();
			lex_read_space;
		}
		
		my $default;
		if ( lex_peek(4) eq 'else' )
		{
			lex_read(4);
			lex_read_space;
			$default = _parse_consequence();
			lex_read_space;
		}
		
		die "syntax error; expected end of switch block" unless lex_peek eq '}';
		lex_read(1);
		
		return (
			sub { ($expr, \@cases, $default) },
			1,
		);
	}

	sub _parse_case
	{
		my ($expr, $type);
		lex_read_space;
		
		if (lex_peek eq '(')
		{
			lex_read(1);
			$type = 'term';
			$expr = parse_fullexpr;
			lex_read_space;
			die "syntax error; expected close parenthesis" unless lex_peek eq ')';
			lex_read(1);
			lex_read_space;
		}
		
		elsif (lex_peek eq '{')
		{
			$type = 'block';
			$expr = parse_block;
			lex_read_space;
		}
		
		else
		{
			$type = 'simple-term';
			$expr = parse_fullexpr;
			lex_read_space;
		}
		
		my $block = _parse_consequence();		
		return [ $type, $expr, $block ];
	}

	sub _parse_consequence
	{
		my ($expr, $type);
		lex_read_space;
		
		my $block;
		if (lex_peek eq ':')
		{
			lex_read(1);
			lex_read_space;
			$block = parse_fullexpr;
			lex_read_space;
			die "syntax error; expected semicolon" unless lex_peek eq ';' || lex_peek eq '}';
			lex_read(1) && lex_read_space while lex_peek eq ';';
		}
		else
		{
			$block = parse_block;
			lex_read_space;
			lex_read(1) && lex_read_space while lex_peek eq ';';
		}
		
		return $block;
	}
};

use v5.14;
use PerlX::Switch;

for (qw/ foo bar baz quux /)
{
	switch {
		case "foo":            say "where?";
		case ("bar")         { say "here,";  1 }
		case { $_ eq "baz" } { say "there,"; 2 }
		else                 { say "and everywhere"; 99 }
	}
}

