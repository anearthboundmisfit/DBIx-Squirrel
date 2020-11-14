BEGIN {
    delete $INC{ 'FindBin.pm' };
    require FindBin;
    require Cwd;
}

use lib Cwd::realpath( "$FindBin::Bin/../lib" );
use Test::Most;
use DBIx::Squirrel::util ':all';
use DBIx::Squirrel;

ok( 1, __FILE__ . ' complete' );
done_testing();
