use strict;
use warnings;

package DBIx::Squirrel::it;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    *DBIx::Squirrel::it::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBIx::Squirrel::util 'throw', 'Dumper';
use Scalar::Util 'blessed',       'reftype';

use constant {
    E_BAD_SLICE    => 'Slice must be a reference to an ARRAY or HASH',
    E_BAD_MAX_ROWS => 'Maximum row count must be an integer greater than zero',
};

use constant {
    DEFAULT_SLICE    => [],
    DEFAULT_MAX_ROWS => 1,
};

my %itor;

sub _dump_state {
    my ( $id, $self ) = shift->id;
    return Dumper( { state => $itor{ $id } } );
}

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $c, $self, $id ) = shift->context;
    if ( $c ) {
        $self->finish;
        delete $itor{ $id };
    }
    return;
}

sub context {
    my $self = shift;
    my $id   = 0+ $self;
    if ( wantarray ) {
        ref $self ? ( $itor{ $id }, $self, $id ) : ();
    } else {
        ref $self ? $itor{ $id } : undef;
    }
}

BEGIN { *c = *context }

sub id {
    my $self = shift;
    if ( wantarray ) {
        ref $self ? ( 0+ $self, $self ) : ();
    } else {
        ref $self ? 0+ $self : undef;
    }
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
                ex => undef,
                fi => undef,
                bu => undef,
            };
            $self;
        } else {
            undef;
        }
    };
    return $self;
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

sub set_slice {
    my ( $c, $self, $id ) = shift->context;
    $self->{ Slice } = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
                $c->{ sl } = shift;
            } else {
                throw E_BAD_SLICE;
            }
        } else {
            $c->{ sl } = DEFAULT_SLICE;
        }
    };
    return $self;
}

sub set_max_rows {
    my ( $c, $self, $id ) = shift->context;
    $self->{ MaxRows } = do {
        if ( @_ ) {
            if ( defined $_[ 0 ] && !ref $_[ 0 ] && int $_[ 0 ] > 0 ) {
                $c->{ mr } = int shift;
            } else {
                throw E_BAD_MAX_ROWS;
            }
        } else {
            $c->{ mr } = DEFAULT_MAX_ROWS;
        }
    };
    return $self;
}

sub finish {
    my ( $c, $self ) = shift->context;
    if ( my $sth = $c->{ st } ) {
        $sth->finish if $sth->{ Active };
    }
    undef $c->{ ex };
    undef $c->{ fi };
    return $self;
}

sub single {
    my ( $c, $self, $id ) = shift->context;
    my $res = $self->execute( @_ );
    return;
}

sub execute {
    my ( $c, $self, $id ) = shift->context;
    if ( $c->{ ex } || $c->{ fi } ) {
        $self->reset;
    }
    my $res = do {
        if ( @_ ) {
            $self->sth->execute( @_ );
        } else {
            $self->sth->execute( @{ $c->{ bp } } );
        }
    };
    if ( $res ) {
        $c->{ ex } = 1;
        $c->{ bu } = $self->sth->fetchall_arrayref( $c->{ sl }, $c->{ mr } );
    } else {
        $c->{ ex } = 0;
    }
    return $res;
}

sub sth { shift->c->{ st } }

sub next {
    my ( $c, $self, $id ) = shift->context;
    return;
}

sub more {
    my ( $c, $self, $id ) = shift->context;
    return;
}

sub first {
    my ( $c, $self, $id ) = shift->context;
    my $res = $self->reset( @_ )->execute;
    return;
}

sub all {
    my ( $c, $self, $id ) = shift->context;
    my $res = $self->reset( @_ )->execute;
    return;
}

## use critic

1;
