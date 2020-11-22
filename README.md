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

# Sensible and simple value-binding
$res = $sth->execute( v1=>'value_1', v2=>'value_2' );
$res = $sth->execute( ':v1'=>'value_1', ':v2'=>'value_2' );
$res = $sth->execute([ v1=>'value_1', v2=>'value_2' ]);
$res = $sth->execute([ ':v1'=>'value_1', ':v2'=>'value_2' ]);
$res = $sth->execute({ v1=>'value_1', v2=>'value_2' });
$res = $sth->execute({ ':v1'=>'value_1', ':v2'=>'value_2' });

# Effortless iterators (no execute required here)
$sth = $dbh->prepare( 'SELECT * FROM table' );
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
DBIx-Squirrel is a Perl 5 module for working with databases.

DBIx-Squirrel is a DBI extension insomuch as it subclasses the popular DBI package (and other packages within that namespace), making minimalist enhancements to its venerable ancestor's interface.

As someone who enjoys working with DBI (sometimes preferring it to heavyweight alternatives), I simply wanted some small improve the user experience, without those improvements seeming too alien in nature.

### Design

#### Compatibility
A developer may confidently replace `use DBI` with `use DBIx::Squirrel` and expect a script to function as it did prior to the change. 

DBIx-Squirrel's enhancements are designed to be low-friction, intuitive (and above all), elective. Things should work as expected, until our requirements change and any deviation from the norm is expected.

In addition to a high degree of backward compatibility, interface-design has been forward-looking, too. Where some DBIx-Squirrel concepts have analogs within DBIx-Class, the same method names will implement analogous behaviours.

#### Ease of use
DBIx-Squirrel's baseline behaviour is _be like DBI_. There is no barrier to using this module if you are familiar with the DBI or DBI's extensive documentation.

Pretty much all of DBIx-Squirrel's features are enhancements progressive or additive in nature. For most experienced DBI (or DBIx-Class) developers, a cursory glance down the synopsis will be enough to get them started.

### Features

#### Connecting to databases

#### Bind values, parameter placeholders, and binding in general

#### Iterators

