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

my ( $standard_dbi_dbh, $standard_ekorn_dbh, $cached_ekorn_dbh ) = (
    DBI->connect( @T_DB_CONNECT_ARGS ),
    DBIx::Squirrel->connect( @T_DB_CONNECT_ARGS ),
    DBIx::Squirrel->connect_cached( @T_DB_CONNECT_ARGS ),
);

isa_ok $standard_dbi_dbh,   'DBI::db';
isa_ok $standard_ekorn_dbh, 'DBIx::Squirrel::db';
isa_ok $cached_ekorn_dbh,   'DBIx::Squirrel::db';

test_clone_connection( $_ ) foreach (
    [ $standard_dbi_dbh,   'standard DBI connection' ],
    [ $standard_ekorn_dbh, 'standard DBIx::Squirrel connection' ],
    [ $cached_ekorn_dbh,   'cached DBIx::Squirrel connection' ],
);

ok 1, __FILE__ . ' complete';
done_testing;

sub test_clone_connection {
    my ($master, $description) = @{+shift};

    diag "";
    diag "Test connection cloned from a $description";
    diag "";

    my $clone  = DBIx::Squirrel->connect( $master );
    isa_ok $clone, 'DBIx::Squirrel::db';
    test_prepare_execute_fetch_cycle($clone);

    $clone->disconnect;
    $master->disconnect;
    return;
}

sub test_prepare_execute_fetch_cycle {
    my $dbh = shift;

    diag "";
    diag "Test prepare-execute-fetch cycle";
    diag "";

    my $sql = << '';
        SELECT * FROM media_types ORDER BY MediaTypeId

    my $sth = $dbh->prepare($sql);
    
    return;
}