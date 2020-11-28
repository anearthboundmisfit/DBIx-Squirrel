use strict;
use warnings;

package DBIx::Squirrel::ResultClass;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    *DBIx::Squirrel::ResultClass::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'reftype';
use Sub::Name 'subname';
use DBIx::Squirrel::util 'throw';

our $AUTOLOAD;

sub new { bless $_[ 1 ], ref $_[ 0 ] || $_[ 0 ] }

sub resultclass { $_[ 0 ]->resultset->resultclass }

sub rowclass { $_[ 0 ]->resultset->rowclass }

sub AUTOLOAD {
    ( my $name = $AUTOLOAD ) =~ s/.*:://;
    return if $name eq 'DESTROY';
    my ( $self, $class ) = ( $_[ 0 ], ref $_[ 0 ] );
    my $closure = do {
        if ( reftype( $self ) eq 'ARRAY' ) {
            my $sth   = $self->resultset->sth;
            my $index = $sth->{ NAME_lc_hash }{ lc $name };
            unless ( defined $index ) {
                throw 'Unrecognised column name (%s)', $name;
            }
            sub { shift->[ $index ] };
        } elsif ( reftype( $self ) eq 'HASH' ) {
            if ( exists $self->{ $name } ) {
                sub { shift->{ $name } };
            } else {
                local ( $_ );
                my ( $index ) = grep { $name eq lc } keys %{ $self };
                unless ( defined $index ) {
                    throw 'Unrecognised column name (%s)', $name;
                }
                sub { shift->{ $index } };
            }
        } else {
            throw 'Object is not a blessed array or hash reference';
        }
    };
    no strict 'refs';
    my $symbol = "$class\::$name";
    *{ $symbol } = subname( $symbol, $closure );
    goto &{ $closure };
}

## use critic

1;
