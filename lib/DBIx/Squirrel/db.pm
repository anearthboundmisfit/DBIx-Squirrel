use strict;
use warnings;

package DBIx::Squirrel::db;

BEGIN {
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
}

use DBIx::Squirrel::st;

1;
