
=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::db - DBI database handle (DBI::db) subclass

=head1 VERSION

2020.11.00

=head1 SYNOPSIS

    $rows = $dbh->do($statement);
    $rows = $dbh->do($statement, \%attr);
    $rows = $dbh->do($statement, @bind_values);
    $rows = $dbh->do($statement, \@bind_values);
    $rows = $dbh->do($statement, %bind_values);
    $rows = $dbh->do($statement, \%attr, @bind_values);
    $rows = $dbh->do($statement, \%attr, \@bind_values);
    $rows = $dbh->do($statement, \%attr, %bind_values);
    $rows = $dbh->do($statement, \%attr, \%bind_values);

    ($rows, $sth) = $dbh->do($statement);
    ($rows, $sth) = $dbh->do($statement, \%attr);
    ($rows, $sth) = $dbh->do($statement, @bind_values);
    ($rows, $sth) = $dbh->do($statement, \@bind_values);
    ($rows, $sth) = $dbh->do($statement, %bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, @bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, \@bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, %bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, \%bind_values);

    $sth = $dbh->prepare($statement);
    $sth = $dbh->prepare($statement, \%attr);

    $sth = $dbh->prepare_cached($statement);
    $sth = $dbh->prepare_cached($statement, \%attr);

    $itor = $dbh->iterate($statement);
    $itor = $dbh->iterate($statement, \%attr);
    $itor = $dbh->iterate($statement, @bind_values);
    $itor = $dbh->iterate($statement, \@bind_values);
    $itor = $dbh->iterate($statement, %bind_values);
    $itor = $dbh->iterate($statement, \%attr, @bind_values);
    $itor = $dbh->iterate($statement, \%attr, \@bind_values);
    $itor = $dbh->iterate($statement, \%attr, %bind_values);
    $itor = $dbh->iterate($statement, \%attr, \%bind_values);

    $rs = $dbh->resultset($statement);
    $rs = $dbh->resultset($statement, \%attr);
    $rs = $dbh->resultset($statement, @bind_values);
    $rs = $dbh->resultset($statement, \@bind_values);
    $rs = $dbh->resultset($statement, %bind_values);
    $rs = $dbh->resultset($statement, \%attr, @bind_values);
    $rs = $dbh->resultset($statement, \%attr, \@bind_values);
    $rs = $dbh->resultset($statement, \%attr, %bind_values);
    $rs = $dbh->resultset($statement, \%attr, \%bind_values);

=head1 DESCRIPTION

This module subclasses DBI's DBI::db module, providing a number of progressive
and additive enhancements to database handle objects:

=over

=item * statement and cached statement preparation;

=item * combined statement preparation and execution;

=item * the creation of result set iterators.

=back

=cut

use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::db;

