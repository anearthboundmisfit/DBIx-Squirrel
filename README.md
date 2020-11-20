<img src="./ekorn.png?raw=true" width="64" height="64" align="right">

# DBIx-Squirrel

A module for working with databases.

### Synopsis

``` perl
use DBIx::Squirrel;

# Connect as you would with DBI
$dbh1 = DBIx::Squirrel->connect($dsn, $user, $pass, \%attr);

# Connect to and clone database handles (even standard DBI::db
# handles)
$dbh1 = DBI->connect($dsn, $user, $pass, \%attr);
$dbh  = DBIx::Squirrel->connect($dbh);

# Prepare statements the old-fashioned way using standard
# placeholders
$sth1 = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = ? AND column_2 = ?
;;

# Prepare clones of previously prepared statements
$sth = $dbh->prepare( $sth1 );
$sth = $sth1->prepare;
$sth = $sth1->clone;

# Bind values the old-fashioned way
$sth->bind_param( 1, 'value_1' );
$sth->bind_param( 2, 'value_2' );

# Bind value lists the easy way
$sth->bind( 'value_1', 'value_2' );

# Oh, and enclosing value lists as array refs is okay, too 
$sth->bind([ 'value_1', 'value_2' ]);

# Execute
$res = $sth->execute;

# Use SQLite ?n-style placeholders
$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = ?1 AND column_2 = ?2
;;

# Or PostgreSQL $1-style or :1-style placeholders 
$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = $1 AND column_2 = $2
;;
$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = :1 AND column_2 = :2
;;

# Or PostgreSQL / Oracle :name-style placeholders
$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 = :v1 AND column_2 = :v2
;;

# With sensible, simple value-binding schemes
$res = $sth->execute( v1=>'value_1', v2=>'value_2' );
$res = $sth->execute( ':v1'=>'value_1', ':v2'=>'value_2' );
$res = $sth->execute([ v1=>'value_1', v2=>'value_2' ]);
$res = $sth->execute([ ':v1'=>'value_1', ':v2'=>'value_2' ]);
$res = $sth->execute({ v1=>'value_1', v2=>'value_2' });
$res = $sth->execute({ ':v1'=>'value_1', ':v2'=>'value_2' });

# Effortless iterators
$sth = $dbh->prepare(<< ';;');
    SELECT * FROM table WHERE column_1 LIKE ?
;;
while ( $row = $sth->next ) {
  print Dumper($row);
}

# Reset iterators (and change row disposition)
$sth = $sth->reset;
$sth = $sth->reset({});
$sth = $sth->reset([]);

# Easily access single, first, remaining and all rows
$row = $sth->single;
$row = $sth->first;
@ary = $sth->remaining;
@ary = $sth->all;

# Use single, find and all to temporarily override bind-values
$row = $sth->single('B%');
$row = $sth->find('B%');
@ary = $sth->all('B%');

# Rule of thumb for anything not covered -- if it hasn't had a
# face-lift then it works the same way as it does for DBI!
```

## Description

DBIx-Squirrel is a lightweight DBI extension that makes it easier to write and maintain programs that work with databases. It works just like DBI right out
of the box (offering comfortable familiarity), and offers a slate of graceful enhancements when they are needed.

**Highlights**

- Connect to database handles — pass a database connection handle to the
`connect` method to clone it. Database connections opened using standard
DBI may also be cloned and enriched.
- Built-in support for *`?`*, *`?1`*, *`$1`*, *`:1`*, and *`:name`* parameter
placeholder styles, regardless of driver.
- Hassle-free binding of parameter values to placeholders. 
- Looks and feels like DBI when you need it to, while offering less labour-intensive ways to do things.