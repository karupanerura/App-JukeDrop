package App::JukeDrop::Model::User;
use strict;
use warnings;
use utf8;
use feature qw/state/;

use App::JukeDrop;
sub c() { App::JukeDrop->context } ## no critic
my $noop = sub {};

use Data::Validator;

sub create {
    state $v = Data::Validator->new(
        uid => 'Str',
        cb  => 'CodeRef',
    )->with(qw/Method StrictSequenced/);
    my ($class, $args) = $v->validate(@_);

    c->dbh->exec('INSERT INTO user (uid) VALUES (?)', $args->{uid}, $args->{cb});
}

sub fetch_by_id {
    state $v = Data::Validator->new(
        id => 'Int',
        cb => 'CodeRef',
    )->with(qw/Method StrictSequenced/);
    my ($class, $args) = $v->validate(@_);

    c->dbh->exec('SELECT * FROM user WHERE id = ? LIMIT 1', $args->{id}, sub {
        my ($dbh, $rows, $rv) = @_;
        $args->{cb}->($rows->[0]);
    });
}

sub search_by_ids {
    state $v = Data::Validator->new(
        ids => 'ArrayRef[Int]',
        cb  => 'CodeRef',
    )->with(qw/Method StrictSequenced/);
    my ($class, $args) = $v->validate(@_);

    my $sql = 'SELECT * FROM user WHERE id IN ('
        . join(',', ('?') x scalar(@{ $args->{ids} }))
        . ')';

    c->dbh->exec($sql, @{ $args->{ids} }, sub {
        my ($dbh, $rows, $rv) = @_;
        $args->{cb}->($rows);
    });
}

sub fetch_by_uid {
    state $v = Data::Validator->new(
        uid => 'Str',
        cb  => 'CodeRef',
    )->with(qw/Method StrictSequenced/);
    my ($class, $args) = $v->validate(@_);

    c->dbh->exec('SELECT * FROM user WHERE uid = ? LIMIT 1', $args->{uid}, sub {
        my ($dbh, $rows, $rv) = @_;
        $args->{cb}->($rows->[0]);
    });
}

1;
__END__
