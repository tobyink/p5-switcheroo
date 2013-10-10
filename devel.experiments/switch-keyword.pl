use strict;
use warnings;

BEGIN {
	package Switcheroo;
	$INC{'Switcheroo.pm'} = __FILE__;
	
	use Exporter 'import';
	our @EXPORT    = qw( switch );
	our @EXPORT_OK = qw( match );
	
	use Parse::Keyword { switch => \&_parse_switch };
	use Devel::LexAlias qw( lexalias );
	use PadWalker qw( peek_my );
	use match::simple qw( match );
	
	sub switch
	{
		my ($pkg, $expr, $comparator, $cases, $default) = @_;
		
		my $pad = peek_my(1);
		my $var = defined($expr)
			? do {
				lexalias($expr, $_, $pad->{$_}) for keys %$pad;
				$expr->();
			}
			: $_;
		Internals::SvREADONLY($var, 1);
		local *_ = \$var;
		
		my $match = \&match::simple::match;
		if ($comparator)
		{
			$match = sub {
				no strict 'refs';
				local *{"$pkg\::a"} = \ $_[0];
				local *{"$pkg\::b"} = \ $_[1];
				$comparator->(@_);
			};
		}
		
		CASE: for my $case ( @$cases )
		{
			my ($type, $condition, $block) = @$case;
			lexalias($condition, $_, $pad->{$_}) for keys %$pad;
			
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
					$match->($var, $term) ? (++$matched && last TERM) : next TERM;
				}
			}
			
			lexalias($block, $_, $pad->{$_}) for keys %$pad;
			return $block->() if $matched;
		}
		
		if ($default)
		{
			lexalias($default, $_, $pad->{$_}) for keys %$pad;
			return $default->();
		}
		return;
	}
	
	sub _parse_switch
	{
		my ($expr, $comparator, @cases, $default);
		my $is_statement = 1;
		
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

		if (lex_peek(2) eq 'on')
		{
			lex_read(2);
			lex_read_space;
			$comparator = parse_block;
			lex_read_space;
		}

		if (lex_peek(2) eq 'do')
		{
			lex_read(2);
			lex_read_space;
			$is_statement = 0;
		}

		die "syntax error; expected block" unless lex_peek eq '{';
		lex_read(1);
		lex_read_space;
		
		while ( lex_peek(4) eq 'case' )
		{
			lex_read(4);
			push @cases, _parse_case();
			lex_read_space;
		}
		
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
			sub { (scalar(compiling_package), $expr, $comparator, \@cases, $default) },
			$is_statement,
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
			if (lex_peek(1) eq '/')
			{
				lex_stuff('qr');
			}
			elsif (lex_peek(2) =~ /m\W/)
			{
				lex_read(1);
				lex_stuff('qr');
			}
			
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
use Switcheroo;
no warnings 'once';

sub xyz
{
	$_ = shift;
	switch {
		case m(foo):          say "where?";
		case ("bar")         { say "here";  1 }
		case { $_ eq "baz" } { say "there"; 2 }
		else          :        say($_)+99;
	}
	1;
}

xyz("foo");
xyz("bar");
xyz("baz");
xyz("everywhere");
