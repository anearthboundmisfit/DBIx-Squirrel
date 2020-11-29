use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::st;

BEGIN {
    @DBIx::Squirrel::st::ISA     = ( 'DBI::st' );
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBI;
use Scalar::Util 'reftype';
use DBIx::Squirrel::util 'throw', 'whine';
use DBIx::Squirrel::it;
use DBIx::Squirrel::ResultSet;

use constant {
    E_INVALID_PLACEHOLDER => 'Cannot bind invalid placeholder (%s)',
    E_UNKNOWN_PLACEHOLDER => 'Cannot bind unknown placeholder (%s)',
    W_CHECK_BIND_VALS     => 'Check bind values match placeholder scheme',
};

sub _id
{
    if ( wantarray ) {
        ref $_[ 0 ] ? ( 0+ $_[ 0 ], $_[ 0 ] ) : ();
    } else {
        ref $_[ 0 ] ? 0+ $_[ 0 ] : undef;
    }
}

sub _private
{
    my $self = shift;
    if ( ref $self ) {
        my $private = do {
            if ( $self->{ private_dbix_squirrel } ) {
                $self->{ private_dbix_squirrel };
            } else {
                $self->{ private_dbix_squirrel } = {};
            }
        };
        if ( @_ ) {
            $private = $self->{ private_dbix_squirrel } = {
                %{ $private },
                do {
                    if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
                        %{ $_[ 0 ] };
                    } else {
                        @_;
                    }
                },
            };
        }
        wantarray ? ( $private, $self, 0+ $self ) : $private;
    } else {
        wantarray ? () : undef;
    }
}

sub execute
{
    my $sth = shift;
    if ( $sth->{ Active } && $DBIx::Squirrel::FINISH_ACTIVE_ON_EXECUTE ) {
        $sth->finish;
    }
    if ( @_ ) {
        $sth->bind( @_ );
    }
    $sth->DBI::st::execute;
}

sub bind
{
    my ( $p, $sth ) = shift->_private;
    if ( @_ ) {
        my $order = $p->{ params };
        if ( $order || ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) ) {
            my %kv = @{ _format_params( $order, @_ ) };
            while ( my ( $k, $v ) = each %kv ) {
                if ( $k ) {
                    if ( $k =~ m/^([\:\$\?]?(\d+))$/ ) {
                        if ( $2 > 0 ) {
                            $sth->bind_param( $2, $v );
                        } else {
                            throw E_INVALID_PLACEHOLDER, $1;
                        }
                    } else {
                        $sth->bind_param( $k, $v );
                    }
                }
            }
        } else {
            my @p = do {
                if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    @{ $_[ 0 ] };
                } else {
                    @_;
                }
            };
            for ( my $n = 0 ; $n <= $#p ; $n += 1 ) {
                $sth->bind_param( 1 + $n, $p[ $n ] );
            }
        }
    }
    $sth;
}

sub _format_params
{
    my $order  = shift;
    my @params = do {
        if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
            %{ $_[ 0 ] };
        } elsif ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'ARRAY' ) {
            @{ $_[ 0 ] };
        } else {
            @_;
        }
    };
    if ( my $ph = _order_of_placeholders_if_positional( $order ) ) {
        [ map { ( $ph->{ $_ } => $params[ $_ - 1 ] ) } keys %{ $ph } ];
    } else {
        whine W_CHECK_BIND_VALS if @params % 2;
        \@params;
    }
}

sub _order_of_placeholders_if_positional
{
    my $order = shift;
    if ( ref $order && reftype( $order ) eq 'HASH' ) {
        my @names = values %{ $order };
        my $count = grep { m/^[\:\$\?]\d+$/ } @names;
        if ( $count == @names ) {
            $order;
        } else {
            undef;
        }
    } else {
        undef;
    }
}

sub bind_param
{
    my ( $p, $sth ) = shift->_private;
    my $param = shift;
    my %b;
    if ( my $order = $p->{ params } ) {
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
                throw E_UNKNOWN_PLACEHOLDER, $param;
            }
        }
    } else {
        $sth->DBI::st::bind_param( $param, ( $b{ $param } = shift ) );
    }
    return wantarray ? %b : \%b;
}

sub prepare
{
    my $sth = shift;
    return $sth->{ Database }->prepare( $sth->{ Statement }, @_ );
}

sub iterate { DBIx::Squirrel::it->new( shift, @_ ) }

sub resultset { DBIx::Squirrel::ResultSet->new( shift, @_ ) }

sub iterator { $_[ 0 ]->_private->{ itor } }

BEGIN {
    *itor  = *iterator;
    *it    = *iterate;
    *rs    = *resultset;
    *clone = *prepare;
}

1;
