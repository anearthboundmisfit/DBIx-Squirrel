use strict;
use warnings;

package DBIx::Squirrel::it;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    *DBIx::Squirrel::it::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::util 'throw', 'whine', 'Dumper';
use Scalar::Util 'blessed', 'reftype';

use constant {
    E_BAD_SLICE    => 'Slice must be a reference to an ARRAY or HASH',
    E_BAD_MAX_ROWS => 'Maximum row count must be an integer greater than zero',
};

our $DEFAULT_SLICE    = [];
our $DEFAULT_MAX_ROWS = 10;

my %itor;

sub _dump_state {
    my $id = $_[ 0 ]->id;
    return Dumper( { state => $itor{ $id } } );
}

sub id {
    my $self = shift;
    if ( wantarray ) {
        ref $self ? ( 0+ $self, $self ) : ();
    } else {
        ref $self ? 0+ $self : undef;
    }
}

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my $self = $_[ 0 ];
    my $id   = 0+ $_[ 0 ];
    $self->finish;
    delete $itor{ $id };
    return;
}

sub new {
    my $self = do {
        my $package = ref $_[ 0 ] ? ref shift : shift;
        my $sth     = shift;
        if ( ref $sth && blessed( $sth ) && $sth->isa( 'DBI::st' ) ) {
            my $self = bless {}, $package;
            my $id   = 0+ $self;
            $itor{ $id } = {
                it => $self,
                st => $sth,
                id => $id,
                bp => [ @_ ],
                sl => $self->set_slice->{ Slice },
                mr => $self->set_max_rows->{ MaxRows },
            };
            $self->finish;
        } else {
            undef;
        }
    };
    return $self;
}

sub set_slice {
    my ( $c, $self ) = shift->context;
    $self->{ Slice } = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
                $c->{ sl } = shift;
            } else {
                throw E_BAD_SLICE;
            }
        } else {
            $c->{ sl } = $DEFAULT_SLICE;
        }
    };
    return $self;
}

sub context {
    my $self = $_[ 0 ];
    my $id   = 0+ $self;
    if ( wantarray ) {
        ref $self ? ( $itor{ $id }, $self, $id ) : ();
    } else {
        ref $self ? $itor{ $id } : undef;
    }
}

BEGIN { *c = *context }

sub set_max_rows {
    my ( $c, $self ) = shift->context;
    $self->{ MaxRows } = do {
        if ( @_ ) {
            if ( defined $_[ 0 ] && !ref $_[ 0 ] && int $_[ 0 ] > 0 ) {
                $c->{ mr } = int shift;
            } else {
                throw E_BAD_MAX_ROWS;
            }
        } else {
            $c->{ mr } = $DEFAULT_MAX_ROWS;
        }
    };
    return $self;
}

sub finish {
    my ( $c, $self ) = shift->context;
    if ( my $sth = $c->{ st } ) {
        $sth->finish if $sth->{ Active };
    }
    $c->{ ex } = undef;
    $c->{ fi } = undef;
    $c->{ bu } = undef;
    $c->{ rf } = 0;
    $c->{ rc } = 0;
    return $self;
}

sub first {
    my ( $c, $self, $id ) = shift->context;
    $self->reset( @_ );
    return $self->_get_row;
}

sub reset {
    my ( $c, $self, $id ) = shift->context;
    #
    # When using the "reset" method to modify the disposition and number of
    # rows fetched at a time, we allow ($slice, $max_rows), ($max_rows, $slice),
    # either one or the other, or none. In the case of none, the only action
    # performed is to finish the statement and reset the iterator.
    #
    if ( @_ ) {
        if ( ref $_[ 0 ] ) {
            $self->set_slice( shift );
            if ( @_ ) {
                $self->set_max_rows( shift );
            } else {
                $self->set_max_rows;
            }
        } else {
            $self->set_max_rows( shift );
            if ( @_ ) {
                $self->set_slice( shift );
            } else {
                $self->set_slice;
            }
        }
    }
    return $self->finish;
}

sub _get_row {
    my ( $c, $self ) = shift->context;
    return if $c->{ fi } || ( !$c->{ ex } && !$self->execute );
    my $row = do {
        $self->charge_buffer unless $self->buffer_empty;
        if ( $self->buffer_empty ) {
            $c->{ fi } = 1;
            undef;
        } else {
            $c->{ rc } += 1;
            shift @{ $c->{ bu } };
        }
    };
    return $row;
}

sub execute {
    my ( $c, $self ) = shift->context;
    my $sth = $c->{ st };
    return unless $sth;
    my $res = do {
        if ( $c->{ ex } || $c->{ fi } ) {
            $self->reset;
        }
        if ( $sth->execute( @_ ? @_ : @{ $c->{ bp } } ) ) {
            if ( my $row_count = $self->charge_buffer ) {
                $c->{ ex } = 1;
                $row_count;
            } else {
                undef;
            }
        } else {
            $c->{ ex } = undef;
        }
    };
    return $res;
}

sub charge_buffer {
    my ( $c, $self ) = shift->context;
    my $sth = $c->{ st };
    return unless $sth && $sth->{ Active };
    my $res = do {
        if ( my $rows = $sth->fetchall_arrayref( $c->{ sl }, $c->{ mr } ) ) {
            $c->{ bu } = do {
                $c->{ ex } = 1 unless $c->{ ex };
                if ( $c->{ bu } ) {
                    [ @{ $c->{ bu } }, @{ $rows } ];
                } else {
                    $rows;
                }
            };
            my $count = @{ $rows };
            $c->{ rf } += $count;
            $count;
        } else {
            $c->{ fi } = 1;
            undef;
        }
    };
    return $res;
}

sub buffer_empty {
    my ( $c, $self ) = $_[ 0 ]->context;
    return $c->{ bu } ? @{ $c->{ bu } } < 1 : 1;
}

sub buffer_count {
    my ( $c, $self ) = $_[ 0 ]->context;
    return $c->{ bu } ? scalar @{ $c->{ bu } } : 0;
}

sub single {
    my $self = shift;
    my $res  = do {
        if ( my $row_count = $self->execute( @_ ) ) {
            whine 'Query returned more than one row' if $row_count > 1;
            $self->_get_row;
        } else {
            undef;
        }
    };
    return $res;
}

sub all {
    my $self = shift;
    $self->reset( @_ );
    return $self->remaining;
}

sub remaining {
    my ( $c, $self ) = shift->context;
    return if $c->{ fi } || ( !$c->{ ex } && !$self->execute );
    while ( $self->charge_buffer ) { ; }
    my $rows = $c->{ bu };
    $c->{ rc } = $c->{ rf };
    $c->{ bu } = undef;
    return wantarray ? @{ $rows } : $rows;
}

sub next { $_[ 0 ]->_get_row }

sub sth { $_[ 0 ]->c->{ st } }

sub pending_execution { $_[ 0 ]->c->{ ex } }

sub not_pending_execution { not $_[ 0 ]->c->{ ex } }

sub done { $_[ 0 ]->c->{ fi } }

sub not_done { not $_[ 0 ]->c->{ fi } }

sub rows_count { $_[0]->c->{ rc } }

sub rows_fetched { $_[0]->c->{ rf } }

BEGIN {
    *executed = *not_pending_execution;
    *finished = *done;
    *more     = *not_done;
}

## use critic

1;
