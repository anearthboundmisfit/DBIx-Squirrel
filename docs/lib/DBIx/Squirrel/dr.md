# NAME

DBIx::Squirrel::dr - DBI database driver (DBI::dr) subclass

# VERSION

2020.11.00

# SYNOPSIS

    # ADDITIONS AND ENHANCEMENTS TO STANDARD DBI BEHAVIOURS

    # New "connect_clone" method. Standard DBI connections may also be cloned
    # and upgraded.
    $dbh = DBIx::Squirrel->connect_clone($other_dbh, \%attr);

    # Additional way to use the "connect" method. Standard DBI connections may
    # also be cloned and upgraded.
    $dbh = DBIx::Squirrel->connect($other_dbh, \%attr);

# DESCRIPTION

This module subclasses DBI's DBI::dr module to provide a new way to connect to
databases using database session handles.

# METHODS

## connect\_clone

### Clone a database session

    $clone_dbh = DBI::Squirrel->connect_clone($original_dbh, \%attr);

Use this method to clone another database session as a DBIx-Squirrel database
session. Cloning and connecting to a standard DBI::db session would allow the
clone to make use of DBIx-Squirrel's features.

The attributes for the cloned session are the same as those used for the
original session, with any other attributes in `\%attr` merged over
them.

## connect\_cached

### Connect to a data source (possibly recycling a connection)

    $dbh = DBI->connect_cached($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;

Like `connect`, except that the database handle returned is also stored in a
hash associated with the given parameters. If another call is made to the same
data source with the same parameter values, then the corresponding cached
database handle will be returned if it is still valid. The cached database
handle is replaced with a new connection if it has been disconnected, or if
the ping method fails.

For more detailed information about this method, please refer to the [DBI](https://metacpan.org/pod/DBI)
documentation.

## connect

### Clone a database session

    $clone_dbh = DBI::Squirrel->connect($original_dbh, \%attr);

Invoke `connect` this way to clone another database session as a DBIx-Squirrel
database session. Cloning and connecting to a standard DBI::db session would
allow the clone to make use of DBIx-Squirrel's features.

The attributes for the cloned session are the same as those used for the
original session, with any other attributes in `\%attr` merged over
them.

### Connect to a data source

    $dbh = DBI->connect_cached($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;

Establishes a database connection, or session, to the requested `$data_source`,
returning a database handle if the connection succeeds.

For more detailed information about this method, please refer to the [DBI](https://metacpan.org/pod/DBI)
documentation.

# AUTHOR

I Campbell <cpanic@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