BEGIN {
    @DBIx::Squirrel::db::ISA     = ( 'DBI::db' );
    *DBIx::Squirrel::db::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'blessed', 'reftype';
use SQL::Abstract;
use DBIx::Squirrel::util 'throw';
use DBIx::Squirrel::st;
use DBIx::Squirrel::results;

BEGIN {
    $DBIx::Squirrel::db::SQL_ABSTRACT = do {
        eval {
            require SQL::Abstract::More;
            SQL::Abstract::More->new;
        } or eval {
            require SQL::Abstract;
            SQL::Abstract->new;
        } or undef;
    };
}

use constant {
    E_EXP_STATEMENT => 'Expected a statement',
    E_EXP_STH       => 'Expected a statement handle',
    E_EXP_REF       => 'Expected a reference to a HASH or ARRAY',
};

our $SQL_ABSTRACT;

=head1 METHODS

=head2 select

=cut

sub select
{
    my $dbh = shift;
    my $sql = do {
        if (   ref $_[ -1 ]
            && blessed( $_[ -1 ] )
            && $_[ -1 ]->isa( 'SQL::Abstract' ) )
        {
            pop;
        } else {
            $SQL_ABSTRACT;
        }
    };
    my ( undef, $sth ) = $dbh->do( $sql->select( @_ ) );
    $sth;
}

=head2 do

=head3 Prepare and execute a statement

    $rows = $dbh->do($statement);
    $rows = $dbh->do($statement, \%attr);
    $rows = $dbh->do($statement, \%attr, @bind_values);

    $rows = $dbh->do($statement, @bind_values);
    $rows = $dbh->do($statement, \@bind_values);
    $rows = $dbh->do($statement, %bind_values);
    $rows = $dbh->do($statement, \%attr, \@bind_values);
    $rows = $dbh->do($statement, \%attr, %bind_values);
    $rows = $dbh->do($statement, \%attr, \%bind_values);
    $rows = $dbh->do($statement, undef, \%bind_values);

Prepares and executes a single statement, returning the number of rows affected
or undef on error. When called in Scalar Context, behaviour is not unlike that
of the DBI implementation method.

The DBIx-Squirrel implementation alows for a slightly richer variety of calling
styles, due to the greater number of bind value schemes supported.

=head3 Prepare and execute a statement, and return statement handle

    ($rows, $sth) = $dbh->do($statement);
    ($rows, $sth) = $dbh->do($statement, \%attr);
    ($rows, $sth) = $dbh->do($statement, @bind_values);
    ($rows, $sth) = $dbh->do($statement, \@bind_values);
    ($rows, $sth) = $dbh->do($statement, %bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, @bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, \@bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, %bind_values);
    ($rows, $sth) = $dbh->do($statement, \%attr, \%bind_values);
    ($rows, $sth) = $dbh->do($statement, undef, \%bind_values);

When called in List Context, both the number of rows affected and the prepared
statement's handle are returned in that order, making the C<do> method useful
for preparing and executing SELECT-queries.

=cut

sub do
{
    my $dbh       = shift;
    my $statement = shift;
    my ( $res, $sth );
    if ( @_ ) {
        if ( ref $_[ 0 ] ) {
            if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                if ( $sth = $dbh->prepare( $statement, shift ) ) {
                    $res = $sth->execute( @_ );
                }
            } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                if ( $sth = $dbh->prepare( $statement ) ) {
                    $res = $sth->execute( @_ );
                }
            } else {
                throw E_EXP_REF;
            }
        } else {
            if ( defined $_[ 0 ] ) {
                if ( $sth = $dbh->prepare( $statement ) ) {
                    $res = $sth->execute( @_ );
                }
            } else {
                if ( $sth = $dbh->prepare( $statement, shift ) ) {
                    $res = $sth->execute( @_ );
                }
            }
        }
    } else {
        if ( $sth = $dbh->prepare( $statement ) ) {
            $res = $sth->execute;
        }
    }
    wantarray ? ( $res, $sth ) : $res;
}

=head2 update

=cut

sub update
{
    my $dbh = shift;
    my $sql = do {
        if (   ref $_[ -1 ]
            && blessed( $_[ -1 ] )
            && $_[ -1 ]->isa( 'SQL::Abstract' ) )
        {
            pop;
        } else {
            $SQL_ABSTRACT;
        }
    };
    my ( $res, $sth ) = $dbh->do( $sql->update( @_ ) );
    wantarray ? ( $res, $sth ) : $res;
}

=head2 insert

=cut

sub insert
{
    my $dbh = shift;
    my $sql = do {
        if (   ref $_[ -1 ]
            && blessed( $_[ -1 ] )
            && $_[ -1 ]->isa( 'SQL::Abstract' ) )
        {
            pop;
        } else {
            $SQL_ABSTRACT;
        }
    };
    my ( $res, $sth ) = $dbh->do( $sql->insert( @_ ) );
    wantarray ? ( $res, $sth ) : $res;
}

=head2 delete

=cut

sub delete
{
    my $dbh = shift;
    my $sql = do {
        if (   ref $_[ -1 ]
            && blessed( $_[ -1 ] )
            && $_[ -1 ]->isa( 'SQL::Abstract' ) )
        {
            pop;
        } else {
            $SQL_ABSTRACT;
        }
    };
    my ( $res, $sth ) = $dbh->do( $sql->delete( @_ ) );
    wantarray ? ( $res, $sth ) : $res;
}

=head2 prepare

=head3 Prepare a statement for execution

    $sth = $dbh->prepare($statement);
    $sth = $dbh->prepare($statement, \%attr);

=cut

sub prepare
{
    my $dbh = shift;
    my ( $params, $std, $sql ) = _common_prepare_work( shift );
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare( $std, @_ );
        } else {
            $dbh->DBI::db::prepare( $sql, @_ );
        }
    };
    if ( $sth ) {
        bless( $sth, 'DBIx::Squirrel::st' )->_private( {
                sql    => $sql,
                std    => $std,
                params => $params,
            },
        );
    }
    $sth;
}

sub _common_prepare_work
{
    my ( $order, $std, $sql ) = do {
        my $statement = do {
            if ( blessed( $_[ 0 ] ) ) {
                if ( $_[ 0 ]->isa( 'DBIx::Squirrel::st' ) ) {
                    shift->_private->{ sql };
                } elsif ( $_[ 0 ]->isa( 'DBI::st' ) ) {
                    shift->{ Statement };
                } else {
                    throw E_EXP_STH;
                }
            } else {
                shift;
            }
        };
        ( _get_param_order( $statement ), $statement );
    };
    if ( length $std ) {
        ( $order, $std, $sql );
    } else {
        throw E_EXP_STATEMENT;
    }
}

