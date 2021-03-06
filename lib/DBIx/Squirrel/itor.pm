use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::itor;

BEGIN {
    *DBIx::Squirrel::itor::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'blessed', 'reftype';
use DBIx::Squirrel::util 'throw', 'whine', 'Dumper';

use constant {
    E_BAD_SLICE    => 'Slice must be a reference to an ARRAY or HASH',
    E_BAD_MAX_ROWS => 'Maximum row count must be an integer greater than zero',
};

our $DEFAULT_SLICE    = [];
our $DEFAULT_MAX_ROWS = 10;
our $BUF_MULTIPLIER   = 1;
our $BUF_MAX_SIZE     = 64;

my %itor;

sub _dump_state
{
    if ( my $id = $_[ 0 ]->_id ) {
        Dumper( $itor{ $id } );
    } else {
        '';
    }
}

sub _id
{
    if ( wantarray ) {
        ref $_[ 0 ] ? ( 0+ $_[ 0 ], $_[ 0 ] ) : ();
    } else {
        ref $_[ 0 ] ? 0+ $_[ 0 ] : undef;
    }
}

sub DESTROY
{
    if ( ${^GLOBAL_PHASE} ne 'DESTRUCT' ) {
        local ( $., $@, $!, $^E, $?, $_ );
        my $self = $_[ 0 ];
        my $id   = 0+ $_[ 0 ];
        $self->_finish;
        delete $itor{ $id };
    }
    return;
}

sub new
{
    $_ = do {
        my @cb;
        unshift @cb, pop while ref $_[ -1 ] && reftype( $_[ -1 ] ) eq 'CODE';
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
}

sub _set_slice
{
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
    $self;
}

sub _private
{
    my $self = shift;
    if ( ref $self ) {
        my $id      = 0+ $self;
        my $private = do {
            if ( $itor{ $id } ) {
                $itor{ $id };
            } else {
                $itor{ $id } = {};
            }
        };
        if ( @_ ) {
            $private = $itor{ $id } = {
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
        wantarray ? ( $private, $self, $id ) : $private;
    } else {
        wantarray ? () : undef;
    }
}

sub _set_max_rows
{
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
    $self;
}

sub _finish
{
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
    $self;
}

sub first
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
        if ( @_ || $p->{ ex } || $p->{ st }->{ Active } ) {
            $self->reset( @_ );
        }
        $self->_get_row;
    };
}

sub reset
{
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
    $self->_finish;
}

sub _get_row
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            $self->charge_buffer if $self->buffer_is_empty;
            if ( $self->buffer_is_still_empty ) {
                $p->{ fi } = 1;
                undef;
            } else {
                $p->{ rc } += 1;
                if ( $self->has_callbacks ) {
                    $self->transform( shift @{ $p->{ bu } } );
                } else {
                    shift @{ $p->{ bu } };
                }
            }
        }
    };
}

sub has_callbacks { scalar @{ $_[ 0 ]->_private->{ cb } } }

sub execute
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
        if ( my $sth = $p->{ st } ) {
            if ( $p->{ ex } || $p->{ fi } ) {
                $self->reset;
            }
            if ( $sth->execute( @_ ? @_ : @{ $p->{ bp } } ) ) {
                $p->{ ex } = 1;
                if ( $sth->{ NUM_OF_FIELDS } ) {
                    my $count = $self->charge_buffer;
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
}

sub charge_buffer
{
    $_ = do {
        my $p   = $_[ 0 ]->_private;
        my $sth = $p->{ st };
        if ( $sth && $sth->{ Active } ) {
            my $rows = $sth->fetchall_arrayref( $p->{ sl }, $p->{ mr } );
            if ( $rows ) {
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
                if ( $p->{ bu } ) {
                    push @{ $p->{ bu } }, @{ $rows };
                } else {
                    $p->{ bu } = $rows;
                }
                $p->{ rf } += @{ $rows };
            } else {
                $p->{ fi } = 1;
                0;
            }
        } else {
            undef;
        }
    };
}

sub buffer_is_empty
{
    if ( my $buffer = $_[ 0 ]->_private->{ bu } ) {
        @{ $buffer } ? 0 : 1;
    } else {
        1;
    }
}

BEGIN { *buffer_is_still_empty = *buffer_is_empty }

sub transform
{
    my ( $p, $self ) = shift->_private;
    if ( @_ ) {
        local ( $_ );
        my @r = @_;
        for my $cb ( @{ $p->{ cb } } ) {
            @r = $cb->(
                do {
                    $_ = $r[ 0 ];
                    @r;
                }
            );
        }
        ( @r == 1 ) ? $r[ 0 ] : @r;
    } else {
        ();
    }
}

sub single
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
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
}

sub find
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
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
}

sub all
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
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
    wantarray ? @{ $_ } : $_;
}

sub remaining
{
    $_ = do {
        my ( $p, $self ) = shift->_private;
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            while ( $self->charge_buffer ) { ; }
            my $rows = do {
                if ( $self->has_callbacks ) {
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
    wantarray ? @{ $_ } : $_;
}

sub next
{
    $_ = do {
        my $self = $_[ 0 ];
        if ( @_ > 1 ) {
            if ( ref $_[ 1 ] ) {
                $self->_set_slice( $_[ 1 ] );
                if ( @_ > 2 ) {
                    $self->_set_max_rows( $_[ 2 ] );
                } else {
                    $self->_set_max_rows;
                }
            } else {
                $self->_set_max_rows( $_[ 1 ] );
                if ( @_ > 2 ) {
                    $self->_set_slice( $_[ 2 ] );
                } else {
                    $self->_set_slice;
                }
            }
        }
        $self->_get_row;
    };
}

sub count { scalar @{ scalar shift->all( @_ ) } }

sub results { shift->sth->results( @_ ) }

BEGIN { *result_set = *results }

BEGIN { *rs = *results }

sub sth { $_[ 0 ]->_private->{ st } }

sub pending_execution { $_[ 0 ]->_private->{ ex } }

sub not_pending_execution { not $_[ 0 ]->_private->{ ex } }

sub done { $_[ 0 ]->_private->{ fi } }

sub not_done { not $_[ 0 ]->_private->{ fi } }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::itor - DBIx-Squirrel iterator base class

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
