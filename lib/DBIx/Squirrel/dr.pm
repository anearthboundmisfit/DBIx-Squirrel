use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::dr;

BEGIN {
    @DBIx::Squirrel::dr::ISA     = ( 'DBI::dr' );
    *DBIx::Squirrel::dr::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBI;
use Scalar::Util 'blessed';
use DBIx::Squirrel::db;

sub connect_cached
{
    if ( my $handle = shift->DBI::connect_cached( @_ ) ) {
        bless $handle, 'DBIx::Squirrel::db';
    } else {
        undef;
    }
}

sub connect
{
    if ( @_ > 1 && _is_db_handle( $_[ 1 ] ) ) {
        goto &connect_clone;
    } else {
        if ( my $handle = shift->DBI::connect( @_ ) ) {
            bless $handle, 'DBIx::Squirrel::db';
        } else {
            undef;
        }
    }
}

sub _is_db_handle
{
    if ( ref $_[ 0 ] ) {
        if ( my $blessed = blessed( $_[ 0 ] ) ) {
            if ( $_[ 0 ]->isa( 'DBI::db' ) ) {
                $blessed;
            } else {
                undef;
            }
        } else {
            undef;
        }
    } else {
        undef;
    }
}

sub connect_clone
{
    my ( $package, $dbh, $attr ) = @_;
    if ( my $clone = $attr ? $dbh->clone( $attr ) : $dbh->clone ) {
        bless $clone, 'DBIx::Squirrel::db';
    } else {
        undef;
    }
}

1;
