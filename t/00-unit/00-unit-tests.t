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
use T::Database ':all';

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

$cached_ekorn_dbh_1->disconnect;
$cached_ekorn_dbh_2->disconnect;

# Create a standard DBI master connection.
#
# We want to check that DBIx::Squirrel can create new connections based upon
# a master connection instantiated using the standard DBI::db archetype.

my $dbi_dbh = DBI->connect( @T_DB_CONNECT_ARGS );
isa_ok $dbi_dbh, 'DBI::db', 'standard DBI::db master';

# Open two more connections by cloning the master and re-blessing the new
# connections appropriately.

my $cloned_dbi_dbh_1 = DBIx::Squirrel->connect_clone( $dbi_dbh );
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

$cloned_dbi_dbh_1->disconnect;
$cloned_dbi_dbh_2->disconnect;
$dbi_dbh->disconnect;

# Create a DBIx::Squirrel master database connection.
#
# We want to check that DBIx::Squirrel can create new connections based upon
# a master connection instantiated using the DBIx::Squirrel::db archetype.

my $ekorn_dbh = DBIx::Squirrel->connect( @T_DB_CONNECT_ARGS );
isa_ok $ekorn_dbh, 'DBIx::Squirrel::db';

# Open two more connections by cloning the master and re-blessing the new
# connections appropriately.

my $cloned_ekorn_dbh_1 = DBIx::Squirrel->connect_clone( $ekorn_dbh );
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

$cloned_ekorn_dbh_1->disconnect;
$cloned_ekorn_dbh_2->disconnect;
$ekorn_dbh->disconnect;

no strict 'refs';

my $master = DBI->connect( @T_DB_CONNECT_ARGS );
my $dbh    = DBIx::Squirrel->connect( $master );
my $exp    = [ {
        Address      => '12,Community Centre',
        City         => 'Delhi',
        Company      => undef,
        Country      => 'India',
        CustomerId   => 58,
        Email        => 'manoj.pareek@rediff.com',
        Fax          => undef,
        FirstName    => 'Manoj',
        LastName     => 'Pareek',
        Phone        => '+91 0124 39883988',
        PostalCode   => '110017',
        State        => undef,
        SupportRepId => 3
    }
];

my ( $sql, $sth, $res, $arr );

# We are testing that we can prepare and execute a statement, and get the
# expected results back.
#

diag 'test using ?-style (standard) placeholders';
$sql = q/SELECT * FROM customers WHERE City = ? AND FirstName = ?/;
$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';
$res = $sth->execute( 'Delhi', 'Manoj' );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with [...] parameter lists

$res = $sth->execute( [ 'Delhi', 'Manoj' ] );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

diag 'test using ?n-style (SQLite) placeholders';
$sql = q/SELECT * FROM customers WHERE City = ?1 AND FirstName = ?2/;
$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';
$res = $sth->execute( 'Delhi', 'Manoj' );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with [...] parameter lists

$res = $sth->execute( [ 'Delhi', 'Manoj' ] );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

diag 'test using $n-style (PostgreSQL) placeholders';
$sql = q/SELECT * FROM customers WHERE City = $1 AND FirstName = $2/;
$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';
$res = $sth->execute( 'Delhi', 'Manoj' );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with [...] parameter lists

$res = $sth->execute( [ 'Delhi', 'Manoj' ] );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

diag 'test using :n-style (Oracle) placeholders';
$sql = q/SELECT * FROM customers WHERE City = :1 AND FirstName = :2/;
$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';
$res = $sth->execute( 'Delhi', 'Manoj' );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with [...] parameter lists

$res = $sth->execute( [ 'Delhi', 'Manoj' ] );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

diag 'test using :name-style (Oracle) placeholders';
$sql = q/SELECT * FROM customers WHERE City = :city AND FirstName = :name/;
$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';
$res = $sth->execute( city => 'Delhi', name => 'Manoj' );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with [...] parameter lists

$res = $sth->execute( [ city => 'Delhi', name => 'Manoj' ] );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

# Again with {...} parameter lists

$res = $sth->execute( { city => 'Delhi', name => 'Manoj' } );
is $res, '0E0', 'got valid result';
$arr = $sth->fetchall_arrayref( {} );
is_deeply $arr, $exp, 'got expected result';

$dbh->disconnect;

ok 1, __FILE__ . ' complete';
done_testing;
