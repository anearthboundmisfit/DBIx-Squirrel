use strict;
use warnings;

package DBIx::Squirrel::ResultSet;

BEGIN {
    @DBIx::Squirrel::ResultSet::ISA     = ( 'DBIx::Squirrel::itor' );
    *DBIx::Squirrel::ResultSet::VERSION = *DBIx::Squirrel::VERSION;
}

use namespace::autoclean;
use Scalar::Util 'reftype', 'weaken';
use Sub::Name 'subname';
use DBIx::Squirrel::itor;
use DBIx::Squirrel::result;

sub DESTROY
{ ## no critic (TestingAndDebugging::ProhibitNoStrict)
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    local ( $., $@, $!, $^E, $?, $_ );
    my ( $id, $self ) = shift->_id;
    my $class = $self->resultclass;
    no strict 'refs';
    undef &{ "$class\::resultset" };
    $self->SUPER::DESTROY;
} ## use critic

sub class { ref $_[ 0 ] ? ref $_[ 0 ] : $_[ 0 ] }

sub resultclass { 'DBIx::Squirrel::result' }

sub rowclass
{
    my $class = sprintf 'Row_0x%x', 0+ $_[ 0 ];
    wantarray ? ( $class, $_[ 0 ] ) : $class;
}

sub _get_row {
    $_ = do {
        my ( $p, $self ) = shift->_private;
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            $self->charge_buffer if $self->buffer_is_empty;
            if ( $self->buffer_is_still_empty ) {
                $p->{ fi } = 1;
                undef;
            } else {
                $p->{ rc } += 1;
                if ( $self->has_callbacks ) {
                    $self->transform( $self->_bless( shift @{ $p->{ bu } } ) );
                } else {
                    shift @{ $p->{ bu } };
                }
            }
        }
    };
}

sub _bless
{ ## no critic (TestingAndDebugging::ProhibitNoStrict)
    my ( $rowclass, $self ) = shift->rowclass;
    if ( ref $_[ 0 ] ) {
        my $resultclass = $self->resultclass;
        unless ( defined &{ $rowclass . '::resultset' } ) {
            no strict 'refs';
            undef &{ "$rowclass\::resultset" };
            *{ "$rowclass\::resultset" } = do {
                weaken( my $rs = $self );
                subname( "$rowclass\::resultset", sub { $rs } );
            };
            undef &{ "$rowclass\::rs" };
            *{ "$rowclass\::rs" }  = *{ "$rowclass\::resultset" };
            @{ "$rowclass\::ISA" } = ( $resultclass );
        }
        $rowclass->new( $_[ 0 ] );
    } else {
        undef;
    }
} ## use critic

sub remaining
{
    my ( $p, $self ) = shift->_private;
    $_ = do {
        if ( $p->{ fi } || ( !$p->{ ex } && !$self->execute ) ) {
            undef;
        } else {
            while ( $self->charge_buffer ) { ; }
            my $rowclass = $self->rowclass;
            my $rows     = do {
                if ( $self->has_callbacks ) {
                    [
                        map { $self->transform( $self->_bless( $_ ) ) } (
                            @{ $p->{ bu } },
                        ),
                    ];
                } else {
                    [ map { $self->_bless( $_ ) } @{ $p->{ bu } } ];
                }
            };
            $p->{ rc } = $p->{ rf };
            $p->{ bu } = undef;
            $self->reset;
            $rows;
        }
    };
    wantarray ? @{ $_ } : $_;
}

BEGIN {
    *rc           = *resultclass;
    *result_class = *resultclass;
    *row_class    = *rowclass;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::ResultSet - DBIx-Squirrel result set iterator class

=head1 VERSION

2020.11.00

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

I Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by I Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
