use strict;
use warnings;

package DBIx::Squirrel::st;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::st::ISA     = ( 'DBI::st' );
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::it;
use DBIx::Squirrel::util 'throw', 'whine';
use Scalar::Util 'reftype';

use constant {
    E_INV_POS_PH => 'Cannot bind invalid positional placeholder (%s)',
    E_UNK_PH     => 'Cannot bind unknown placeholder (%s)',
};

sub _id {
    my $self = $_[ 0 ];
    return do {
        if ( wantarray ) {
            ref $self ? ( 0+ $self, $self ) : ();
        } else {
            ref $self ? 0+ $self : undef;
        }
    };
}

sub _private {
    my $self = shift;
    return do {
        if ( ref $self ) {
            my $id = 0+ $self;
            unless ( $self->{ private_dbix_squirrel } ) {
                $self->{ private_dbix_squirrel } = {};
            }
            if ( @_ ) {
                $self->{ private_dbix_squirrel } = {
                    %{ $self->{ private_dbix_squirrel } },
                    do {
                        if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
                            %{ $_[ 0 ] };
                        } else {
                            @_;
                        }
                    },
                };
            }
            if ( wantarray ) {
                ( $self->{ private_dbix_squirrel }, $self, $id );
            } else {
                $self->{ private_dbix_squirrel };
            }
        } else {
            wantarray ? () : undef;
        }
    };
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
    my ( $priv, $sth ) = shift->_private;
    if ( @_ ) {
        my $order = $priv->{ params };
        if ( $order || ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) ) {
            my %kv = _format_params( $order, @_ );
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
    my $order  = shift;
    my @params = do {
        if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
            %{ +shift };
        } elsif ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
            @{ +shift };
        } else {
            @_;
        }
    };
    return do {
        if ( my %order = _order_of_placeholders_if_positional( $order ) ) {
            map { ( $order{ $_ } => $params[ $_ - 1 ] ) } keys %order;
        } else {
            whine 'Check bind values' if @params % 2;
            @params;
        }
    };
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
    my ( $priv, $sth ) = shift->_private;
    my $param = shift;
    my %b;
    if ( my $order = $priv->{ params } ) {
        if ( $param =~ m/^([\:\$\?]?(\d+))$/ ) {
            $sth->DBI::st::bind_param( $2, ( $b{ $2 } = shift ) );
        } else {
            if ( substr( $param, 0, 1 ) ne ':' ) {
                $param = ":$param";
            }
            my @bound = (
                map    { $sth->DBI::st::bind_param( $_, ( $b{ $_ } = shift ) ) }
                  grep { $order->{ $_ } eq $param }
                  keys %{ $order }
            );
            unless ( @bound || $DBIx::Squirrel::RELAXED_PARAM_CHECKS ) {
                throw E_UNK_PH, $param;
            }
        }
    } else {
        $sth->DBI::st::bind_param( $param, ( $b{ $param } = shift ) );
    }
    return wantarray ? %b : \%b;
}

sub prepare {
    my $sth = shift;
    my $dbh = $sth->{ Database };
    return $dbh->prepare( $sth->{ Statement }, @_ );
}

sub result_set {
    return bless( shift->iterate( @_ ), 'DBIx::Squirrel::ResultSet' );
}

sub iterate {
    my ( $priv, $sth ) = shift->_private;
    my $itor = $priv->{ itor } or do {
        $priv->{ itor } = DBIx::Squirrel::it->new( $sth, @_ );
    };
    return $priv->{ itor };
}

sub reset {
    shift->iterate->reset( @_ )->sth;
}

sub single {
    shift->iterate->single( @_ );
}

sub find {
    shift->iterate->find( @_ );
}

sub first {
    shift->iterate->first( @_ );
}

sub all {
    shift->iterate->all( @_ );
}

sub remaining {
    shift->iterate->remaining( @_ );
}

sub next {
    shift->iterate->next( @_ );
}

sub count {
    shift->iterate->count( @_ );
}

sub reiterate {
    shift->prepare->iterate( @_ );
}

sub iterator {
    shift->_private->{ itor };
}

BEGIN {
    *resultset = *result_set;
    *rs        = *result_set;
    *it        = *iterate;
    *itor      = *iterator;
    *reit      = *reiterate;
    *clone     = *prepare;
}

## use critic

1;
