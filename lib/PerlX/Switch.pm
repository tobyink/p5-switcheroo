use 5.014;
use strict;
use warnings;

package PerlX::Switch;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';
our @EXPORT    = qw( switch );
our @EXPORT_OK = qw( match );

use Devel::LexAlias qw( lexalias );
use Exporter qw( import );
use match::simple qw( match );
use PadWalker qw( peek_my );
use Parse::Keyword { switch => \&_parse_switch };

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
	
	if (lex_peek(2) eq 'if')
	{
		lex_read(2);
		lex_read_space;
		die "syntax error; expected open parenthesis" unless lex_peek eq '(';
		lex_read(1);
		lex_read_space;
		$comparator = parse_fullexpr;
		lex_read_space;
		die "syntax error; expected close parenthesis" unless lex_peek eq ')';
		lex_read(1);
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
	
	if ( lex_peek(7) eq 'default' )
	{
		lex_read(7);
		lex_read_space;
		if (lex_peek eq ':')
		{
			lex_read(1);
			lex_read_space;
		}
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
#		if (lex_peek(1) eq '/')
#		{
#			lex_stuff('qr');
#		}
#		elsif (lex_peek(2) =~ /m\W/)
#		{
#			lex_read(1);
#			lex_stuff('qr');
#		}
#		
		$type = 'simple-term';
		$expr = parse_fullexpr;
		lex_read_space;
	}
	
	die "syntax error; expected colon" unless lex_peek eq ':';
	lex_read(1);
	lex_read_space;
	
	my $block = _parse_consequence();
	return [ $type, $expr, $block ];
}

sub _parse_consequence
{
	my ($expr, $type);
	lex_read_space;
	
	my $block = (lex_peek eq '{') ? parse_block() : parse_fullstmt();
	lex_read_space;
	(lex_read(1), lex_read_space) while lex_peek eq ';';
	
	return $block;
}


1;

__END__

=pod

=encoding utf-8

=for stopwords fallthrough non-whitespace

=head1 NAME

PerlX::Switch - yet another switch statement for Perl

=head1 SYNOPSIS

   my $day_type;
   
   switch ($day) {
      case 0, 6:  $day_type = "weekend";
      default:    $day_type = "weekday";
   }

=head1 DESCRIPTION

This module provides Perl with a switch statement. It's more reliable than
the L<Switch> module (which is broken on recent versions of Perl anyway),
less confusing than C<< use feature 'switch' >>, and more powerful than
L<Switch::Plain> (though Switch::Plain is significantly faster).

The basic grammar of the switch statement is as follows:

   switch ( TEST ) {
      case EXPR1: STATEMENT1;
      case EXPR2: STATEMENT2;
      default:    STATEMENT3;
   }

TEST is evaluated in scalar context. Each expression EXPR1, EXPR2, etc
is evaluated in list context. If TEST matches any of the expression,
then the statement following it is executed. Matching is performed by
L<match::simple>, which is a simplified version of the Perl smart match
operator. If no match is successful, then the C<default> statement is
executed.

C<switch> is whole statement, so does not need to be followed by a
semicolon.

Within the switch block, C<< $_ >> is a read-only alias to the TEST
value.

That's the basics taken care of, but there are several variations...

=head2 Implicit test

If the test is omitted, then C<< $_ >> is tested:

   my $day_type;
   
   $_ = $day;
   switch {
      case 0, 6:  $day_type = "weekend";
      default:    $day_type = "weekday";
   }

=head2 Expression blocks

If C<case> is followed by a C<< { >> character, this is I<not> interpreted
as the start of an anonymous hashref, but as a block. Matching via 
L<match::simple> is not attempted; instead the block is evaluated as
a boolean.

   switch ($number) {
      case 0:           say "zero";
      case { $_ % 2 }:  say "an odd number";
      default:          say "an even number";
   }

=head2 Statement blocks

If the first non-whitespace character is C<< { >>, the statement is treated
as a block rather than a single statement:

   switch ($number) {
      case 0: {
         say "zero";
      }
      case { $_ % 2 }: {
         say "an odd number";
      }
      default: {
         say "an even number";
      }
   }

=head2 Comparison expression

Above I said that matching is performed by L<match::simple>. That was a lie.
L<match::simple> is just the default. You can provide your own expression
for matching:

   switch ($number) if ($a > $b) {
      case 1000:   say "greater than 1000";
      case 100:    say "greater than 100";
      case 10:     say "greater than 10";
      case 1:      say "greater than 1";
   }

C<< $a >> is the TERM and C<< $b >> is the EXPR.

=head2 Switch expressions

Although C<switch> acts as a full statement usually, it can be used as part
of an expression if the keyword C<do> appears before the block:

   my $day_type = switch ($day) do {
      case 0, 6:  "weekend";
      default:    "weekday";
   };

=head2 Fallthrough

There's no fallthrough.

=begin trustme

=item switch

=end trustme

=head1 CAVEATS

Internally a lot of parts of code are passed around as coderefs, so
certain things might not work how you'd expect inside C<switch>:

=over

=item * 

C<caller>

=item * 

C<return>

=item * 

C<< @_ >>

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=PerlX-Switch>.

=head1 SEE ALSO

L<Switch::Plain>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

