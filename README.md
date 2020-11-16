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

$sth = $dbh->prepare(<< '');
    SELECT * FROM table WHERE column_1 = ? AND column_2 = ?

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute( [ 'value_1', 'value_2' ] );

$sth = $dbh->prepare(<< '');
    SELECT * FROM table WHERE column_1 = ?1 AND column_2 = ?2

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute( [ 'value_1', 'value_2' ] );

$sth = $dbh->prepare(<< '');
    SELECT * FROM table WHERE column_1 = $1 AND column_2 = $2

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute( [ 'value_1', 'value_2' ] );

$sth = $dbh->prepare(<< '');
    SELECT * FROM table WHERE column_1 = :1 AND column_2 = :2

$res = $sth->execute( 'value_1', 'value_2' );
$res = $sth->execute( [ 'value_1', 'value_2' ] );

$sth = $dbh->prepare(<< '');
    SELECT * FROM table WHERE column_1 = :v1 AND column_2 = :v2

$res = $sth->execute( v1=>'value_1', v2=>'value_2' );
$res = $sth->execute( ':v1'=>'value_1', ':v2'=>'value_2' );
$res = $sth->execute( [ v1=>'value_1', v2=>'value_2' ] );
$res = $sth->execute( [ ':v1'=>'value_1', ':v2'=>'value_2' ] );
$res = $sth->execute( { v1=>'value_1', v2=>'value_2' } );
$res = $sth->execute( { ':v1'=>'value_1', ':v2'=>'value_2' } );
```

### Description

DBIx-Squirrel is a lightweight DBI extension, aimed at making programs that work with databases (and the DBI) easier to write and maintain.