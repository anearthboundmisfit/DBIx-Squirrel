=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::dr - DBI database driver (DBI::dr) subclass

=head1 VERSION

2020.11.00

=head1 SYNOPSIS

    # Use the traditional methods to connect to datasources using connection
    # parameters.
    $dbh = DBI->connect($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;

    # New "connect_clone" method. Standard DBI connections may also be cloned
    # and upgraded.
    $dbh = DBIx::Squirrel->connect_clone($other_dbh, \%attr);

    # Additional way to use the "connect" method. Standard DBI connections may
    # also be cloned and upgraded.
    $dbh = DBIx::Squirrel->connect($other_dbh, \%attr);

=head1 DESCRIPTION

This module subclasses DBI's DBI::dr module to provide a new way to connect to
databases using database session handles.

=head1 METHODS

=cut

use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::dr;

BEGIN {
    @DBIx::Squirrel::dr::ISA     = ( 'DBI::dr' );
    *DBIx::Squirrel::dr::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use DBI;
use Scalar::Util 'blessed';
use DBIx::Squirrel::db;

=head2 connect_clone

=head3 Clone a database session

    $clone_dbh = DBI::Squirrel->connect_clone($original_dbh);
    $clone_dbh = DBI::Squirrel->connect_clone($original_dbh, \%attr);

Use this method to clone another database session as a DBIx-Squirrel database
session. Cloning and connecting to a standard DBI::db session would allow the
clone to make use of DBIx-Squirrel's features.

The attributes for the cloned session are the same as those used for the
original session, with any other attributes in C<\%attr> merged over
them.

=cut

sub connect_clone
{
    my ( $package, $dbh, $attr ) = @_;
    if ( my $clone = $attr ? $dbh->clone( $attr ) : $dbh->clone ) {
        bless $clone, 'DBIx::Squirrel::db';
    } else {
        undef;
    }
}

=head2 connect_cached

=head3 Connect to a data source (possibly recycling a connection)

    $dbh = DBI->connect_cached($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;

Like C<connect>, except that the database handle returned is also stored in a
hash associated with the given parameters. If another call is made to the same
data source with the same parameter values, then the corresponding cached
database handle will be returned if it is still valid. The cached database
handle is replaced with a new connection if it has been disconnected, or if
the ping method fails.

For more detailed information about this method, please refer to the L<DBI>
documentation.

=cut

sub connect_cached
{
    if ( my $handle = shift->DBI::connect_cached( @_ ) ) {
        bless $handle, 'DBIx::Squirrel::db';
    } else {
        undef;
    }
}

sub _is_db_handle
{
    if ( ref $_[ 0 ] ) {
        if ( my $blessed = blessed( $_[ 0 ] ) ) {
            if ( $_[ 0 ]->isa( 'DBI::db' ) ) {
                $blessed;
            } else {
                undef;
            }
        } else {
            undef;
        }
    } else {
        undef;
    }
}

=head2 connect

=head3 Clone a database session

    $clone_dbh = DBI::Squirrel->connect($original_dbh);
    $clone_dbh = DBI::Squirrel->connect($original_dbh, \%attr);

Invoke C<connect> this way to clone another database session as a DBIx-Squirrel
database session. Cloning and connecting to a standard DBI::db session would
allow the clone to make use of DBIx-Squirrel's features.

The attributes for the cloned session are the same as those used for the
original session, with any other attributes in C<\%attr> merged over
them.

=head3 Connect to a data source

    $dbh = DBI->connect_cached($data_source, $username, $password)
      or die $DBI::Squirrel::errstr;
    $dbh = DBI->connect_cached($data_source, $username, $password, \%attr)
      or die $DBI::Squirrel::errstr;

Establishes a database connection, or session, to the requested C<$data_source>,
returning a database handle if the connection succeeds.

For more detailed information about this method, please refer to the L<DBI>
documentation.

=cut

sub connect
{
    if ( @_ > 1 && _is_db_handle( $_[ 1 ] ) ) {
        goto &connect_clone;
    } else {
        if ( my $handle = shift->DBI::connect( @_ ) ) {
            bless $handle, 'DBIx::Squirrel::db';
        } else {
            undef;
        }
    }
}

1;

__END__

=head1 AUTHOR

I Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
