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
our $DEFAULT_MAX_ROWS = 2;
our $BUF_MULT         = 2;
our $BUF_MAX_SIZE     = 64;

my %itor;

sub _dump_state {
    my $id = $_[ 0 ]->_id;
    return Dumper( { state => $itor{ $id } } );
}

sub _id {
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
    $self->_finish;
    delete $itor{ $id };
    return;
}

sub new {
    local ( $_ );
    my $self = do {
        my $package = ref $_[ 0 ] ? ref shift : shift;
        my $sth     = shift;
        if ( ref $sth && blessed( $sth ) && $sth->isa( 'DBI::st' ) ) {
            my $self = bless {}, $package;
            my $id   = 0+ $self;
            $itor{ $id } = {
                st => $sth,
                id => $id,
                bp => [ @_ ],
                sl => $self->_set_slice->{ Slice },
                mr => $self->_set_max_rows->{ MaxRows },
            };
            $sth->{ private_dbix_squirrel }{ itor } = $self;
            $self->_finish;
        } else {
            undef;
        }
    };
    return $self;
}

sub _set_slice {
    my ( $c, $self ) = shift->_context;
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

sub _context {
    my $self = $_[ 0 ];
    my $id   = 0+ $self;
    if ( wantarray ) {
        ref $self ? ( $itor{ $id }, $self, $id ) : ();
    } else {
        ref $self ? $itor{ $id } : undef;
    }
}

sub _set_max_rows {
    my ( $c, $self ) = shift->_context;
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

sub _finish {
    my ( $c, $self ) = shift->_context;
    if ( my $sth = $c->{ st } ) {
        $sth->finish if $sth->{ Active };
    }
    $c->{ ex } = undef;
    $c->{ fi } = undef;
    $c->{ bu } = undef;
    $c->{ bx } = $DEFAULT_MAX_ROWS;
    $c->{ bm } = ( $BUF_MULT >= 0 && $BUF_MULT < 9 ) ? $BUF_MULT : 0;
    $c->{ bl } = ( $BUF_MAX_SIZE > 0 ) ? $BUF_MAX_SIZE : $c->{ bx };
    $c->{ rf } = 0;
    $c->{ rc } = 0;
    return $self;
}

sub first {
    local ( $_ );
    my ( $c, $self, $id ) = shift->_context;
    $self->reset( @_ );
    return $self->_get_row;
}

sub reset {
    local ( $_ );
    my ( $c, $self, $id ) = shift->_context;
    #
    # When using the "reset" method to modify the disposition and number of
    # rows fetched at a time, we allow ($slice, $max_rows), ($max_rows, $slice),
    # either one or the other, or none. In the case of none, the only action
    # performed is to finish the statement and reset the iterator.
    #
    if ( @_ ) {
        if ( ref $_[ 0 ] ) {
            $self->_set_slice( shift );
            if ( @_ ) {
                $self->_set_max_rows( shift );
            } else {
                $self->_set_max_rows;
            }
        } else {
            $self->_set_max_rows( shift );
            if ( @_ ) {
                $self->_set_slice( shift );
            } else {
                $self->_set_slice;
            }
        }
    }
    return $self->_finish;
}

sub _get_row {
    my ( $c, $self ) = shift->_context;
    return if $c->{ fi } || ( !$c->{ ex } && !$self->execute );
    my $row = do {
        $self->_charge_buffer if $self->_buffer_empty;
        if ( $self->_buffer_empty ) {
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
    local ( $_ );
    my ( $c, $self ) = shift->_context;
    my $sth = $c->{ st };
    return unless $sth;
    my $res = do {
        if ( $c->{ ex } || $c->{ fi } ) {
            $self->reset;
        }
        if ( $sth->execute( @_ ? @_ : @{ $c->{ bp } } ) ) {
            if ( my $row_count = $self->_charge_buffer ) {
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

sub _charge_buffer {
    my ( $c, $self ) = shift->_context;
    my $sth = $c->{ st };
    return unless $sth && $sth->{ Active };
    my $res = do {
        if ( my $rows = $sth->fetchall_arrayref( $c->{ sl }, $c->{ mr } ) ) {
            if ( $c->{ bm } ) {
                my $candidate_mr = do {
                    if ( $c->{ bm } > 1 ) {
                        $c->{ bm } * $c->{ mr };
                    } else {
                        $c->{ bx } + $c->{ mr };
                    }
                };
                if ( $c->{ bl } >= $candidate_mr ) {
                    $c->{ mr } = $candidate_mr;
                }
            }
            $c->{ bu } = do {
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

sub _buffer_empty {
    my ( $c, $self ) = $_[ 0 ]->_context;
    return $c->{ bu } ? @{ $c->{ bu } } < 1 : 1;
}

sub single {
    local ( $_ );
    my $self = shift;
    my $res  = do {
        if ( my $row_count = $self->execute( @_ ) ) {
            whine 'Query returned more than one row' if $row_count > 1;
            $self->_get_row;
        } else {
            undef;
        }
    };
    # Single binds possibly override constructor binds, so be sure to
    # reset or things get unpredicable
    $self->reset;
    return $res;
}

sub find {
    local ( $_ );
    my $self = shift;
    my $res  = do {
        if ( my $row_count = $self->execute( @_ ) ) {
            $self->_get_row;
        } else {
            undef;
        }
    };
    return $res;
}

sub all {
    local ( $_ );
    my $self = shift;
    my $res  = do {
        if ( $self->execute( @_ ) ) {
            $self->remaining;
        } else {
            [];
        }
    };
    # Find binds possibly override constructor binds, so be sure to
    # reset or things get unpredicable
    $self->reset;
    return wantarray ? @{ $res } : $res;
}

sub remaining {
    local ( $_ );
    my ( $c, $self ) = shift->_context;
    return if $c->{ fi } || ( !$c->{ ex } && !$self->execute );
    while ( $self->_charge_buffer ) { ; }
    my $rows = $c->{ bu };
    $c->{ rc } = $c->{ rf };
    $c->{ bu } = undef;
    return wantarray ? @{ $rows } : $rows;
}

sub next {
    local ( $_ );
    my $self = shift;
    if ( @_ ) {
        if ( ref $_[ 0 ] ) {
            $self->_set_slice( shift );
            if ( @_ ) {
                $self->_set_max_rows( shift );
            } else {
                $self->_set_max_rows;
            }
        } else {
            $self->_set_max_rows( shift );
            if ( @_ ) {
                $self->_set_slice( shift );
            } else {
                $self->_set_slice;
            }
        }
    }
    return $self->_get_row;
}

sub reiterate {
    shift->sth->reiterate( @_ );
}

sub sth {
    shift->_context->{ st };
}

sub pending_execution {
    shift->_context->{ ex };
}

sub not_pending_execution {
    not shift->_context->{ ex };
}

sub done {
    shift->_context->{ fi };
}

sub not_done {
    not shift->_context->{ fi };
}

sub row_count {
    shift->_context->{ rc };
}

sub rows_fetched {
    shift->_context->{ rf };
}

BEGIN {
    *reit    = *reiterate;
    *iterate = *reiterate;
    *it      = *reiterate;
}

## use critic

1;
