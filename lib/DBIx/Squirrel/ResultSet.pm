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
use DBIx::Squirrel::it;
use DBIx::Squirrel::ResultClass;

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $id, $self ) = shift->_id;
    my $class = $self->resultclass;
    no strict 'refs';
    undef &{ "$class\::resultset" };
    return $self->SUPER::DESTROY;
}

sub new {
    my @cb;
    while ( ref $_[ -1 ] && reftype( $_[ -1 ] ) eq 'CODE' ) {
        unshift @cb, pop;
    }
    my $self = shift->SUPER::new( @_ );
    $self->_private->{ cb } = \@cb;
    return $self;
}

sub resultclass { 'DBIx::Squirrel::ResultClass' }

sub rowclass {
    my $self        = $_[ 0 ];
    my $resultclass = $self->resultclass;
    my $rowclass    = sprintf '%s_0x%x', $resultclass, 0+ $self;
    return wantarray ? ( $rowclass, $self ) : $rowclass;
}

sub _get_row {
    my $self = shift;
    my $row  = $self->SUPER::_get_row;
    return do {
        if ( @{ $self->_private->{ cb } } ) {
            $self->_transform( $self->_bless( $row ) );
        } else {
            $self->_bless( $row );
        }
    };
}

sub _transform {
    my ( $private, $self ) = shift->_private;
    return do {
        if ( defined $_[ 0 ] ) {
            local ( $_ );
            my $row = $_[ 0 ];
            for my $cb ( @{ $private->{ cb } } ) {
                $row = $cb->( $_ = $row );
            }
            $row;
        } else {
            undef;
        }
    };
}

sub _bless {
    my ( $rowclass, $self ) = shift->rowclass;
    return do {
        if ( ref $_[ 0 ] ) {
            my $resultclass = $self->resultclass;
            unless ( defined &{ $rowclass . '::resultset' } ) {
                no strict 'refs';
                undef &{ "$rowclass\::resultset" };
                *{ "$rowclass\::resultset" } = do {
                    weaken( my $rs = $self );
                    subname( "$rowclass\::resultset", sub { $rs } );
                };
                undef &{ "$rowclass\::rs" };
                *{ "$rowclass\::rs" }  = *{ "$rowclass\::resultset" };
                @{ "$rowclass\::ISA" } = ( $resultclass );
            }
            $rowclass->new( $_[ 0 ] );
        } else {
            undef;
        }
    };
}

sub remaining {
    my ( $rowclass, $self ) = shift->rowclass;
    $_ = do {
        local ( $_ );
        my $rows = $self->SUPER::remaining( @_ );
        if ( @{ $self->_private->{ cb } } ) {
            [ map { $self->_transform( $self->_bless( $_ ) ) } @{ $rows } ];
        } else {
            [ map { $self->_bless( $_ ) } @{ $rows } ];
        }
    };
    return wantarray ? @{ $_ } : $_;
}

BEGIN {
    *rc = *resultclass;
}

## use critic

1;
