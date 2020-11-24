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
use DBIx::Squirrel::Result;

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    no strict 'refs';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $id, $self ) = shift->_id;
    my $class = ref( $self ) . '_' . sprintf( '0x%x', $id ) . '::Result';
    do {
        no warnings;
        *{ $class . '::_rs' } = subname( $class . '::_rs', sub { undef } );
    };
    return $self->SUPER::DESTROY;
}

sub _get_row {
    my $self = shift;
    my $row  = $self->SUPER::_get_row( @_ );
    $self->_bless_row( $row ) if ref $row;
    return $row;
}

sub _bless_row {
    no strict 'refs';
    my ( $id, $self ) = shift->_id;
    my $class = ref( $self ) . '_' . sprintf( '0x%x', $id ) . '::Result';
    my $row   = bless( shift, $class );
    unless ( defined &{ $class . '::_rs' } && $class->_rs ) {
        no warnings;
        @{ $class . '::ISA' } = ( 'DBIx::Squirrel::Result' );
        *{ $class . '::_rs' } = subname( $class . '::_rs', sub { $self } );
    }
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

## use critic

1;
