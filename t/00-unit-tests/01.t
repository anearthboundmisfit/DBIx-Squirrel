BEGIN {
    delete $INC{ 'FindBin.pm' };
    require FindBin;
}

use autobox::Core;
use Test::Most;
use Capture::Tiny 'capture_stdout', 'capture_stderr';
use Cwd 'realpath';
use DBIx::Squirrel::util ':all';
use DBIx::Squirrel;

use lib realpath( "$FindBin::Bin/../lib" );
use T::Database ':all';

$| = 1;

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

# What follows are some basic checks that everything seems to work in the
# prepare->execute->fetch workflow. We also want to take the opportunity to
# check that cloning database handles really works, especially when cloning
# standard DBI database handles.

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

my ( $sql, $sth, $res, $arr, $itor, $n, $stdout, $stderr, $row, @rows );

# We are testing that we can prepare and execute a statement, and get the
# expected results back.
#

diag 'test using ?-style (standard) placeholders';
$sql = << '';
  SELECT * FROM customers WHERE City = ? AND FirstName = ?

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
$sql = << '';
  SELECT * FROM customers WHERE City = ?1 AND FirstName = ?2

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
$sql = << '';
  SELECT * FROM customers WHERE City = $1 AND FirstName = $2

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
$sql = << '';
  SELECT * FROM customers WHERE City = :1 AND FirstName = :2

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
$sql = << '';
  SELECT * FROM customers WHERE City = :city AND FirstName = :name

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

diag 'test iterator';
$sql = << '';
  SELECT * FROM customers WHERE Country LIKE ?

$sth = $dbh->prepare( $sql );
isa_ok $sth, 'DBIx::Squirrel::st', 'got statement handle';

$itor = $sth->iterate( 'I%' );
is $itor->{ Slice }, $DBIx::Squirrel::it::DEFAULT_SLICE,
  'initial slice ok';
is $itor->{ MaxRows }, $DBIx::Squirrel::it::DEFAULT_MAX_ROWS,
  'initial max rows ok';

$itor->reset( { foo => 1 }, 10 );
is_deeply $itor->{ Slice }, { foo => 1 }, 'slice ok';
is $itor->{ MaxRows }, 10, 'max rows ok';

$itor->reset( 20, { foo => 2 } );
is_deeply $itor->{ Slice }, { foo => 2 }, 'slice ok';
is $itor->{ MaxRows }, 20, 'max rows ok';

$itor->reset;
is_deeply $itor->{ Slice }, { foo => 2 }, 'slice ok';
is $itor->{ MaxRows }, 20, 'max rows ok';

$itor->_set_slice->_set_max_rows;
is $itor->{ Slice }, $DBIx::Squirrel::it::DEFAULT_SLICE,
  'slice ok';
is $itor->{ MaxRows }, $DBIx::Squirrel::it::DEFAULT_MAX_ROWS,
  'max rows ok';

$itor->reset( {}, 1 );

( $exp, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->find;
    }
);
is_deeply $row, $exp, 'find ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->find;
    }
);
is_deeply $row, $exp, 'find again ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "4, Rue Milton",
        City         => "Paris",
        Company      => undef,
        Country      => "France",
        CustomerId   => 39,
        Email        => "camille.bernard\@yahoo.fr",
        Fax          => undef,
        FirstName    => "Camille",
        LastName     => "Bernard",
        Phone        => "+33 01 49 70 65 65",
        PostalCode   => 75009,
        State        => undef,
        SupportRepId => 4,
    },
    do {
        $itor->find( 'F%' );
    }
);
is_deeply $row, $exp, 'find with different params ok'
  or print "Got:\n" . Dumper( $row );

( $exp, @rows ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->find;
    }
);
is_deeply \@rows, [ $exp ], 'find ok'
  or print "Got:\n" . Dumper( \@rows );

( $exp, @rows ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->sth->find;
    }
);
is_deeply \@rows, [ $exp ], 'sth->find ok'
  or print "Got:\n" . Dumper( \@rows );

( $exp, @rows ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->find;
    }
);
is_deeply \@rows, [ $exp ], 'find again ok'
  or print "Got:\n" . Dumper( \@rows );

( $exp, @rows ) = ( {
        Address      => "4, Rue Milton",
        City         => "Paris",
        Company      => undef,
        Country      => "France",
        CustomerId   => 39,
        Email        => "camille.bernard\@yahoo.fr",
        Fax          => undef,
        FirstName    => "Camille",
        LastName     => "Bernard",
        Phone        => "+33 01 49 70 65 65",
        PostalCode   => 75009,
        State        => undef,
        SupportRepId => 4,
    },
    do {
        $itor->find( 'F%' );
    }
);
is_deeply \@rows, [ $exp ], 'find with different params ok'
  or print "Got:\n" . Dumper( \@rows );

