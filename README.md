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

## Description

DBIx-Squirrel is a lightweight DBI extension, aimed at making programs that work with databases (and the DBI) easier to write and maintain.

### Feature highlights

- **Like DBI but easier**<br>Still looks and feels like plain old DBI
when you need it to, but makes life easier when you want simplicity.
- **Connect to database handles**<br>The familiar `connect` method may
also be used to clone and connect to other database handles, including those created using DBI.
- **Parameter placeholders**<br>A total of five different placeholder styles are supported, offering greater flexibility and portability.
- **Parameter binding**<br>Common sense, simple binding of parameters
to placeholders. 