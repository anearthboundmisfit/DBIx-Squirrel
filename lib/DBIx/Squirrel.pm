use strict;
use warnings;

package DBIx::Squirrel;

BEGIN {
    $DBIx::Squirrel::VERSION = '2020.11.00';
    @DBIx::Squirrel::ISA     = ( 'DBI' );
}

use DBI;
use DBIx::Squirrel::st;
use DBIx::Squirrel::db;

sub connect {

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel - A module for working with databases in Perl.

=head1 VERSION

2020.11.00

=cut
