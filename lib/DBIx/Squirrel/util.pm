use strict;
use warnings;

package    # hide from PAUSE
  DBIx::Squirrel::util;

BEGIN {
    require Exporter;
    @DBIx::Squirrel::util::ISA         = ( 'Exporter' );
    *DBIx::Squirrel::util::VERSION     = *DBIx::Squirrel::VERSION;
    %DBIx::Squirrel::util::EXPORT_TAGS = (
        all => [
            qw/
              Dumper
              throw
              whine
              /
        ]
    );
    @DBIx::Squirrel::util::EXPORT_OK
      = @{ $DBIx::Squirrel::util::EXPORT_TAGS{ all } };
}

use Carp;
use Data::Dumper::Concise;

sub throw
{
    @_ = do {
        if ( @_ ) {
            if ( @_ > 1 ) {
                if ( my $format = shift ) {
                    sprintf( $format, @_ );
                } else {
                    join( '', map { $_ // '' } @_ );
                }
            } else {
                shift || 'This script is pining for the fjords';
            }
        } else {
            $@ || $_ || 'This script is pining for the fjords';
        }
    };
    goto &Carp::confess;
}

sub whine
{
    @_ = do {
        if ( @_ ) {
            if ( @_ > 1 ) {
                if ( my $format = shift ) {
                    sprintf( $format, @_ );
                } else {
                    join( '', map { $_ // '' } @_ );
                }
            } else {
                shift || 'Careful now';
            }
        } else {
            $@ || $_ || 'Careful now';
        }
    };
    goto &Carp::cluck;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Squirrel::util - exports tools used by DBIx-Squirrel modules

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