( $exp, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->all;
    }
);
is_deeply $row, $exp, 'all ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->all;
    }
);
is_deeply $row, $exp, 'all again ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "4, Rue Milton",
        City         => "Paris",
        Company      => undef,
        Country      => "France",
        CustomerId   => 39,
        Email        => "camille.bernard\@yahoo.fr",
        Fax          => undef,
        FirstName    => "Camille",
        LastName     => "Bernard",
        Phone        => "+33 01 49 70 65 65",
        PostalCode   => 75009,
        State        => undef,
        SupportRepId => 4,
    },
    do {
        $itor->all( 'F%' );
    }
);
is_deeply $row, $exp, 'all with different params ok'
  or print "Got:\n" . Dumper( $row );

( $exp, @rows ) = ( [ {
            Address      => "3 Chatham Street",
            City         => "Dublin",
            Company      => undef,
            Country      => "Ireland",
            CustomerId   => 46,
            Email        => "hughoreilly\@apple.ie",
            Fax          => undef,
            FirstName    => "Hugh",
            LastName     => "O'Reilly",
            Phone        => "+353 01 6792424",
            PostalCode   => undef,
            State        => "Dublin",
            SupportRepId => 3,
        },
        {
            Address      => "3,Raj Bhavan Road",
            City         => "Bangalore",
            Company      => undef,
            Country      => "India",
            CustomerId   => 59,
            Email        => "puja_srivastava\@yahoo.in",
            Fax          => undef,
            FirstName    => "Puja",
            LastName     => "Srivastava",
            Phone        => "+91 080 22289999",
            PostalCode   => 560001,
            State        => undef,
            SupportRepId => 3,
        },
    ],
    do {
        $itor->all;
    }
);
is_deeply [ @rows[ 0, -1 ] ], $exp, 'all ok'
  or print "Got:\n" . Dumper( [ @rows[ 0, -1 ] ] );

( $exp, @rows ) = ( [ {
            Address      => "3 Chatham Street",
            City         => "Dublin",
            Company      => undef,
            Country      => "Ireland",
            CustomerId   => 46,
            Email        => "hughoreilly\@apple.ie",
            Fax          => undef,
            FirstName    => "Hugh",
            LastName     => "O'Reilly",
            Phone        => "+353 01 6792424",
            PostalCode   => undef,
            State        => "Dublin",
            SupportRepId => 3,
        },
        {
            Address      => "3,Raj Bhavan Road",
            City         => "Bangalore",
            Company      => undef,
            Country      => "India",
            CustomerId   => 59,
            Email        => "puja_srivastava\@yahoo.in",
            Fax          => undef,
            FirstName    => "Puja",
            LastName     => "Srivastava",
            Phone        => "+91 080 22289999",
            PostalCode   => 560001,
            State        => undef,
            SupportRepId => 3,
        },
    ],
    do {
        $itor->sth->all;
    }
);
is_deeply [ @rows[ 0, -1 ] ], $exp, 'sth->all ok'
  or print "Got:\n" . Dumper( [ @rows[ 0, -1 ] ] );

( $exp, @rows ) = ( [ {
            Address      => "3 Chatham Street",
            City         => "Dublin",
            Company      => undef,
            Country      => "Ireland",
            CustomerId   => 46,
            Email        => "hughoreilly\@apple.ie",
            Fax          => undef,
            FirstName    => "Hugh",
            LastName     => "O'Reilly",
            Phone        => "+353 01 6792424",
            PostalCode   => undef,
            State        => "Dublin",
            SupportRepId => 3,
        },
        {
            Address      => "3,Raj Bhavan Road",
            City         => "Bangalore",
            Company      => undef,
            Country      => "India",
            CustomerId   => 59,
            Email        => "puja_srivastava\@yahoo.in",
            Fax          => undef,
            FirstName    => "Puja",
            LastName     => "Srivastava",
            Phone        => "+91 080 22289999",
            PostalCode   => 560001,
            State        => undef,
            SupportRepId => 3,
        },
    ],
    do {
        $itor->all;
    }
);
is_deeply [ @rows[ 0, -1 ] ], $exp, 'all again ok'
  or print "Got:\n" . Dumper( [ @rows[ 0, -1 ] ] );

