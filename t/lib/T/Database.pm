use strict;
use warnings;

package T::Database;

use Test::Most;
use DBIx::Squirrel;
use T::Constants ':all';

BEGIN {
    require Exporter;
    @T::Database::ISA         = ( 'Exporter' );
    %T::Database::EXPORT_TAGS = (
        all => [
            @{ $T::Constants::EXPORT_TAGS{ all } },
        ]
    );
    @T::Database::EXPORT_OK = @{ $T::Database::EXPORT_TAGS{ all } };
}

sub connect {
    DBIx::Squirrel->connect( @T_DB_CONNECT_ARGS );
}

1;
