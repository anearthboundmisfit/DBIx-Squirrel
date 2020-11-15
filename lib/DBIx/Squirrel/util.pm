use strict;
use warnings;

package DBIx::Squirrel::util;

## no critic (TestingAndDebugging::ProhibitNoStrict)

BEGIN {
    require Exporter;
    @DBIx::Squirrel::util::ISA         = ( 'Exporter' );
    *DBIx::Squirrel::util::VERSION     = *DBIx::Squirrel::VERSION;
    %DBIx::Squirrel::util::EXPORT_TAGS = (
        all => [
            qw/
              Dumper
              throw
              /
        ]
    );
    @DBIx::Squirrel::util::EXPORT_OK
      = @{ $DBIx::Squirrel::util::EXPORT_TAGS{ all } };
}

use Carp;
use Data::Dumper::Concise;

sub throw {
    @_ = do {
        if ( @_ ) {
            if ( @_ > 1 ) {
                if ( my $format = shift ) {
                    sprintf( $format, @_ );
                } else {
                    join( '', map { $_ // '' } @_ );
                }
            } else {
                shift || 'Died';
            }
        } else {
            $@ || $_ || 'Died';
        }
    };
    goto &Carp::confess;
}

## use critic

1;
