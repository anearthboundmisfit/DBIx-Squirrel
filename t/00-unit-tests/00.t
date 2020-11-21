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

    diag "";
    diag "Test prepare-execute-fetch cycle";
    diag "";
    test_prepare_execute_fetch_single_row( $clone );
    test_prepare_execute_fetch_multiple_rows( $clone );

    $clone->disconnect;
    $master->disconnect;
    return;
}

sub test_prepare_execute_fetch_single_row {
    my ( $dbh ) = @_;
    my (
        $sql, $sth, $res, $got, @got, $exp, @exp, $row, $stdout, $stderr,
        @hashrefs, @arrayrefs
    );

    diag "Result contains a single row";
    diag "";

    $sql = << '';
    SELECT *
    FROM media_types
    ORDER BY MediaTypeId
    LIMIT 1

    @arrayrefs = (
        [ 1, "MPEG audio file", ],
    );

    @hashrefs = ( {
            MediaTypeId => 1,
            Name        => "MPEG audio file",
        }
    );

    $sth = $dbh->prepare( $sql );
    isa_ok $sth, 'DBIx::Squirrel::st';

    $res = $sth->execute;
    is $res, '0E0', 'execute';
    diag_result $sth;

    ( $exp, $got ) = (
        $arrayrefs[ 0 ],
        do {
            $sth->execute;
            ( $stderr, $row ) = capture_stderr { $sth->single };
            $row;
        },
    );
    is_deeply $exp, $got, 'single';
    is $stderr, '', 'got no warning when result contains single row';

    return;
}

sub test_prepare_execute_fetch_multiple_rows {
    my ( $dbh ) = @_;
    my (
        $sql, $sth, $res, $got, @got, $exp, @exp, $row, $stdout, $stderr,
        @hashrefs, @arrayrefs
    );

    diag "";
    diag "Result contains multiple rows";
    diag "";

    $sql = << '';
    SELECT *
    FROM media_types
    ORDER BY MediaTypeId

    @arrayrefs = (
        [ 1, "MPEG audio file", ],
        [ 2, "Protected AAC audio file", ],
        [ 3, "Protected MPEG-4 video file", ],
        [ 4, "Purchased AAC audio file", ],
        [ 5, "AAC audio file", ],
    );

    @hashrefs = ( {
            MediaTypeId => 1,
            Name        => "MPEG audio file",
        },
        {
            MediaTypeId => 2,
            Name        => "Protected AAC audio file",
        },
        {
            MediaTypeId => 3,
            Name        => "Protected MPEG-4 video file",
        },
        {
            MediaTypeId => 4,
            Name        => "Purchased AAC audio file",
        },
        {
            MediaTypeId => 5,
            Name        => "AAC audio file",
        },
    );

    $sth = $dbh->prepare( $sql );
    isa_ok $sth, 'DBIx::Squirrel::st';

    $res = $sth->execute;
    is $res, '0E0', 'execute';
    diag_result $sth;

    ( $exp, $got ) = (
        $arrayrefs[ 0 ],
        do {
            $sth->execute;
            ( $stderr, $row ) = capture_stderr { $sth->single };
            $row;
        },
    );
    is_deeply $exp, $got, 'single';
    like $stderr, qr/Query returned more than one row/,
      'got warning when result contains multiple rows';

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            scalar $sth->remaining;
        },
    );
    is_deeply $exp, $got, 'remaining yields complete set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        $arrayrefs[ 0 ],
        do {
            $sth->execute;
            ( $stderr, $row ) = capture_stderr { $sth->single };
            $row;
        },
    );
    is_deeply $exp, $got, 'single';

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            [ $sth->remaining ];
        },
    );
    is_deeply $exp, $got, 'remaining yields complete set'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        $arrayrefs[ 0 ],
        do {
            $sth->execute;
            $sth->first;
        },
    );
    is_deeply $exp, $got, 'first';

    ( $exp, $got ) = (
        [ @arrayrefs[ 1 .. 4 ] ],
        do {
            scalar $sth->remaining;
        },
    );
    is_deeply $exp, $got, 'remaining'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        $arrayrefs[ 0 ],
        do {
            $sth->execute;
            $sth->first;
        },
    );
    is_deeply $exp, $got, 'first';

    ( $exp, $got ) = (
        [ @arrayrefs[ 1 .. 4 ] ],
        do {
            [ $sth->remaining ];
        },
    );
    is_deeply $exp, $got, 'remaining'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            $sth->execute;
            scalar $sth->all;
        },
    );
    is_deeply $exp, $got, 'all'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            $sth->execute;
            [ $sth->all ];
        },
    );
    is_deeply $exp, $got, 'all'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            my @ary;
            $sth->reset;
            while ( my $row = $sth->next ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'next'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @arrayrefs ],
        do {
            my @ary = $sth->first;
            while ( my $row = $sth->next ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'first, next'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @hashrefs ],
        do {
            my @ary;
            $sth->reset( {} );
            while ( my $row = $sth->next ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'next (hashrefs)'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @hashrefs ],
        do {
            my @ary = $sth->first( {} );
            while ( my $row = $sth->next ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'first, next (hashrefs)'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @hashrefs ],
        do {
            my @ary;
            $sth->reset;
            while ( my $row = $sth->next( {} ) ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'next (hashrefs)'
      or dump_val { exp => $exp, got => $got };

    ( $exp, $got ) = (
        [ @hashrefs ],
        do {
            my @ary = $sth->first( {} );
            while ( my $row = $sth->next ) {
                push @ary, $row;
            }
            [ @ary ];
        },
    );
    is_deeply $exp, $got, 'first, next (hashrefs)'
      or dump_val { exp => $exp, got => $got };

    return;
}
