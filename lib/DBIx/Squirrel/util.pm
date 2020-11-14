use strict;
use warnings;

package DBIx::Squirrel::util;

BEGIN {
    require Exporter;
    @DBIx::Squirrel::util::ISA         = ( 'Exporter' );
    *DBIx::Squirrel::util::VERSION     = *DBIx::Squirrel::VERSION;
    %DBIx::Squirrel::util::EXPORT_TAGS = ( all => [ qw// ] );
    @DBIx::Squirrel::util::EXPORT_OK
      = @{ $DBIx::Squirrel::util::EXPORT_TAGS{ all } };
}

1;