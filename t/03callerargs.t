=pod

=encoding utf-8

=head1 PURPOSE

Test using C<< @_ >> within C<switch> blocks.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::More;

use Switcheroo;

sub switcher
{
	switch ($_[0]) {
		case 0, 6:  $_[2];
		default:    { $_[1] };
	}
}

is(switcher(0, 'weekday', 'weekend'), 'weekend');
is(switcher($_, 'weekday', 'weekend'), 'weekday') for 1..5;
is(switcher(6, 'weekday', 'weekend'), 'weekend');

done_testing;

