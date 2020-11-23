<img src="./ekorn.png?raw=true" width="64" height="64" align="right">

# DBIx-Squirrel

A module for working with databases.

### Synopsis

``` perl
use DBIx::Squirrel;

$db1 = DBI->connect($dsn, $user, $pass, \%attr);
$dbh = DBIx::Squirrel->connect($db1);
$dbh = DBIx::Squirrel->connect($dsn, $user, $pass, \%attr);

$st1 = $db1->prepare('SELECT * FROM product WHERE id = ?');
$sth = $dbh->prepare($st1);
$sth->bind_param(1, '1001099');
$sth->bind( '1001099' );
$sth->bind(['1001099']);
$res = $sth->execute;
$res = $sth->execute( '1001099' );
$res = $sth->execute(['1001099']);
$itr = $sth->iterate( '1001099' );
$itr = $sth->iterate(['1001099']);

$sth = $dbh->prepare('SELECT * FROM product WHERE id = ?');
$sth->bind_param(1, '1001099');
$sth->bind( '1001099' );
$sth->bind(['1001099']);
$res = $sth->execute;
$res = $sth->execute( '1001099' );
$res = $sth->execute(['1001099']);
$itr = $sth->iterate( '1001099' );
$itr = $sth->iterate(['1001099']);

$sth = $dbh->prepare('SELECT * FROM product WHERE id = ?1');
$sth->bind_param(1, '1001099');
$sth->bind( '1001099' );
$sth->bind(['1001099']);
$res = $sth->execute;
$res = $sth->execute( '1001099' );
$res = $sth->execute(['1001099']);
$itr = $sth->iterate( '1001099' );
$itr = $sth->iterate(['1001099']);

$sth = $dbh->prepare('SELECT * FROM product WHERE id = $1');
$sth->bind_param(1, '1001099');
$sth->bind( '1001099' );
$sth->bind(['1001099']);
$res = $sth->execute;
$res = $sth->execute( '1001099' );
$res = $sth->execute(['1001099']);
$itr = $sth->iterate( '1001099' );
$itr = $sth->iterate(['1001099']);

$sth = $dbh->prepare('SELECT * FROM product WHERE id = :1');
$sth->bind_param(1, '1001099');
$sth->bind( '1001099' );
$sth->bind(['1001099']);
$res = $sth->execute;
$res = $sth->execute( '1001099' );
$res = $sth->execute(['1001099']);
$itr = $sth->iterate( '1001099' );
$itr = $sth->iterate(['1001099']);

$sth = $dbh->prepare('SELECT * FROM product WHERE id = :id');
$sth->bind_param(':id', '1001099');
$res = $sth->bind( ':id', '1001099' );
$res = $sth->bind([':id', '1001099']);
$res = $sth->bind({':id', '1001099'});
$res = $sth->bind( id=>'1001099' );
$res = $sth->bind([id=>'1001099']);
$res = $sth->bind({id=>'1001099'});
$res = $sth->execute;
$res = $sth->execute( id=>'1001099' );
$res = $sth->execute([id=>'1001099']);
$res = $sth->execute({id=>'1001099'});
$itr = $sth->iterate( id=>'1001099' );
$itr = $sth->iterate([id=>'1001099']);
$itr = $sth->iterate({id=>'1001099'});

@ary = ();
while ($next = $itr->next) {
  push @ary, $next;
}

@ary = $itr->first;
push @ary, $_ while $itr->next;

@ary = $itr->first;
push @ary, $itr->remaining;

@ary = $itr->all;

$itr = $itr->reset;     # Repositions iterator at the start
$itr = $itr->reset({}); # Fetch rows as hashrefs
$itr = $itr->reset([]); # Fetch rows as arrayrefs

$row = $itr->single;
$row = $itr->single( id=>'1001100' );
$row = $itr->single([id=>'1001100']);
$row = $itr->single({id=>'1001100'});
$row = $itr->find( id=>'1001100' );
$row = $itr->find([id=>'1001100']);
$row = $itr->find({id=>'1001100'});

# Iterator methods may also be applied directly to statement objects,
# and will automatically execute the statements if execution is
# required.
```

## Description
DBIx-Squirrel is a Perl 5 module for working with databases.

DBIx-Squirrel is a DBI extension insomuch as it subclasses the popular DBI package (and other packages within that namespace), making minimalist enhancements to its venerable ancestor's interface.

As someone who enjoys working with DBI (sometimes preferring it to heavyweight alternatives), I simply wanted a few small improvements to the user experience, without those improvements seeming too alien in nature.

### Design

#### Compatibility
A developer may confidently replace `use DBI` with `use DBIx::Squirrel` and expect a script to function as it did prior to the change. 

DBIx-Squirrel's enhancements are designed to be low-friction, intuitive (and above all), elective. Things should work as expected until our requirements change, and any deviation from the norm is expected.

In addition to a high degree of backward compatibility, interface-design has also been forward-looking. Where some DBIx-Squirrel concepts have analogs within DBIx-Class (another popular package), the same method names will implement any analogous behaviours.

#### Ease of use
DBIx-Squirrel's baseline behaviour is _be like DBI_. There is no barrier to using this module if you are familiar with the DBI, or its extensive documentation.

Pretty much all of DBIx-Squirrel's enhancements are progressive or additive in nature. For most experienced DBI (or DBIx-Class) developers, a cursory glance at the synopsis should be enough to get them started.

### Features

#### Connecting to databases, and preparing statements
- The `connect` method continues to work as expected. It may also be invoked with a single argument (another database handle), if the intention is to clone that connection. This is particularly useful when cloning a standard DBI database object, since the resulting clone will be a DBI-Squirrel database object.

- The `prepare` and `prepare_cached` methods continue to work as expected, though passing a statement handle, instead of a statement in a string, results in that statement being cloned. Again, this is useful when the intention is to clone a standard DBI statement object in order to produce a DBIx-Squirrel statement object.

#### Parameter placeholders, and bind values
- Regardless of the database driver being used, DBIx-Squirrel provides baseline support for five parameter placeholder schemes (`?`, `?1`,  `$1`, `:1`, `:name`).
- A statement object's `bind_param` method will continue to work as expected, though its behaviour has been progressively enhanced. It now accommodates both `bind_param(':name', 'value')` and `bind_param('name', 'value')` calling styles, as well as the `bind_param(1, 'value')` style for positional placeholders.
- Statement objects have a new `bind` method which is aimed at greatly streamlining the binding of values to statement parameters, and improving program readability.
- A statement object's `execute` method will accept any arguments you would pass to the `bind` method. It isn't really necessary to call `bind` because `execute` will take care of that.

#### Iterators
- DBIx-Squirrel implements its own iterator class, making the traversal of result sets super simple and efficient. You will hardly ever need to instantiate an iterator (though you can), since DBIx-Squirrel statement objects offer an iterator-style interface.
- Some DBIx-Squirrel iterator behaviours are analogous to behaviours exhibited by `DBIx::Class::ResultSet` objects. They have been given similar method names (`reset`, `first`, `next`, `single`, `find`, `all`) to remove any cognitive friction.
