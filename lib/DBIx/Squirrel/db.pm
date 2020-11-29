use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::db;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'blessed', 'reftype';
use DBIx::Squirrel::util 'throw';
use DBIx::Squirrel::st;
use DBIx::Squirrel::ResultSet;

use constant {
    E_EXP_STATEMENT => 'Expected a statement',
    E_EXP_STH       => 'Expected a statement handle',
    E_EXP_REF       => 'Expected a reference to a HASH or ARRAY',
};

sub prepare
{
    my $dbh = shift;
    my ( $params, $std, $sql ) = _common_prepare_work( shift );
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare( $std, @_ );
        } else {
            $dbh->DBI::db::prepare( $sql, @_ );
        }
    };
    if ( $sth ) {
        bless( $sth, 'DBIx::Squirrel::st' )->_private( {
                sql    => $sql,
                std    => $std,
                params => $params,
            },
        );
    }
    $sth;
}

sub _common_prepare_work
{
    my ( $order, $std, $sql ) = do {
        my $statement = do {
            if ( blessed( $_[ 0 ] ) ) {
                if ( $_[ 0 ]->isa( 'DBIx::Squirrel::st' ) ) {
                    shift->_private->{ sql };
                } elsif ( $_[ 0 ]->isa( 'DBI::st' ) ) {
                    shift->{ Statement };
                } else {
                    throw E_EXP_STH;
                }
            } else {
                shift;
            }
        };
        ( _get_param_order( $statement ), $statement );
    };
    if ( length $std ) {
        ( $order, $std, $sql );
    } else {
        throw E_EXP_STATEMENT;
    }
}

sub _get_param_order
{
    my $sql   = shift;
    my $order = do {
        my %order;
        if ( $sql ) {
            $sql =~ s{\s+\Z}{}s;
            $sql =~ s{\A\s+}{}s;
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
    wantarray ? ( $order, $sql ) : $order;
}

sub prepare_cached
{
    my $dbh = shift;
    my ( $params, $std, $sql ) = _common_prepare_work( shift );
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare_cached( $std, @_ );
        } else {
            $dbh->DBI::db::prepare_cached( $sql, @_ );
        }
    };
    if ( $sth ) {
        bless( $sth, 'DBIx::Squirrel::st' )->_private( {
                cache_key => join( '#', ( caller 0 )[ 1, 2 ] ),
                sql       => $sql,
                std       => $std,
                params    => $params,
            }
        );
    }
    $sth;
}

sub do
{
    my $dbh       = shift;
    my $statement = shift;
    my ( $res, $sth );
    if ( @_ ) {
        if ( ref $_[ 0 ] ) {
            if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                if ( $sth = $dbh->prepare( $statement, shift ) ) {
                    $res = $sth->execute( @_ );
                }
            } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                if ( $sth = $dbh->prepare( $statement ) ) {
                    $res = $sth->execute( @_ );
                }
            } else {
                throw E_EXP_REF;
            }
        } else {
            if ( defined $_[ 0 ] ) {
                if ( $sth = $dbh->prepare( $statement ) ) {
                    $res = $sth->execute( @_ );
                }
            } else {
                if ( $sth = $dbh->prepare( $statement, shift ) ) {
                    $res = $sth->execute( @_ );
                }
            }
        }
    } else {
        if ( $sth = $dbh->prepare( $statement ) ) {
            $res = $sth->execute;
        }
    }
    wantarray ? ( $res, $sth ) : $res;
}

sub iterate
{
    my $dbh       = shift;
    my $statement = shift;
    $_ = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] ) {
                if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->iterate( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'CODE' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } else {
                    throw E_EXP_REF;
                }
            } else {
                if ( defined $_[ 0 ] ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } else {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->iterate( @_ );
                    }
                }
            }
        } else {
            if ( my $sth = $dbh->prepare( $statement ) ) {
                $sth->iterate;
            }
        }
    };
}

sub resultset
{
    my $dbh       = shift;
    my $statement = shift;
    $_ = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] ) {
                if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->resultset( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'CODE' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } else {
                    throw E_EXP_REF;
                }
            } else {
                if ( defined $_[ 0 ] ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } else {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->resultset( @_ );
                    }
                }
            }
        } else {
            if ( my $sth = $dbh->prepare( $statement ) ) {
                $sth->resultset;
            }
        }
    };
}

BEGIN {
    *it         = *iterate;
    *rs         = *resultset;
    *result_set = $resultset;
}

## use critic

1;
