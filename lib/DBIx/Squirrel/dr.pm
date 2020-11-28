use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::dr;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::dr::ISA     = ( 'DBI::dr' );
    *DBIx::Squirrel::dr::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBI;
use DBIx::Squirrel::db;
use Scalar::Util 'blessed';

sub connect_cached {
    my $handle = shift->DBI::connect_cached( @_ );
    if ( $handle ) {
        bless $handle, 'DBIx::Squirrel::db';
    }
    return $handle;
}

sub connect {
    my $handle = do {
        if ( @_ > 1 && _is_db_handle( $_[ 1 ] ) ) {
            goto &connect_clone;
        } else {
            shift->DBI::connect( @_ );
        }
    };
    if ( $handle ) {
        bless $handle, 'DBIx::Squirrel::db';
    }
    return $handle;
}

sub _is_db_handle {
    my ( $maybe_dbh ) = @_;
    my $blessed;
    if ( ref $maybe_dbh ) {
        if ( $blessed = blessed( $maybe_dbh ) ) {
            if ( $maybe_dbh->isa( 'DBI::db' ) ) {
                return $blessed;
            }
        }
    }
    return $blessed;
}

sub connect_clone {
    my $handle = do {
        my ( $package, $master, $attr ) = @_;
        if ( my $clone = $attr ? $master->clone( $attr ) : $master->clone ) {
            bless $clone, 'DBIx::Squirrel::db';
        } else {
            undef;
        }
    };
    return $handle;
}

## use critic

1;
