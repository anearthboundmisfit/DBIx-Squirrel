use strict;
use warnings;

package DBIx::Squirrel::ResultSet;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    @DBIx::Squirrel::ResultSet::ISA     = ( 'DBIx::Squirrel::it' );
    *DBIx::Squirrel::ResultSet::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'reftype', 'weaken';
use Sub::Name 'subname';
use DBIx::Squirrel::ResultSet::Result;

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $id, $self ) = shift->_id;
    my $class = $self->resultclass;
    no strict 'refs';
    undef &{ "$class\::resultset" };
    return $self->SUPER::DESTROY;
}

sub resultclass { sprintf( '%s::Result_0x%x', ref $_[ 0 ], 0+ $_[ 0 ] ) }

sub _get_row {
    my $self = shift;
    my $row  = $self->SUPER::_get_row( @_ );
    $self->_bless_row( $row );
    return $row;
}

sub _bless_row {
    my $self = shift;
    my $row  = do {
        if ( ref $_[ 0 ] ) {
            my $class = $self->resultclass;
            unless ( defined &{ $class . '::resultset' } ) {
                no strict 'refs';
                undef &{ "$class\::resultset" };
                *{ "$class\::resultset" } = do {
                    weaken( my $rs = $self );
                    subname( "$class\::resultset", sub { $rs } );
                };
                undef &{ "$class\::rs" };
                *{ "$class\::rs" }  = *{ "$class\::resultset" };
                @{ "$class\::ISA" } = (
                    'DBIx::Squirrel::ResultSet::Result',
                );
            }
            bless shift, $class;
        } else {
            undef;
        }
    };
    return $row;
}

sub remaining {
    my $self = shift;
    my $rows = $self->SUPER::remaining( @_ );
    if ( @{ $rows } ) {
        $self->_bless_row( $rows->[ 0 ] );
        if ( @{ $rows } > 1 ) {
            my $class = ref $rows->[ 0 ];
            for my $row ( @{ $rows }[ 1 .. $#{ $rows } ] ) {
                bless $row, $class;
            }
        }
    }
    return $rows;
}

BEGIN {
    *rc = *resultclass;
}

## use critic

1;
