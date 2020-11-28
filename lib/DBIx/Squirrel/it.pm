use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::it;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    *DBIx::Squirrel::it::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::ResultSet;
use DBIx::Squirrel::util 'throw', 'whine', 'Dumper';
use Scalar::Util 'blessed', 'reftype';

use constant {
    E_BAD_SLICE    => 'Slice must be a reference to an ARRAY or HASH',
    E_BAD_MAX_ROWS => 'Maximum row count must be an integer greater than zero',
};

our $DEFAULT_SLICE    = [];
our $DEFAULT_MAX_ROWS = 10;
our $BUF_MULTIPLIER   = 1;
our $BUF_MAX_SIZE     = 64;

my %itor;

sub _dump_state {
    my $id = $_[ 0 ]->_id;
    return Dumper( { state => $itor{ $id } } );
}

sub _id {
    my $self = $_[ 0 ];
    return do {
        if ( wantarray ) {
            ref $self ? ( 0+ $self, $self ) : ();
        } else {
            ref $self ? 0+ $self : undef;
        }
    };
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
    $_ = do {
        my @cb;
        while ( ref $_[ -1 ] && reftype( $_[ -1 ] ) eq 'CODE' ) {
            unshift @cb, pop;
        }
        my $class = ref $_[ 0 ] ? ref shift : shift;
        my $sth   = shift;
        if ( ref $sth && blessed( $sth ) && $sth->isa( 'DBI::st' ) ) {
            my $self = bless {}, $class;
            my $id   = 0+ $self;
            $itor{ $id } = {
                st => $sth,
                id => $id,
                bp => \@_,
                cb => \@cb,
                sl => $self->_set_slice->{ Slice },
                mr => $self->_set_max_rows->{ MaxRows },
            };
            $sth->_private->{ itor } = $self;
            $self->_finish;
        } else {
            undef;
        }
    };
    return $_;
}

sub _set_slice {
    my ( $p, $self ) = shift->_private;
    $self->{ Slice } = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
                $p->{ sl } = shift;
            } else {
                throw E_BAD_SLICE;
            }
        } else {
            $p->{ sl } = $DEFAULT_SLICE;
        }
    };
    return $self;
}

sub _private {
    my $self = shift;
    return do {
        if ( ref $self ) {
            my $id = 0+ $self;
            unless ( $itor{ $id } ) {
                $itor{ $id } = {};
            }
            if ( @_ ) {
                $itor{ $id } = {
                    %{ $itor{ $id } },
                    do {
                        if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) eq 'HASH' ) {
                            %{ $_[ 0 ] };
                        } else {
                            @_;
                        }
                    },
                };
            }
            if ( wantarray ) {
                ( $itor{ $id }, $self, $id );
            } else {
                $itor{ $id };
            }
        } else {
            wantarray ? () : undef;
        }
    };
}

sub _set_max_rows {
    my ( $p, $self ) = shift->_private;
    $self->{ MaxRows } = do {
        if ( @_ ) {
            if ( defined $_[ 0 ] && !ref $_[ 0 ] && int $_[ 0 ] > 0 ) {
                $p->{ mr } = int shift;
            } else {
                throw E_BAD_MAX_ROWS;
            }
        } else {
            $p->{ mr } = $DEFAULT_MAX_ROWS;
        }
    };
    return $self;
}

sub _finish {
    my ( $p, $self ) = shift->_private;
    if ( my $sth = $p->{ st } ) {
        $sth->finish if $sth->{ Active };
    }
    $p->{ ex } = undef;
    $p->{ fi } = undef;
    $p->{ bu } = undef;
    $p->{ bx } = $DEFAULT_MAX_ROWS;
    $p->{ bm } = do {
        if ( $BUF_MULTIPLIER >= 0 && $BUF_MULTIPLIER < 11 ) {
            $BUF_MULTIPLIER;
        } else {
            0;
        }
    };
    $p->{ bl } = do {
        if ( $BUF_MAX_SIZE > 0 ) {
            $BUF_MAX_SIZE;
        } else {
            $p->{ bx };
        }
    };
    $p->{ rf } = 0;
    $p->{ rc } = 0;
    return $self;
}

sub first {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( @_ || $p->{ ex } || $p->{ st }->{ Active } ) {
            $self->reset( @_ );
        }
        $self->_get_row;
    };
    return $_;
}

