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

sub resultclass { 'DBIx::Squirrel::ResultClass' }

sub rowclass {
    my $self        = $_[ 0 ];
    my $resultclass = $self->resultclass;
    my $rowclass    = sprintf '%s_0x%x', $resultclass, 0+ $self;
    return wantarray ? ( $rowclass, $self ) : $rowclass;
}

sub _get_row {
    my ( $p, $self ) = shift->_private;
    my $row = do {
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            if ( $self->_buffer_empty ) {
                $self->_charge_buffer;
            }
            if ( $self->_buffer_empty ) {
                $p->{ fi } = 1;
                undef;
            } else {
                $p->{ rc } += 1;
                shift @{ $p->{ bu } };
            }
        }
    };
    return do {
        if ( @{ $p->{ cb } } ) {
            $self->transform( $self->_bless( $row ) );
        } else {
            $self->_bless( $row );
        }
    };
    return $row;
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
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            local ( $_ );
            while ( $self->_charge_buffer ) { ; }
            my $rowclass = $self->rowclass;
            my $rows     = do {
                if ( @{ $self->_private->{ cb } } ) {
                    [
                        map { $self->transform( $self->_bless( $_ ) ) } (
                            @{ $p->{ bu } },
                        ),
                    ];
                } else {
                    [ map { $self->_bless( $_ ) } @{ $p->{ bu } } ];
                }
            };
            $p->{ rc } = $p->{ rf };
            $p->{ bu } = undef;
            $self->reset;
            $rows;
        }
    };
    return wantarray ? @{ $_ } : $_;
}

BEGIN {
    *rc = *resultclass;
}

## use critic

1;
