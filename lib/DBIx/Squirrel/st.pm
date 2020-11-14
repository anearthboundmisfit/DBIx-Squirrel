use strict;
use warnings;

package DBIx::Squirrel::st;

BEGIN {
    @DBIx::Squirrel::st::ISA     = ( 'DBI::st' );
    *DBIx::Squirrel::st::VERSION = *DBIx::Squirrel::VERSION;
}

1;
