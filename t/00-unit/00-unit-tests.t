BEGIN {
    delete $INC{ 'FindBin.pm' };
    require FindBin;
}

use autobox::Core;
use Test::Most;
use Cwd 'realpath';
use DBIx::Squirrel::util ':all';
use DBIx::Squirrel;

use lib realpath( "$FindBin::Bin/../lib" );
use T::Constants ':all';

# Create to references to a cached DBIx::Squirrel database connection.
#
# Since the connection is cached, both references must point to the same
# connection object.

my $cached_ekorn_dbh_1 = DBIx::Squirrel->connect_cached( @T_DB_CONNECT_ARGS );
isa_ok $cached_ekorn_dbh_1, 'DBIx::Squirrel::db',
  'cached DBIx::Squirrel::db 1';

my $cached_ekorn_dbh_2 = DBIx::Squirrel->connect_cached( @T_DB_CONNECT_ARGS );
isa_ok $cached_ekorn_dbh_2, 'DBIx::Squirrel::db',
  'cached DBIx::Squirrel::db 2';

is $cached_ekorn_dbh_2, $cached_ekorn_dbh_1,
  'cached DBIx::Squirrel::db objects 1 and 2 are the same';

# Create a standard DBI master connection.
#
# We want to check that DBIx::Squirrel can create new connections based upon
# a master connection instantiated using the standard DBI::db archetype.

my $dbi_dbh = DBI->connect( @T_DB_CONNECT_ARGS );
isa_ok $dbi_dbh, 'DBI::db', 'standard DBI::db master';

# Open two more connections by cloning the master and re-blessing the new
# connections appropriately.

my $cloned_dbi_dbh_1 = DBIx::Squirrel->connect_cloned( $dbi_dbh );
isa_ok $cloned_dbi_dbh_1, 'DBIx::Squirrel::db',
  'first DBIx::Squirrel::db clone created';

# We can also use the "connect" method by passing a database handle.

my $cloned_dbi_dbh_2 = DBIx::Squirrel->connect( $dbi_dbh );
isa_ok $cloned_dbi_dbh_2, 'DBIx::Squirrel::db',
  'second DBIx::Squirrel::db clone created';

# All three connections must be different objects.

ok $cloned_dbi_dbh_1 != $dbi_dbh,
  'first clone differs from master';
ok $cloned_dbi_dbh_2 != $cloned_dbi_dbh_1,
  'second clone differs from first';

# Create a DBIx::Squirrel master database connection.
#
# We want to check that DBIx::Squirrel can create new connections based upon
# a master connection instantiated using the DBIx::Squirrel::db archetype.

my $ekorn_dbh = DBIx::Squirrel->connect( @T_DB_CONNECT_ARGS );
isa_ok $ekorn_dbh, 'DBIx::Squirrel::db';

# Open two more connections by cloning the master and re-blessing the new
# connections appropriately.

my $cloned_ekorn_dbh_1 = DBIx::Squirrel->connect_cloned( $ekorn_dbh );
isa_ok $cloned_ekorn_dbh_1, 'DBIx::Squirrel::db',
  'first DBIx::Squirrel::db clone created';

my $cloned_ekorn_dbh_2 = DBIx::Squirrel->connect( $ekorn_dbh );
isa_ok $cloned_ekorn_dbh_2, 'DBIx::Squirrel::db',
  'second DBIx::Squirrel::db clone created';

# All three connections must be different objects.

ok $cloned_ekorn_dbh_1 != $ekorn_dbh,
  'first clone differs from master';
ok $cloned_ekorn_dbh_2 != $cloned_ekorn_dbh_1,
  'second clone differs from first';

my $sth = $ekorn_dbh->prepare('select * from customers where City = ?');
isa_ok $sth, 'DBIx::Squirrel::st';

my $res = $sth->execute('Delhi');
ok $res;

my $arr = $sth->fetchall_arrayref({});
ok $arr;
is $arr->length, 1;
is $arr->[0]{CustomerId}, 58;
explain $arr;

$ekorn_dbh->disconnect;

ok 1, __FILE__ . ' complete';
done_testing;
