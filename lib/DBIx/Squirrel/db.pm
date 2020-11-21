use strict;
use warnings;

package DBIx::Squirrel::db;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'blessed', 'reftype';
use DBIx::Squirrel::util 'throw';
use DBIx::Squirrel::st;

sub prepare {
    my $dbh = shift;
    my ( $params, $std, $sql ) = do {
        my $statement = do {
            if ( blessed( $_[ 0 ] ) ) {
                if ( $_[ 0 ]->isa( 'DBI::st' ) ) {
                    shift->{ Statement };
                } elsif ( $_[ 0 ]->isa( 'DBIx::Squirrel::st' ) ) {
                    shift->{ private_dbix_squirrel }{ sql };
                } else {
                    throw 'Expected a statement handle';
                }
            } else {
                shift;
            }
        };
        if ( defined $statement ) {
            $statement =~ s{\s+\Z}{}s;
            $statement =~ s{\A\s+}{}s;
        }
        if ( length $statement ) {
            ( _get_param_order( $statement ), $statement );
        } else {
            throw 'Expected a statement';
        }
    };
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare( $std, @_ );
        } else {
            $dbh->DBI::db::prepare( $sql, @_ );
        }
    };
    if ( $sth ) {
        $sth->{ private_dbix_squirrel } = {
            sql    => $sql,
            std    => $std,
            params => $params,
        };
        bless $sth, 'DBIx::Squirrel::st';
    }
    return $sth;
}

sub _get_param_order {
    my $sql   = shift;
    my $order = do {
        my %order;
        if ( $sql ) {
            my @params = $sql =~ m{[\:\$\?]\w+\b}g;
            if ( my $count = @params ) {
                $sql =~ s{\s+\Z}{}s;
                $sql =~ s{\A\s+}{}s;
                $sql =~ s{[\:\$\?]\w+\b}{?}g;
                for ( my $p = 0 ; $p < $count ; $p += 1 ) {
                    $order{ 1 + $p } = $params[ $p ];
                }
            }
        }
        %order ? \%order : undef;
    };
    return wantarray ? ( $order, $sql ) : $order;
}

sub prepare_cached {
    my $dbh = shift;
    my ( $params, $std, $sql ) = do {
        my $statement = do {
            if ( blessed( $_[ 0 ] ) ) {
                if ( $_[ 0 ]->isa( 'DBI::st' ) ) {
                    shift->{ Statement };
                } elsif ( $_[ 0 ]->isa( 'DBIx::Squirrel::st' ) ) {
                    shift->{ private_dbix_squirrel }{ sql };
                } else {
                    throw 'Expected a statement handle';
                }
            } else {
                shift;
            }
        };
        if ( defined $statement ) {
            $statement =~ s{\s+\Z}{}s;
            $statement =~ s{\A\s+}{}s;
        }
        if ( length $statement ) {
            ( _get_param_order( $statement ), $statement );
        } else {
            throw 'Expected a statement';
        }
    };
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare_cached( $std, @_ );
        } else {
            $dbh->DBI::db::prepare_cached( $sql, @_ );
        }
    };
    if ( $sth ) {
        $sth->{ private_dbix_squirrel } = {
            cache_key => join( '#', ( caller 0 )[ 1, 2 ] ),
            sql       => $sql,
            std       => $std,
            params    => $params,
        };
        bless $sth, 'DBIx::Squirrel::st';
    }
    return $sth;
}

sub do {
    my $dbh       = shift;
    my $statement = shift;
    my $res       = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] ) {
                if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                    $dbh->prepare( $statement, shift )->execute( @_ );
                } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    $dbh->prepare( $statement )->execute( @_ );
                } else {
                    throw 'Expected a reference to a HASH or ARRAY';
                }
            } else {
                if ( defined $_[ 0 ] ) {
                    $dbh->prepare( $statement )->execute( @_ );
                } else {
                    $dbh->prepare( $statement, shift )->execute( @_ );
                }
            }
        } else {
            $dbh->prepare( $statement )->execute;
        }
    };
    return $res;
}

sub iterate {
    my $dbh       = shift;
    my $statement = shift;
    return $dbh->prepare( $statement )->iterate( @_ );
}

BEGIN {
    *it = *iterate;
}

## use critic

1;
