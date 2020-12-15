=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::st - DBI statement handle (DBI::st) subclass

=head1 VERSION

2020.11.00

=head1 SYNOPSIS

=head1 DESCRIPTION

This module subclasses DBI's DBI::st module, providing a number of progressive
and additive enhancements to statement handle objects:

=over

=item * the binding of parameter value;

=item * statement execution;

=item * the creation of result set iterators.

=back

=cut

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
use DBIx::Squirrel::itor;
use DBIx::Squirrel::results;

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
    wantarray ? %b : \%b;
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

sub prepare
{
    my $sth = shift;
    $sth->{ Database }->prepare( $sth->{ Statement }, @_ );
}

BEGIN { *clone = *prepare }

sub iterate { DBIx::Squirrel::itor->new( shift, @_ ) }

BEGIN { *it = *iterate }

sub resultset { DBIx::Squirrel::results->new( shift, @_ ) }

BEGIN { *rs = *resultset }

sub iterator { $_[ 0 ]->_private->{ itor } }

BEGIN { *itor = *iterator }

1;

__END__

=head1 AUTHOR

I Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
