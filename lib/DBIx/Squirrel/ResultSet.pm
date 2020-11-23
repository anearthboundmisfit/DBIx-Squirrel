use strict;
use warnings;

package DBIx::Squirrel::ResultSet;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::ResultSet::ISA     = ( 'DBIx::Squirrel::it' );
    *DBIx::Squirrel::ResultSet::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::Result;

sub _get_row {
    my $row = shift->SUPER::_get_row( @_ );
    bless $row, 'DBIx::Squirrel::Result' if $row;
    return $row;
}

sub remaining {
    my $rows = shift->SUPER::remaining( @_ );
    bless $_, 'DBIx::Squirrel::Result' for @{ $rows };
    return $rows;
}

## use critic

1;
