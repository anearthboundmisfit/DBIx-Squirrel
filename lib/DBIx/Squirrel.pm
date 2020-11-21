use strict;
use warnings;

package DBIx::Squirrel;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::ISA     = ( 'DBI' );
    $DBIx::Squirrel::VERSION = '2020.11.00';
}

use DBIx::Squirrel::util 'Dumper';
use DBIx::Squirrel::dr;

our $RELAXED_PARAM_CHECKS     = 0;
our $FINISH_ACTIVE_ON_EXECUTE = 1;
our $NORMALISED_STATEMENTS    = 1;

BEGIN {
    *connect_cached        = *DBIx::Squirrel::dr::connect_cached;
    *connect               = *DBIx::Squirrel::dr::connect;
    *connect_clone         = *DBIx::Squirrel::dr::connect_clone;
    *err                   = *DBI::err;
    *errstr                = *DBI::errstr;
    *rows                  = *DBI::rows;
    *lasth                 = *DBI::lasth;
    *state                 = *DBI::state;
    *NORMALIZED_STATEMENTS = *NORMALISED_STATEMENTS;
}

## use critic

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel - A module for working with databases in Perl.

=head1 VERSION

2020.11.00

=cut
