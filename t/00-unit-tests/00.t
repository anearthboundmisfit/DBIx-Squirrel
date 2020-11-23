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

our (
    $sql, $sth, $res, $got, @got, $exp, @exp, $row, $dbh, $it, $stdout, $rs,
    $stderr, @hashrefs, @arrayrefs, $standard_dbi_dbh, $standard_ekorn_dbh,
    $cached_ekorn_dbh,
);

print STDERR "\n";

test_the_basics();

ok 1, __FILE__ . ' complete';
done_testing;

sub test_the_basics {

    diag "";
    diag "Test the basics";
    diag "";

    # Check that "whine" emits warnings

    ( $exp, $got ) = (
        99,
        do {
            ( $stderr ) = capture_stderr {
                whine 'Got a warning';
            };
            99;
        },
    );
    is $got, $exp, 'whine';
    like $stderr, qr/Got a warning at/, 'whine';

    ( $stderr ) = capture_stderr {
        whine 'Got %s warning', 'another';
    };
    like $stderr, qr/Got another warning at/, 'whine';

    # Check that "throw" triggers exceptions

    throws_ok { throw 'An error' } ( qr/An error at/, 'throw' );
    throws_ok { throw '%s error', 'Another' } ( qr/Another error at/, 'throw' );

    # Check that "DBIx::Squirrel::dr::_is_db_handle" does its thing

    $standard_dbi_dbh = DBI->connect( @T_DB_CONNECT_ARGS );
    ok DBIx::Squirrel::dr::_is_db_handle( $standard_dbi_dbh ),
      '_is_db_handle';
    ok !DBIx::Squirrel::dr::_is_db_handle( '' ),
      '_is_db_handle';
    ok !DBIx::Squirrel::dr::_is_db_handle( \'' ),
      '_is_db_handle';
    is DBIx::Squirrel::dr::_is_db_handle( $standard_dbi_dbh ), 'DBI::db',
      '_is_db_handle';

    # Check that we can open standard and cached DBIx::Squirrel::db
    # connections

    $standard_ekorn_dbh = DBIx::Squirrel->connect( @T_DB_CONNECT_ARGS );
    isa_ok $standard_ekorn_dbh, 'DBIx::Squirrel::db';

    $cached_ekorn_dbh = DBIx::Squirrel->connect_cached( @T_DB_CONNECT_ARGS );
    isa_ok $cached_ekorn_dbh, 'DBIx::Squirrel::db';

    # Check that "DBIx::Squirrel::db::_get_param_order" works properly

    ( $exp, $got ) = ( [
            undef,
            'SELECT * FROM table WHERE col = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col = ? '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [
            undef,
            'SELECT * FROM table WHERE col1 = ? AND col2 = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col1 = ? AND col2 = ? '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => '$1',
            },
            'SELECT * FROM table WHERE col = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col = $1 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => '$1',
                2 => '$2',
            },
            'SELECT * FROM table WHERE col1 = ? AND col2 = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col1 = $1 AND col2 = $2 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => '?1',
            },
            'SELECT * FROM table WHERE col = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col = ?1 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => '?1',
                2 => '?2',
            },
            'SELECT * FROM table WHERE col1 = ? AND col2 = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col1 = ?1 AND col2 = ?2 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => ':1',
            },
            'SELECT * FROM table WHERE col = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col = :1 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => ':1',
                2 => ':2',
            },
            'SELECT * FROM table WHERE col1 = ? AND col2 = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col1 = :1 AND col2 = :2 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => ':n',
            },
            'SELECT * FROM table WHERE col = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col = :n '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [ {
                1 => ':n1',
                2 => ':n2',
            },
            'SELECT * FROM table WHERE col1 = ? AND col2 = ?',
        ],
        do {
            [
                DBIx::Squirrel::db::_get_param_order(
                    ' SELECT * FROM table WHERE col1 = :n1 AND col2 = :n2 '
                )
            ];
        },
    );
    is_deeply $exp, $got, '_get_param_order'
      or dump_val { exp => $exp, got => $got };

    # Check that "DBIx::Squirrel::db::_common_prepare_work" works properly

    ( $exp, $got ) = ( [ {
                1 => ':id',
            },
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = ?',
                )
            ),
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = :id',
                )
            ),
        ],
        do {
            [
                DBIx::Squirrel::db::_common_prepare_work(
                    join ' ', (
                        'SELECT *',
                        'FROM media_types',
                        'WHERE MediaTypeId = :id',
                    )
                )
            ];
        },
    );
    is_deeply $exp, $got, '_common_prepare_work (plain text statement)'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_dbi_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE MediaTypeId = ?',
        )
    );

    ( $exp, $got ) = ( [
            undef,
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = ?',
                )
            ),
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = ?',
                )
            ),
        ],
        do {
            [ DBIx::Squirrel::db::_common_prepare_work( $sth ) ];
        },
    );
    is_deeply $exp, $got, '_common_prepare_work (DBI::st)'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE MediaTypeId = :id',
        )
    );

    ( $exp, $got ) = ( [ {
                1 => ':id',
            },
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = ?',
                )
            ),
            (
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                    'WHERE MediaTypeId = :id',
                )
            ),
        ],
        do {
            [ DBIx::Squirrel::db::_common_prepare_work( $sth ) ];
        },
    );
    is_deeply $exp, $got, '_common_prepare_work (DBIx::Squirrel::st)'
      or dump_val { exp => $exp, got => $got };

    # Check that "DBIx::Squirrel::st::_order_of_placeholders_if_positional"
    # works properly

    ( $exp, $got ) = (
        undef,
        DBIx::Squirrel::st::_order_of_placeholders_if_positional( undef ),
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        undef,
        DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                1 => ':name',
            }
        ),
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        undef,
        DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                1 => ':name',
                2 => ':2',
            }
        ),
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            1 => ':1',
        },
        {
            DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                    1 => ':1',
                }
            )
        },
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            1 => ':1',
            2 => ':2'
        },
        {
            DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                    1 => ':1',
                    2 => ':2',
                }
            )
        },
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            1 => ':1',
        },
        {
            DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                    1 => ':1',
                }
            )
        },
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            1 => '$1',
            2 => '$2'
        },
        {
            DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                    1 => '$1',
                    2 => '$2',
                }
            )
        },
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            1 => '?1',
            2 => '?2'
        },
        {
            DBIx::Squirrel::st::_order_of_placeholders_if_positional( {
                    1 => '?1',
                    2 => '?2',
                }
            )
        },
    );
    is_deeply $exp, $got, '_order_of_placeholders_if_positional'
      or dump_val { exp => $exp, got => $got };

    # Check that "DBIx::Squirrel::st::_format_params" works

    ( $exp, $got ) = (
        [],
        [ DBIx::Squirrel::st::_format_params( undef ) ],
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ 'a', 'b' ],
        [
            DBIx::Squirrel::st::_format_params(
                undef,
                ( 'a', 'b' ),
            )
        ],
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { '?1' => 'a', '?2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => '?1', 2 => '?2' },
                ( 'a', 'b' ),
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { '$1' => 'a', '$2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => '$1', 2 => '$2' },
                ( 'a', 'b' ),
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { ':1' => 'a', ':2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => ':1', 2 => ':2' },
                ( 'a', 'b' ),
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { ':n1' => 'a', ':n2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => ':n1', 2 => ':n2' },
                ( ':n1' => 'a', ':n2' => 'b' ),
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 'n1' => 'a', 'n2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => ':n1', 2 => ':n2' },
                ( 'n1' => 'a', 'n2' => 'b' ),
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 'n1' => 'a', 'n2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1 => ':n1', 2 => ':n2' },
                [ 'n1' => 'a', 'n2' => 'b' ],
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 'n1' => 'a', 'n2' => 'b' },
        {
            DBIx::Squirrel::st::_format_params(
                { 1    => ':n1', 2    => ':n2' },
                { 'n1' => 'a',   'n2' => 'b' },
            )
        },
    );
    is_deeply $exp, $got, '_format_params'
      or dump_val { exp => $exp, got => $got };

    # Check that "DBIx::Squirrel::st::bind_param" works properly

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = ?',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( 1 => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = ?1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( '?1' => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( 1 => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = $1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( '$1' => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( 1 => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = :1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( ':1' => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( 1 => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = :name',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( ':name' => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( name => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        { $sth->bind_param( 1 => 'AAC audio file' ) },
    );
    is_deeply $exp, $got, 'bind_param'
      or dump_val { exp => $exp, got => $got };

    # Check the "DBIx::Squirrel::st::bind" works properly

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = ?',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = ?1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = $1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = :1',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = :name',
        )
    );

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( ':name' => 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( { ':name' => 'AAC audio file' } );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( [ ':name' => 'AAC audio file' ] );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( name => 'AAC audio file' );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( { name => 'AAC audio file' } );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { 1 => 'AAC audio file' },
        do {
            $res = $sth->bind( [ name => 'AAC audio file' ] );
            is $res, $sth, 'bind';
            $sth->{ ParamValues };
        },
    );
    is_deeply $exp, $got, 'bind'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE Name = :name',
        )
    );

    $it = $sth->iterate( name => 'AAC audio file' );
    isa_ok $it, 'DBIx::Squirrel::it';

    ( $exp, $got ) = (
        bless( {
                MaxRows => 10,
                Slice   => [],
            },
            'DBIx::Squirrel::it'
        ),
        $it,
    );
    is_deeply $exp, $got, 'iterate'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( {
            itor   => $it,
            params => {
                1 => ":name",
            },
            sql => "SELECT * FROM media_types WHERE Name = :name",
            std => "SELECT * FROM media_types WHERE Name = ?",
        },
        $sth->{ private_dbix_squirrel },
    );
    is_deeply $exp, $got, 'iterate'
      or dump_val { exp => $exp, got => $got };

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
        )
    );

    $it = $sth->iterate;

    ( $exp, $got ) = (
        [ 1, 'MPEG audio file' ],
        do {
            diag "";
            diag "THE FOLLOWING WARNING IS EXPECTED - BE NOT ALARMED!";
            diag "";
            $it->single;
        }
    );
    is_deeply $exp, $got, 'single'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ 1, 'MPEG audio file' ],
        $it->first,
    );
    is_deeply $exp, $got, 'first'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { MediaTypeId => 1, Name => "MPEG audio file" },
        do {
            $it->reset( {} );
            $it->first;
        },
    );
    is_deeply $exp, $got, 'first'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { MediaTypeId => 1, Name => "MPEG audio file" },
        $it->first( {} ),
    );
    is_deeply $exp, $got, 'first'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        { MediaTypeId => 2, Name => "Protected AAC audio file" },
        $it->next,
    );
    is_deeply $exp, $got, 'next'
      or dump_val { exp => $exp, got => $got };

    $sth->finish;

    $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
            'WHERE MediaTypeId = :id',
        )
    );

    $it = $sth->iterate( id => 1 );

    ( $exp, $got ) = (
        [ 1, 'MPEG audio file' ],
        $it->single,
    );
    is_deeply $exp, $got, 'single'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ 5, 'AAC audio file' ],
        $it->single( id => 5 ),
    );
    is_deeply $exp, $got, 'single'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ 1, 'MPEG audio file' ],
        $it->single,
    );
    is_deeply $exp, $got, 'single'
      or dump_val { exp => $exp, got => $got };

    my $sth = $standard_ekorn_dbh->prepare(
        join ' ', (
            'SELECT *',
            'FROM media_types',
        )
    );

    ( $exp, $got ) = (
        bless( { MaxRows => 10, Slice => {} }, 'DBIx::Squirrel::ResultSet' ),
        do {
            my $sth = $standard_ekorn_dbh->prepare(
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                )
            )->reset( {} );
            $sth->result_set;
        },
    );
    is_deeply $exp, $got, 'result_set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        bless( { MaxRows => 10, Slice => {} }, 'DBIx::Squirrel::ResultSet' ),
        do {
            my $sth = $standard_ekorn_dbh->prepare(
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                )
            );
            $sth->result_set->reset( {} );
        },
    );
    is_deeply $exp, $got, 'result_set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        bless( { MaxRows => 10, Slice => [] }, 'DBIx::Squirrel::ResultSet' ),
        do {
            my $sth = $standard_ekorn_dbh->prepare(
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                )
            )->reset( [] );
            $sth->result_set;
        },
    );
    is_deeply $exp, $got, 'result_set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        bless( { MaxRows => 10, Slice => [] }, 'DBIx::Squirrel::ResultSet' ),
        do {
            my $sth = $standard_ekorn_dbh->prepare(
                join ' ', (
                    'SELECT *',
                    'FROM media_types',
                )
            );
            $sth->result_set->reset( [] );
        },
    );
    is_deeply $exp, $got, 'result_set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        bless( { MaxRows => 10, Slice => [] }, 'DBIx::Squirrel::ResultSet' ),
        do {
            $sth->result_set;
        },
    );
    is_deeply $exp, $got, 'result_set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        bless( [ 1, "MPEG audio file" ], 'DBIx::Squirrel::Result' ),
        do {
            $sth->result_set->first;
        },
    );
    is_deeply $exp, $got, 'first'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = ( [
            bless( [
                    1,
                    "MPEG audio file",
                ],
                'DBIx::Squirrel::Result'
            ),
            bless( [
                    2,
                    "Protected AAC audio file",
                ],
                'DBIx::Squirrel::Result'
            ),
            bless( [
                    3,
                    "Protected MPEG-4 video file",
                ],
                'DBIx::Squirrel::Result'
            ),
            bless( [
                    4,
                    "Purchased AAC audio file",
                ],
                'DBIx::Squirrel::Result'
            ),
            bless( [
                    5,
                    "AAC audio file",
                ],
                'DBIx::Squirrel::Result'
            ),
        ],
        ,
        do {
            [ $sth->result_set->all ];
        },
    );
    is_deeply $exp, $got, 'all'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        5,
        do {
            my $rs = $sth->result_set;
            $rs->count;
        },
    );
    is_deeply $exp, $got, 'count'
      or dump_val { exp => $exp, got => $got };

    $sth->finish;

    $standard_ekorn_dbh->disconnect;
    $standard_dbi_dbh->disconnect;

    return;
}
