use strict;
use warnings;

package DBIx::Squirrel::result;

BEGIN {
    *DBIx::Squirrel::result::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'reftype';
use Sub::Name 'subname';
use DBIx::Squirrel::util 'throw';

use constant {
    E_BAD_OBJECT     => 'Object is not a blessed array or hash reference',
    E_STH_EXPIRED    => 'Result is no longer associated with a statement',
    E_UNKNOWN_COLUMN => 'Unrecognised column (%s)',
};

our $AUTOLOAD;

sub new { bless $_[ 1 ], ref $_[ 0 ] || $_[ 0 ] }

sub resultclass { $_[ 0 ]->results->resultclass }

sub rowclass { $_[ 0 ]->results->rowclass }

sub get_column
{
    my ( $self, $name ) = ( $_[ 0 ], ( $_[ 1 ] // '' ) );
    $_ = do {
        if ( reftype( $self ) eq 'ARRAY' ) {
            my $sth = $self->results->sth
              or throw E_STH_EXPIRED;
            my $index = $sth->{ NAME_lc_hash }{ lc $name };
            throw E_UNKNOWN_COLUMN, $name unless defined $index;
            $self->[ $index ];
        } elsif ( reftype( $self ) eq 'HASH' ) {
            if ( exists $self->{ $name } ) {
                $self->{ $name };
            } else {
                local ( $_ );
                my ( $index ) = grep { lc eq $name } keys %{ $self };
                throw E_UNKNOWN_COLUMN, $name unless defined $index;
                $self->{ $index };
            }
        } else {
            throw E_BAD_OBJECT;
        }
    };
}

# AUTOLOAD is called whenever a row object attempts invoke an unknown
# method. This implementation will try to create an accessor which is then
# asscoiated with a specific column. There is some initial overhead involved
# in the accessor's validation and creation. Thereafter, the accessor will
# respond just like as a normal method. During accessor's creation, AUTOLOAD
# will decide the best strategy for geting the column's data depending on
# the underlying row implementation (arrayref or hashref), resulting in
# an accessor that is always appropriate.
#
sub AUTOLOAD
{ ## no critic (TestingAndDebugging::ProhibitNoStrict)
    ( my $name = $AUTOLOAD ) =~ s/.*:://;
    if ( $name ne 'DESTROY' ) {
        my ( $self, $class ) = ( $_[ 0 ], ref $_[ 0 ] );
        my $symbol = "$class\::$name";
        no strict 'refs';
        *{ $symbol } = do {
            if ( reftype( $self ) eq 'ARRAY' ) {
                my $sth = $self->results->sth
                  or throw E_STH_EXPIRED;
                my $index = $sth->{ NAME_lc_hash }{ lc $name };
                throw E_UNKNOWN_COLUMN, $name unless defined $index;
                subname( $symbol, sub { $_[ 0 ]->[ $index ] } );
            } elsif ( reftype( $self ) eq 'HASH' ) {
                if ( exists $self->{ $name } ) {
                    subname( $symbol, sub { $_[ 0 ]->{ $name } } );
                } else {
                    local ( $_ );
                    my ( $index ) = grep { lc eq $name } keys %{ $self };
                    throw E_UNKNOWN_COLUMN, $name unless defined $index;
                    subname( $symbol, sub { $_[ 0 ]->{ $index } } );
                }
            } else {
                throw E_BAD_OBJECT;
            }
        };
        goto &{ $symbol };
    }
} ## use critic

BEGIN {
    *rc           = *resultclass;
    *result_class = *resultclass;
    *row_class    = *rowclass;
    *class        = *rowclass;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::result - DBIx-Squirrel result (row) base class

=head1 VERSION

2020.11.00

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

I Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
