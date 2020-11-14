use strict;
use warnings;

package DBIx::Squirrel::st;

BEGIN {
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
    @DBIx::Squirrel::st::ISA = ( 'DBI::st' );
}

1;
