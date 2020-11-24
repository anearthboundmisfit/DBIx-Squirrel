use strict;
use warnings;

package DBIx::Squirrel::Result;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    *DBIx::Squirrel::Result::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'reftype';
use DBIx::Squirrel::util 'throw';

our $AUTOLOAD;

sub AUTOLOAD {
    local ( $_ );
    ( my $name = $AUTOLOAD ) =~ s/.*:://;
    return if $name eq 'DESTROY';
    my $self    = $_[ 0 ];
    my $class   = ref $self;
    my $closure = do {
        if ( reftype( $self ) eq 'ARRAY' ) {
            my $sth   = $self->_rs->sth;
            my $index = $sth->{ NAME_lc_hash }{ lc $name };
            if ( defined $index ) {
                sub { shift->[ $index ] };
            } else {
                undef;
            }
        } elsif ( reftype( $self ) eq 'HASH' ) {
            if ( exists $self->{ $name } ) {
                sub { shift->{ $name } };
            } else {
                my ( $index ) = grep { $name eq lc $_ } keys %{ $self };
                if ( defined $index ) {
                    sub { shift->{ $index } };
                } else {
                    undef;
                }
            }
        } else {
            throw 'Object is not a blessed array or hash reference';
        }
    };
    if ( $closure ) {
        no strict 'refs';
        *{ $class . '::' . $name } = $closure;
    } else {
        throw 'Unrecognised column name (%s)', $name;
    }
    goto &{ $closure };
}


## use critic

1;
