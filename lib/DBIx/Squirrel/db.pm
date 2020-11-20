use strict;
use warnings;

package DBIx::Squirrel::db;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'blessed';
use DBIx::Squirrel::st;

sub prepare {
    my $dbh = shift;
    my $sql = shift;
    my $sth = do {
        if ( $sql ) {
            if ( blessed( $sql ) && $sql->isa( 'DBI::st' ) ) {
                $dbh->DBI::db::prepare( $sql->{ Statement }, @_ );
            } else {
                $dbh->DBI::db::prepare( $sql, @_ );
            }
        } else {
            undef;
        }
    };
    if ( $sth ) {
        $sth->{ private_dbix_squirrel } = {
            params => _get_param_order( $sql ),
        };
        bless $sth, 'DBIx::Squirrel::st';
    }
    return $sth;
}

sub _get_param_order {
    my $order = do {
        my %order;
        if ( my $sql = shift ) {
            my @params = $sql =~ m{[\:\$\?]\w+\b}g;
            if ( my $count = @params ) {
                $sql =~ s{[\:\$\?]\w+\b}{?}g;
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
        $sth->{ private_dbix_squirrel } = {
            params    => _get_param_order( $sql ),
            cache_key => join( '#', ( caller 0 )[ 1, 2 ] ),
        };
        bless $sth, 'DBIx::Squirrel::st';
    }
    return $sth;
}

sub do {
    shift->prepare( shift )->execute( @_ );
}

sub iterate {
    shift->prepare( shift )->iterate( @_ );
}

BEGIN {
    *it = *iterate;
}

## use critic

1;
