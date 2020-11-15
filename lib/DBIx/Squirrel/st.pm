use strict;
use warnings;

package DBIx::Squirrel::st;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::st::ISA     = ( 'DBI::st' );
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::util 'throw', 'Dumper';
use Scalar::Util 'reftype';

use constant {
    E_INV_POS_PH => 'Cannot bind invalid positional placeholder (%s)',
    E_UNK_PH     => 'Cannot bind unknown placeholder (%s)',
};

sub execute {
    my $sth = shift;
    if ( @_ ) {
        $sth->bind( @_ );
    }
    if ( $DBIx::Squirrel::FINISH_ACTIVE_ON_EXECUTE ) {
        $sth->finish if $sth->{ Active };
    }
    return $sth->DBI::st::execute;
}

sub bind {
    my $sth = shift;
    if ( @_ ) {
        my $order = $sth->{ private_dbix_squirrel }{ params };
        if ( $order || ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) ) {
            my %kv = do {
                if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
                    %{ +shift };
                } elsif ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    _format_params( $order, @{ +shift } );
                } else {
                    _format_params( $order, @_ );
                }
            };
            while ( my ( $k, $v ) = each %kv ) {
                if ( $k ) {
                    if ( $k =~ m/^([\:\$\?]?(\d+))$/ ) {
                        if ( $2 > 0 ) {
                            $sth->bind_param( $2, $v );
                        } else {
                            throw E_INV_POS_PH, $1;
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

sub _format_params {
    my @params = do {
        if ( my %order = _order_of_placeholders_if_positional( shift ) ) {
            map { ( $order{ $_ } => $_[ $_ - 1 ] ) } keys %order;
        } else {
            @_;
        }
    };
    return @params;
}

sub _order_of_placeholders_if_positional {
    if ( my $order = shift ) {
        if ( ref $order && reftype( $order ) eq 'HASH' ) {
            my @names = values %{ $order };
            my $count = grep { m/^[\:\$\?]\d+$/ } @names;
            if ( $count == @names ) {
                return %{ $order };
            }
        }
    }
    return;
}

sub bind_param {
    my $sth    = shift;
    my $param  = shift;
    my $result = do {
        if ( my $order = $sth->{ private_dbix_squirrel }{ params } ) {
            if ( $param =~ m/^([\:\$\?]?(\d+))$/ ) {
                $sth->DBI::st::bind_param( $2, @_ );
            } else {
                if ( substr( $param, 0, 1 ) ne ':' ) {
                    $param = ":$param";
                }
                my @bound = map { $sth->DBI::st::bind_param( $_, @_ ) } (
                    grep { $order->{ $_ } eq $param } keys %{ $order },
                );
                unless ( @bound || $DBIx::Squirrel::RELAXED_PARAM_CHECKS ) {
                    throw E_UNK_PH, $param;
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
