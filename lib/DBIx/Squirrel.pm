use strict;
use warnings;

package DBIx::Squirrel;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::ISA     = ( 'DBI' );
    $DBIx::Squirrel::VERSION = '2020.11.00';
}

use DBI;
use DBIx::Squirrel::st;
use DBIx::Squirrel::db;
use Scalar::Util 'blessed';

sub _is_db_handle {
    my ( $maybe_dbh ) = @_;
    if ( ref $maybe_dbh ) {
        if ( blessed( $maybe_dbh ) && $maybe_dbh->isa( 'DBI::db' ) ) {
            return 1;
        }
    }
    return;
}

sub connect_cached {
    my $handle = shift->DBI::connect_cached( @_ );
    return $handle;
}

sub connect {
    my $handle = do {
        if ( @_ > 1 && _is_db_handle( $_[ 1 ] ) ) {
            shift->connect_cloned( @_ );
        } else {
            shift->DBI::connect( @_ );
        }
    };
    return $handle;
}

sub connect_cloned {
    my $handle = do {
        my ( $package, $master, $attr ) = @_;
        if ( my $clone = $attr ? $master->clone( $attr ) : $master->clone ) {
            bless $clone, join( '::', $package, 'db' );
        } else {
            undef;
        }
    };
    return $handle;
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
