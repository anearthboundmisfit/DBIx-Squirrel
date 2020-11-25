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

sub resultclass { 'DBIx::Squirrel::ResultClass' }

sub rowclass {
    my $self        = $_[ 0 ];
    my $resultclass = $self->resultclass;
    my $rowclass    = sprintf '%s_0x%x', $resultclass, 0+ $self;
    return wantarray ? ( $rowclass, $self ) : $rowclass;
}

sub _get_row {
    my $self = shift;
    my $row  = $self->SUPER::_get_row( @_ );
    $self->_bless_row( $row );
    return $row;
}

sub _bless_row {
    my ( $rowclass, $self ) = shift->rowclass;
    my $row = do {
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
    return $row;
}

sub remaining {
    my $self = shift;
    my $rows = $self->SUPER::remaining( @_ );
    if ( @{ $rows } ) {
        $self->_bless_row( $rows->[ 0 ] );
        if ( @{ $rows } > 1 ) {
            my $rowclass = ref $rows->[ 0 ];
            for my $row ( @{ $rows }[ 1 .. $#{ $rows } ] ) {
                bless $row, $rowclass;
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
