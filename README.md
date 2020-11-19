<img src="./ekorn.png?raw=true" width="64" height="64" align="right">

# DBIx-Squirrel

A module for working with databases.

### Synopsis

``` perl
use DBIx::Squirrel;

$dbh   = DBIx::Squirrel->connect($dsn, $user, $pass, \%attr);
$clone = DBIx::Squirrel->connect($dbh);

$dbh   = DBI->connect($dsn, $user, $pass, \%attr);
$clone = DBIx::Squirrel->connect($dbh);

$sth1 = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = ? AND column_2 = ?
;;

$sth = $dbh->prepare( $sth1 );
$sth->bind_param( 1, 'value_1' );
$sth->bind_param( 2, 'value_2' );
$res = $sth->execute;

$sth = $dbh->prepare( $sth1 );
$sth->bind( 'value_1', 'value_2' );
$res = $sth->execute;

$sth = $dbh->prepare( $sth1 );
$sth->bind([ 'value_1', 'value_2' ]);
$res = $sth->execute;

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute([ 'value_1', 'value_2' ]);

$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = ?1 AND column_2 = ?2
;;

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute([ 'value_1', 'value_2' ]);

$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = $1 AND column_2 = $2
;;

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute([ 'value_1', 'value_2' ]);

$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = :1 AND column_2 = :2
;;

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute([ 'value_1', 'value_2' ]);

$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = :v1 AND column_2 = :v2
;;

$res = $sth->execute( v1=>'value_1', v2=>'value_2' );
$res = $sth->execute( ':v1'=>'value_1', ':v2'=>'value_2' );
$res = $sth->execute([ v1=>'value_1', v2=>'value_2' ]);
$res = $sth->execute([ ':v1'=>'value_1', ':v2'=>'value_2' ]);
$res = $sth->execute({ v1=>'value_1', v2=>'value_2' });
$res = $sth->execute({ ':v1'=>'value_1', ':v2'=>'value_2' });

$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 LIKE ?
;;

$sth->reset;
while ( $row = $sth->next ) {
  print Dumper($row);
}

$sth->reset;
$row = $sth->find('B%');
$row = $sth->single;
$row = $sth->first;
@ary = $sth->remaining;
@ary = $sth->all;
@ary = $sth->all('B%');


$itor = $sth->iterate('A%');
while ($row = $itor->next) {
  print Dumper($row);
}

$itor->reset;
$row = $itor->find('B%');
$row = $itor->single;
$row = $itor->first;
@ary = $itor->remaining;
@ary = $itor->all;
@ary = $itor->all('B%');
```

## Description

DBIx-Squirrel is a lightweight DBI extension that helpst make programs that work with databases easier to write and maintain. It works just like DB
out-of-the-box, offering comfortable familiarity, offering a slew of
graceful enhancements when they are needed.

Feature highlights:

- Connect to database handles — pass a database connection handle to the
**`connect`** method to clone it. Database connections opened using standard
DBI may also be cloned and enriched.
- Built-in support for *`?`*, *`?1`*, *`$1`*, *`:1`*, and *`:name`* parameter
placeholder styles, regardless of driver.
- Hassle-free binding of parameter values to placeholders. 
- Looks and feels like DBI when you need it to but there are also easier ways
to do things.