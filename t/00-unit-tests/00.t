BEGIN {
    delete $INC{ 'FindBin.pm' };
    require FindBin;
}

use autobox::Core;
use Test::Most;
use Capture::Tiny 'capture_stdout', 'capture_stderr', 'capture';
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
    my ( $master, $description ) = @{ +shift };

    diag "";
    diag "Test connection cloned from a $description";
    diag "";

    my $clone = DBIx::Squirrel->connect( $master );
    isa_ok $clone, 'DBIx::Squirrel::db';
    test_prepare_execute_fetch_cycle( $clone );

    $clone->disconnect;
    $master->disconnect;
    return;
}

sub test_prepare_execute_fetch_cycle {
    my ( $dbh ) = @_;
    my ( $sql, $sth, $res );

    diag "";
    diag "Test prepare-execute-fetch cycle";
    diag "";

    $sql = << '';
    SELECT *
    FROM media_types
    WHERE MediaTypeId > ?
    ORDER BY MediaTypeId

    $sth = $dbh->prepare( $sql );
    $res = $sth->execute( 0 );

    diag dump_results( $sth, $res );
    diag "";

    return;
}

sub dump_results {
    my ( $sth ) = @_;
    my ( $summary, @rows ) = do {
        my @res = split /\n/, capture_stdout { $sth->dump_results };
        ( pop @res, @res );
    };
    return join "\n", (
        'Statement',
        '---------',
        $sth->{ Statement }, '',
        do {
            if ( %{ $sth->{ ParamValues } } ) {
                (
                    'Parameters',
                    '----------',
                    Dumper( $sth->{ ParamValues } ),
                );
            } else {
                ();
            }
        },
        do {
            if ( @rows ) {
                (
                    'Result (' . $summary . ')',
                    '--------' . ( '-' x ( 1 + length( $summary ) ) ),
                    @rows,
                );
            } else {
                ();
            }
        },
    );
}
