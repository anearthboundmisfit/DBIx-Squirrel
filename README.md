<img src="./ekorn.png?raw=true" width="64" height="64" align="right">

# DBIx-Squirrel

A Perl 5 module for working with databases.

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
$res = $sth->bind( ':id'=>'1001099' );
$res = $sth->bind([':id'=>'1001099']);
$res = $sth->bind({':id'=>'1001099'});
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

# The database handle "do" method works as before, but it also
# returns the statement handle when called in list-context. So
# we can use it to prepare and execute statements, before we
# fetch results. Be careful to use "undef" if passing named
# parameters in a hashref so they are not used as statement
# attributes. The new "do" is smart enough not to confuse
# other things as statement attributes.
#
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = ?', '1001099'
);
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = ?', ['1001099']
);
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = :id', ':id'=>'1001099'
);
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = :id', id=>'1001099'
);
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = :id', [':id'=>'1001099']
);
($res, $sth) = $dbh->do(
  'SELECT * FROM product WHERE id = :id', [id=>'1001099']
);
($res, $sth) = $dbh->do( # ------------ undef or \%attr
  'SELECT * FROM product WHERE id = :id', undef,
  {':id'=>'1001099'}
);
($res, $sth) = $dbh->do( # ------------ undef or \%attr
  'SELECT * FROM product WHERE id = :id', undef,
  {id=>'1001099'},
);

# Using the iterators couldn't be easier!
#
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

# Result sets are just fancy iterators that "bless" results in
# a manner that enables us to get column values using accessor
# methods, without ever having to worry about whether the row
# is implemented as an arrayref or hashref. Accessors are not
# case-sensitive.
#
$sth = $dbh->prepare('SELECT MediaTypeId, Name FROM media_types');
$rs  = $sth->resultset;
while ($rs->next) {
  print $_->name, "\n";
}

# Use callbacks to declare how result set and iterator methods
# should transform, or otherwise process, rows prior to returning
# a result to the caller.
#
$it = $sth->it(
  sub { $_->{Name} }
)->reset({});
print "$_\n" foreach $it->all;

# Create callback chains, too.
#
$rs = $sth->rs(
  sub { $_->Name },
  sub { "Media type: $_" },
);
print "$_\n" while $rs->next;

print "$_\n" foreach $dbh->rs(
  'SELECT MediaTypeId, Name FROM media_types',
  sub { $_->Name },
  sub { "Media type: $_" },
)->all;
```

## Description
Just what the world needs: another Perl module for working with databases.

DBIx-Squirrel is a DBI extension. It subclasses the venerable DBI package (and other packages within that namespace), making a few enhancements to its ancestor's interface.

As someone who enjoys working with DBI (sometimes preferring it to heavyweight alternatives), I simply wanted a few small improvements to the user experience, without those improvements seeming too alien in nature.

### Design

#### Compatibility
A developer may confidently replace `use DBI` with `use DBIx::Squirrel` and expect a script to function as it did prior to the change. 

DBIx-Squirrel's enhancements are designed to be low-friction, intuitive (and above all), elective. Things should work as expected until our requirements change, and any deviation from the norm is expected.

In addition to a high degree of backward compatibility, interface-design has also been forward-looking. Where some DBIx-Squirrel concepts have analogs within DBIx-Class (another popular package), the same method names will implement any analogous behaviours.

#### Ease of use
DBIx-Squirrel's baseline behaviour is _be like DBI_. There is no barrier to using this module if you are familiar with the DBI, or its extensive documentation.

Pretty much all of DBIx-Squirrel's enhancements are progressive or additive in nature. For most experienced DBI and DBIx-Class developers, a cursory glance at the synopsis should be enough to get started.

### Features

#### Connecting to databases, and preparing statements
- The `connect` method continues to work as expected. It may also be invoked with a single argument (another database handle), if the intention is to clone that connection. This is particularly useful when cloning a standard DBI database object, since the resulting clone will be a DBI-Squirrel database object.

- The `prepare` and `prepare_cached` methods continue to work as expected, though passing a statement handle, instead of a statement in a string, results in that statement being cloned. Again, this is useful when the intention is to clone a standard DBI statement object in order to produce a DBIx-Squirrel statement object.

#### Parameter placeholders, bind values, and iterators
- Regardless of the database driver being used, DBIx-Squirrel provides baseline support for five parameter placeholder schemes (`?`, `?1`,  `$1`, `:1`, `:name`).
- A statement object's `bind_param` method will continue to work as expected, though its behaviour has been progressively enhanced. It now accommodates both `bind_param(':name', 'value')` and `bind_param('name', 'value')` calling styles, as well as the `bind_param(1, 'value')` style for positional placeholders.
- Statement objects have a new `bind` method aimed at greatly streamlining the binding of values to statement parameters.
- A statement object's `execute` method will accept any arguments you would pass to the `bind` method. It isn't really necessary to call `bind` because `execute` will take care of that.
- DBIx-Squirrel iterators make the traversal of result sets simple and efficient, and these can be generated by using a statement object's `iterate` method in place of `execute`, with both methods taking the same arguments.
- Some DBIx-Squirrel iterator behaviours are analogous to behaviours exhibited by `DBIx::Class::ResultSet` objects. They have been given similar method names (`reset`, `first`, `next`, `single`, `find`, `all`) to remove any cognitive friction.
