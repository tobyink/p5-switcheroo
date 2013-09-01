BEGIN {
	package PerlX::Switch;
	
	use Exporter 'import';
	our @EXPORT = qw( switch case );
	
	use Parse::Keyword {
		switch    => \&_parse_switch,
		case      => \&_parse_case,
	};
	
	use match::simple qw( match );
	
	our $R;
	
	sub switch
	{
		my ($sigil, $expr, $block) = @_;
		
		local *_ = \(
			$sigil eq '%' ? +{ $expr->() } :
			$sigil eq '@' ? +[ $expr->() ] :
			$expr->()
		);
		
		local $R;
		$block->();
		return ${ $R || \undef };
	}
	
	sub case
	{
		my ($type, $expr, $block) = @_;
		return if $R;
		
		if ($type eq 'term' or $type eq 'simple-term')
		{
			my @terms = $expr->();
			for my $term (@terms)
			{
				next unless match($_, $term);
				$R = do { my $x = $block->(); \$x };
				return;
			}
			return;
		}
		elsif ($type eq 'block')
		{
			$R = do { my $x = $block->(); \$x } if $expr->();
			return;
		}
		
		die;
	}
	
	sub _parse_switch
	{
		my ($expr, $sigil);
		
		lex_read_space;
		die "syntax error; expected open parenthesis" unless lex_peek eq '(';
		lex_read(1);
		lex_read_space;
		
		if (lex_peek eq '@' or lex_peek eq '%')
		{
			$sigil = lex_peek;
			$expr = parse_fullexpr;
		}
		else
		{
			$expr = parse_fullexpr;
		}
		
		lex_read_space;
		die "syntax error; expected close parenthesis" unless lex_peek eq ')';
		lex_read(1);
		lex_read_space;
		die "syntax error; expected block" unless lex_peek eq '{';
		my $block = parse_block;
		
		return(
			sub { ($sigil, $expr, $block) },
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
			die "syntax error; expected colon" unless lex_peek eq ':';
			lex_read(1);
			lex_read_space;
		}
		
		my $block = $type eq 'simple-term' ? parse_fullexpr : parse_block;
		
		return(
			sub { ($type, $expr, $block) },
			$type ne 'simple-term',
		);
	}
};

use v5.14;
no thanks 'PerlX::Switch';
use PerlX::Switch;

say do {
	switch ("foo") {
		case ("bar")         { say "bar";1 }
		case { $_ eq "baz" } { say "baz";2 }
		case 99, "foo", 42:    say "foo";
	}
};

