use strict;
use warnings;

package DBIx::Squirrel::dr;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::dr::ISA     = ( 'DBI::dr' );
    *DBIx::Squirrel::dr::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBI;
use DBIx::Squirrel::db;
use DBIx::Squirrel::util 'Dumper';
use Scalar::Util 'blessed';
use Storable qw/dclone/;

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
    if ( ref $maybe_dbh ) {
        if ( blessed( $maybe_dbh ) && $maybe_dbh->isa( 'DBI::db' ) ) {
            return 1;
        }
    }
    return;
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
