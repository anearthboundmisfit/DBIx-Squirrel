<img src="./ekorn.png?raw=true" width="64" height="64" align="right">

# DBIx-Squirrel

A module for working with databases.

DBIx-Squirrel is a lightweight DBI extension, aimed at making programs that 
work with databases (and the DBI) easier to write and maintain.

## Synopsis

``` perl
use DBIx::Squirrel;

$dbh = DBIx::Squirrel->connect($dsn, $user, $pass, \%attr);
$dbh = DBIx::Squirrel->connect($another_dbh);
```