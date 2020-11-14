use strict;
use warnings;

package DBIx::Squirrel::db;

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use DBIx::Squirrel::st;

1;