sub reset {
    my ( $p, $self ) = shift->_private;
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
    my ( $p, $self ) = shift->_private;
    my $row = do {
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            $self->_charge_buffer if $self->_buffer_empty;
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
            $self->transform( $row );
        } else {
            $row;
        }
    };
}

sub execute {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( my $sth = $p->{ st } ) {
            if ( $p->{ ex } || $p->{ fi } ) {
                $self->reset;
            }
            if ( $sth->execute( @_ ? @_ : @{ $p->{ bp } } ) ) {
                $p->{ ex } = 1;
                if ( $sth->{ NUM_OF_FIELDS } ) {
                    my $count = $self->_charge_buffer;
                    $p->{ fi } = $count ? 0 : 1;
                    $count;
                } else {
                    $p->{ fi } = 1;
                    0;
                }
            } else {
                $p->{ ex } = undef;
            }
        } else {
            undef;
        }
    };
    return $_;
}

sub _charge_buffer {
    my $p   = $_[ 0 ]->_private;
    my $sth = $p->{ st };
    return unless $sth && $sth->{ Active };
    my $res = do {
        if ( my $rows = $sth->fetchall_arrayref( $p->{ sl }, $p->{ mr } ) ) {
            if ( $p->{ bm } ) {
                my $candidate_mr = do {
                    if ( $p->{ bm } > 1 ) {
                        $p->{ bm } * $p->{ mr };
                    } else {
                        $p->{ bx } + $p->{ mr };
                    }
                };
                if ( $p->{ bl } >= $candidate_mr ) {
                    $p->{ mr } = $candidate_mr;
                }
            }
            $p->{ bu } = do {
                if ( $p->{ bu } ) {
                    [ @{ $p->{ bu } }, @{ $rows } ];
                } else {
                    $rows;
                }
            };
            $p->{ rf } += @{ $rows };
        } else {
            $p->{ fi } = 1;
            undef;
        }
    };
    return $res;
}

sub _buffer_empty {
    my $p = $_[ 0 ]->_private;
    return do {
        if ( $p->{ bu } ) {
            1 if @{ $p->{ bu } } < 1;
        } else {
            1;
        }
    };
}

sub transform {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( defined $_[ 0 ] ) {
            local ( $_ );
            my $row = $_[ 0 ];
            for my $cb ( @{ $p->{ cb } } ) {
                $row = $cb->( $_ = $row );
            }
            $row;
        } else {
            undef;
        }
    };
    return $_;
}

sub single {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        my $res = do {
            if ( my $row_count = $self->execute( @_ ) ) {
                if ( $row_count > 1 ) {
                    whine 'Query returned more than one row';
                }
                $self->_get_row;
            } else {
                undef;
            }
        };
        $self->reset;
        $res;
    };
    return $_;
}

sub find {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        my $res = do {
            if ( my $row_count = $self->execute( @_ ) ) {
                $self->_get_row;
            } else {
                undef;
            }
        };
        $self->reset;
        $res;
    };
    return $_;
}

sub count {
    return scalar @{ scalar shift->all( @_ ) };
}

sub all {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        my $res = do {
            if ( $self->execute( @_ ) ) {
                $self->remaining;
            } else {
                [];
            }
        };
        $self->reset;
        $res;
    };
    return wantarray ? @{ $_ } : $_;
}

sub remaining {
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            local ( $_ );
            while ( $self->_charge_buffer ) { ; }
            my $rows = do {
                if ( @{ $self->_private->{ cb } } ) {
                    [ map { $self->transform( $_ ) } @{ $p->{ bu } } ];
                } else {
                    $p->{ bu };
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

sub next {
    my $self = shift;
    $_ = do {
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
        $self->_get_row;
    };
    return $_;
}

sub reiterate {
    shift->sth->reiterate( @_ );
}

sub resultset {
    shift->sth->resultset( @_ );
}

sub sth {
    shift->_private->{ st };
}

sub pending_execution {
    shift->_private->{ ex };
}

sub not_pending_execution {
    not shift->_private->{ ex };
}

sub done {
    shift->_private->{ fi };
}

sub not_done {
    not shift->_private->{ fi };
}

BEGIN {
    *resultset = *resultset;
    *rs        = *resultset;
    *reit      = *reiterate;
    *iterate   = *reiterate;
    *it        = *reiterate;
}

## use critic

1;