sub _get_param_order
{
    my $sql   = shift;
    my $order = do {
        my %order;
        if ( $sql ) {
            $sql =~ s{\s+\Z}{}s;
            $sql =~ s{\A\s+}{}s;
            my @params = $sql =~ m{[\:\$\?]\w+\b}g;
            if ( my $count = @params ) {
                $sql =~ s{[\:\$\?]\w+\b}{?}g;
                for ( my $p = 0 ; $p < $count ; $p += 1 ) {
                    $order{ 1 + $p } = $params[ $p ];
                }
            }
        }
        %order ? \%order : undef;
    };
    wantarray ? ( $order, $sql ) : $order;
}

=head2 prepare_cached

    $sth = $dbh->prepare_cached($statement);
    $sth = $dbh->prepare_cached($statement, \%attr);
    $sth = $dbh->prepare_cached($original_sth);
    $sth = $dbh->prepare_cached($original_sth, \%attr);

=cut

sub prepare_cached
{
    my $dbh = shift;
    my ( $params, $std, $sql ) = _common_prepare_work( shift );
    my $sth = do {
        if ( $DBIx::Squirrel::NORMALISED_STATEMENTS ) {
            $dbh->DBI::db::prepare_cached( $std, @_ );
        } else {
            $dbh->DBI::db::prepare_cached( $sql, @_ );
        }
    };
    if ( $sth ) {
        bless( $sth, 'DBIx::Squirrel::st' )->_private( {
                cache_key => join( '#', ( caller 0 )[ 1, 2 ] ),
                sql       => $sql,
                std       => $std,
                params    => $params,
            }
        );
    }
    $sth;
}

=head2 iterate

    $itor = $dbh->iterate($statement);
    $itor = $dbh->iterate($statement, \%attr);
    $itor = $dbh->iterate($statement, @bind_values);
    $itor = $dbh->iterate($statement, \@bind_values);
    $itor = $dbh->iterate($statement, %bind_values);
    $itor = $dbh->iterate($statement, \%attr, @bind_values);
    $itor = $dbh->iterate($statement, \%attr, \@bind_values);
    $itor = $dbh->iterate($statement, \%attr, %bind_values);
    $itor = $dbh->iterate($statement, \%attr, \%bind_values);

=cut

sub iterate
{
    my $dbh       = shift;
    my $statement = shift;
    $_ = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] ) {
                if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->iterate( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'CODE' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } else {
                    throw E_EXP_REF;
                }
            } else {
                if ( defined $_[ 0 ] ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->iterate( @_ );
                    }
                } else {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->iterate( @_ );
                    }
                }
            }
        } else {
            if ( my $sth = $dbh->prepare( $statement ) ) {
                $sth->iterate;
            }
        }
    };
}

=head2 it

An alias for C<iterate>

=cut

BEGIN { *it = *iterate }

=head2 resultset

    $rs = $dbh->resultset($statement);
    $rs = $dbh->resultset($statement, \%attr);
    $rs = $dbh->resultset($statement, @bind_values);
    $rs = $dbh->resultset($statement, \@bind_values);
    $rs = $dbh->resultset($statement, %bind_values);
    $rs = $dbh->resultset($statement, \%attr, @bind_values);
    $rs = $dbh->resultset($statement, \%attr, \@bind_values);
    $rs = $dbh->resultset($statement, \%attr, %bind_values);
    $rs = $dbh->resultset($statement, \%attr, \%bind_values);

=cut

sub resultset
{
    my $dbh       = shift;
    my $statement = shift;
    $_ = do {
        if ( @_ ) {
            if ( ref $_[ 0 ] ) {
                if ( reftype( $_[ 0 ] ) eq 'HASH' ) {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->resultset( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'ARRAY' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } elsif ( reftype( $_[ 0 ] ) eq 'CODE' ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } else {
                    throw E_EXP_REF;
                }
            } else {
                if ( defined $_[ 0 ] ) {
                    if ( my $sth = $dbh->prepare( $statement ) ) {
                        $sth->resultset( @_ );
                    }
                } else {
                    if ( my $sth = $dbh->prepare( $statement, shift ) ) {
                        $sth->resultset( @_ );
                    }
                }
            }
        } else {
            if ( my $sth = $dbh->prepare( $statement ) ) {
                $sth->resultset;
            }
        }
    };
}

=head2 result_set

An alias for C<resultset>

=cut

BEGIN { *result_set = *resultset }

=head2 rs

An alias for C<resultset>

=cut

BEGIN { *rs = *resultset }

1;

__END__

=head1 AUTHOR

I Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
