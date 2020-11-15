use strict;
use warnings;

package DBIx::Squirrel::st;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::st::ISA     = ( 'DBI::st' );
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
}

use Carp 'croak';
use Scalar::Util 'reftype';

sub _unpack_params_by_order {
    my @params = do {
        if ( my $order = shift ) {
            if ( @_ ) {
                my %order              = %{ $order };
                my @names              = values %order;
                my $numeric_name_count = grep { m/^:\d+$/ } @names;
                if ( $numeric_name_count == @names ) {
                    map { ( $order{ $_ } => $_[ $_ - 1 ] ) }
                      keys %order;
                } else {
                    @_;
                }
            }
        }
    };
    return @params;
}

sub execute {
    my $sth = shift;
    if ( @_ ) {
        $sth->bind( @_ );
    }
    if ( $sth->{ Active } && $DBIx::Squirrel::FINISH_ACTIVE_ON_EXECUTE ) {
        $sth->finish;
    }
    return $sth->DBI::st::execute;
}

sub bind {
    my $sth = shift;
    if ( @_ ) {
        if ( $sth->{ private_sq_params }
            || ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) )
        {
            my %kv = do {
                if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
                    %{ +shift };
                } elsif ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    _unpack_params_by_order(
                        $sth->{ private_sq_params },
                        @{ +shift }
                    );
                } else {
                    _unpack_params_by_order(
                        $sth->{ private_sq_params },
                        @_
                    );
                }
            };
            while ( my ( $k, $v ) = each %kv ) {
                if ( $k ) {
                    if ( $k =~ m/^[\:\$\?]?(\d+)$/ ) {
                        if ( $1 > 0 ) {
                            $sth->bind_param( $1, $v );
                        }
                    } else {
                        $sth->bind_param( $k, $v );
                    }
                }
            }
        } else {
            my @p = do {
                if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    @{ +shift };
                } else {
                    @_;
                }
            };
            for ( my $n = 0 ; $n <= $#p ; $n += 1 ) {
                $sth->bind_param( 1 + $n, $p[ $n ] );
            }
        }
    }
    return $sth;
}

sub bind_param {
    my $sth    = shift;
    my $param  = shift;
    my $result = do {
        if ( my $order = $sth->{ private_sq_params } ) {
            if ( $param =~ m/^[\:\$\?]?(\d+)$/ ) {
                $sth->DBI::st::bind_param( $1, @_ );
            } else {
                if ( substr( $param, 0, 1 ) ne ':' ) {
                    $param = ":$param";
                }
                my @bound = map { $sth->DBI::st::bind_param( $_, @_ ) } (
                    grep { $order->{ $_ } eq $param } keys %{ $order },
                );
                unless ( @bound || $DBIx::Squirrel::RELAXED_PARAM_CHECKS ) {
                    croak 'Cannot bind unknown placeholder "$param"';
                }
                $sth;
            }
        } else {
            $sth->DBI::st::bind_param( $param, @_ );
        }
    };
    return $result;
}

## use critic

1;
