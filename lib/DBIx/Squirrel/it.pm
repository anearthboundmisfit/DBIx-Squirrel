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
    DEFAULT_SLICE    => [],
    DEFAULT_MAX_ROWS => 1,
};

use constant {
    E_BAD_SLICE    => 'Slice must be a reference to an ARRAY or HASH',
    E_BAD_MAX_ROWS => 'Maximum row count must be an integer greater than zero',
};

my %itor;

sub _dump_state {
    my ( $id, $self ) = shift->id;
    return Dumper( {
            id    => $id,
            state => $itor{ $id }
        }
    );
}

sub DESTROY {
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $id, $self ) = shift->id;
    if ( my $c = $itor{ $id } ) {
        $self->finish;
        delete $itor{ $id };
    }
    return;
}

sub id {
    if ( wantarray ) {
        ref $_[ 0 ] ? ( 0+ $_[ 0 ], $_[ 0 ] ) : ();
    } else {
        ref $_[ 0 ] ? 0+ $_[ 0 ] : undef;
    }
}

sub new {
    my $self = do {
        my $package = ref $_[ 0 ] ? ref shift : shift;
        my $sth     = shift;
        if ( ref $sth && blessed( $sth ) && $sth->isa( 'DBI::st' ) ) {
            my ( $id, $self ) = bless( {}, $package )->id;
            $itor{ $id } = {
                it => $self,
                st => $sth,
                bp => [ @_ ],
                sl => [],
                mr => 1,
                ex => 0,
                fi => 0,
            };
            $self;
        } else {
            undef;
        }
    };
    return $self;
}

sub reset {
    my ( $id, $self ) = shift->id;
    #
    # We allow ($slice, $max_rows), ($max_rows, $slice), one or the other, or
    # none when using reset to modify the disposition and number of rows in
    # fetches.
    #
    if ( @_ && ref( $_[ 0 ] ) && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
        $self->set_slice( shift );
        if ( @_ && defined( $_[ 0 ] ) && !ref( $_[ 0 ] ) ) {
            $self->set_max_rows( shift );
        }
    } elsif ( @_ && defined( $_[ 0 ] ) && !ref( $_[ 0 ] ) ) {
        $self->set_max_rows( shift );
        if ( @_ && ref( $_[ 0 ] ) && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
            $self->set_slice( shift );
        }
    }
    return $self->finish;
}

sub set_slice {
    my ( $id, $self ) = shift->id;
    if ( @_ && ref( $_[ 0 ] ) && reftype( $_[ 0 ] ) =~ m/^ARRAY|HASH$/ ) {
        $itor{ $id }{ sl } = $_[ 0 ];
    } else {
        throw E_BAD_SLICE;
    }
    return $self;
}

sub set_max_rows {
    my ( $id, $self ) = shift->id;
    if ( @_ && defined( $_[ 0 ] ) && !ref( $_[ 0 ] ) && int( 0+ $_[ 0 ] ) > 0 )
    {
        $itor{ $id }{ mr } = int( 0+ $_[ 0 ] );
    } else {
        throw E_BAD_MAX_ROWS;
    }
    return $self;
}

sub finish {
    my ( $id, $self ) = shift->id;
    if ( $self->sth->{ Active } ) {
        $self->sth->finish;
    }
    @{ $itor{ $id } }{ qw/ex fi/ } = ( 0, 0 );
    return $self;
}

sub sth { $itor{ $_[ 0 ]->id }{ st } }

sub reset_slice {
    my ( $id, $self ) = shift->id;
    $itor{ $id }{ sl } = DEFAULT_SLICE;
    return $self;
}

sub reset_max_rows {
    my ( $id, $self ) = shift->id;
    $itor{ $id }{ mr } = DEFAULT_MAX_ROWS;
    return $self;
}

sub next {
    my ( $id, $self ) = shift->id;
}

## use critic

1;
