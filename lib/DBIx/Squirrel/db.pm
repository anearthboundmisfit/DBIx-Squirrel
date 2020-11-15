use strict;
use warnings;

package DBIx::Squirrel::db;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use DBIx::Squirrel::st;

sub _get_params_order {
    my $order = do {
        my %order;
        if ( my $sql = shift ) {
            my @params = $sql =~ m{(\:\w+)\b}g;
            if ( my $count = @params ) {
                $sql =~ s{\:\w+\b}{?}g;
                for ( my $p = 0 ; $p < $count ; $p += 1 ) {
                    $order{ 1 + $p } = $params[ $p ];
                }
            }
        }
        %order ? \%order : undef;
    };
    return $order;
}

sub prepare_cached {
    my $dbh = shift;
    my $sql = shift;
    my $sth = do {
        if ( $sql ) {
            $dbh->DBI::db::prepare_cached( $sql, @_ );
        } else {
            undef;
        }
    };
    if ( $sth ) {
        if ( my $order = _get_params_order( $sql ) ) {
            $sth->{ private_sq_params } = $order;
        }
        $sth->{ private_sq_cache_key } = join '#', ( caller 0 )[ 1, 2 ];
    }
    return $sth;
}

sub prepare {
    my $dbh = shift;
    my $sql = shift;
    my $sth = do {
        if ( $sql ) {
            $dbh->DBI::db::prepare( $sql, @_ );
        } else {
            undef;
        }
    };
    if ( $sth ) {
        if ( my $order = _get_params_order( $sql ) ) {
            $sth->{ private_sq_params } = $order;
        }
    }
    return $sth;
}

## use critic

1;