( $exp, @rows ) = ( [ {
            Address      => "4, Rue Milton",
            City         => "Paris",
            Company      => undef,
            Country      => "France",
            CustomerId   => 39,
            Email        => "camille.bernard\@yahoo.fr",
            Fax          => undef,
            FirstName    => "Camille",
            LastName     => "Bernard",
            Phone        => "+33 01 49 70 65 65",
            PostalCode   => 75009,
            State        => undef,
            SupportRepId => 4,
        },
        {
            Address      => "Porthaninkatu 9",
            City         => "Helsinki",
            Company      => undef,
            Country      => "Finland",
            CustomerId   => 44,
            Email        => "terhi.hamalainen\@apple.fi",
            Fax          => undef,
            FirstName    => "Terhi",
            LastName     => "H\x{e4}m\x{e4}l\x{e4}inen",
            Phone        => "+358 09 870 2000",
            PostalCode   => "00530",
            State        => undef,
            SupportRepId => 3,
        },
    ],
    do {
        $itor->all( 'F%' );
    }
);
is_deeply [ @rows[ 0, -1 ] ], $exp, 'all with different params ok'
  or print "Got:\n" . Dumper( [ @rows[ 0, -1 ] ] );

( $exp, $stderr, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    capture_stderr {
        $itor->reset( {}, 1 );
        $itor->single;
    },
);
is_deeply $row, $exp, 'single ok'
  or print "Got:\n" . Dumper( $row );
is $stderr, '', 'warning suppressed (1-row buffer)';

( $stderr, $row ) = (
    capture_stderr {
        $itor->reset( {}, 10 );
        $itor->single;
    },
);
is_deeply $row, $exp, 'single ok';
like $stderr, qr/Query returned more than one row/s,
  'got expected warning (n-row buffer)';

( $stderr, $row ) = (
    capture_stderr {
        $itor->reset( {}, 10 );
        $itor->sth->single;
    },
);
is_deeply $row, $exp, 'sth->single ok';
like $stderr, qr/Query returned more than one row/s,
  'got expected warning (n-row buffer)';

( $row ) = (
    do {
        $itor->reset( {}, 1 );
        $itor->first;
    }
);
is_deeply $row, $exp, 'first ok'
  or print "Got:\n" . Dumper( $row );

( $row ) = (
    do {
        $itor->reset( {}, 10 );
        $itor->first;
    }
);
is_deeply $row, $exp, 'first ok'
  or print "Got:\n" . Dumper( $row );

( $row ) = (
    do {
        $itor->sth->first;
    }
);
is_deeply $row, $exp, 'sth->first ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "3 Chatham Street",
        City         => "Dublin",
        Company      => undef,
        Country      => "Ireland",
        CustomerId   => 46,
        Email        => "hughoreilly\@apple.ie",
        Fax          => undef,
        FirstName    => "Hugh",
        LastName     => "O'Reilly",
        Phone        => "+353 01 6792424",
        PostalCode   => undef,
        State        => "Dublin",
        SupportRepId => 3,
    },
    do {
        $itor->reset( {}, 1 );
        $itor->next;
    }
);
is_deeply $row, $exp, 'next ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "Via Degli Scipioni, 43",
        City         => "Rome",
        Company      => undef,
        Country      => "Italy",
        CustomerId   => 47,
        Email        => "lucas.mancini\@yahoo.it",
        Fax          => undef,
        FirstName    => "Lucas",
        LastName     => "Mancini",
        Phone        => "+39 06 39733434",
        PostalCode   => "00192",
        State        => "RM",
        SupportRepId => 5,
    },
    do {
        $itor->next;
    }
);
is_deeply $row, $exp, 'next ok'
  or print "Got:\n" . Dumper( $row );

( $exp, $row ) = ( {
        Address      => "12,Community Centre",
        City         => "Delhi",
        Company      => undef,
        Country      => "India",
        CustomerId   => 58,
        Email        => "manoj.pareek\@rediff.com",
        Fax          => undef,
        FirstName    => "Manoj",
        LastName     => "Pareek",
        Phone        => "+91 0124 39883988",
        PostalCode   => 110017,
        State        => undef,
        SupportRepId => 3,
    },
    do {
        $itor->sth->next;
    }
);
is_deeply $row, $exp, 'sth->next ok'
  or print "Got:\n" . Dumper( $row );
$itor->reset;

$sth = $dbh->prepare( 'SELECT * FROM customers' );
while ( $row = $sth->next ) {
  print Dumper($row);
}

$dbh->disconnect;

ok 1, __FILE__ . ' complete';
done_testing;
