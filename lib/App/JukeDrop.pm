package App::JukeDrop;
use strict;
use warnings;
use utf8;
our $VERSION='0.01';
use 5.008001;

use AnyEvent::DBI;
use Class::Data::Lazy qw/dbh/;

use parent qw/Amon2/;
# Enable project local mode.
__PACKAGE__->make_local_context();

my $noop = sub {};
sub _build_dbh {
    my $class = shift;

    my $conf = $class->config->{DBI}
        or die "Missing configuration about DBI";

    my $dbh = AnyEvent::DBI->new(@$conf);
    $dbh->exec('SET NAMES utf8mb4', $noop);
    $dbh->exec('SET SESSION sql_mode=STRICT_TRANS_TABLES', $noop);
    return $dbh;
}

1;
__END__

=head1 NAME

App::JukeDrop - App::JukeDrop

=head1 DESCRIPTION

This is a main context class for App::JukeDrop

=head1 AUTHOR

App::JukeDrop authors.

