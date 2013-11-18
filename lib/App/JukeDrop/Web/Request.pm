package App::JukeDrop::Web::Request;
use strict;
use warnings;
use utf8;

use parent qw/Amon2::Web::Request/;

sub base {
    my $self = shift;
    $self->{_base} ||= $self->SUPER::base();
    return $self->{_base}->clone;
}

sub uri {
    my $self = shift;
    $self->{_uri} ||= $self->SUPER::uri();
    return $self->{_uri}->clone;
}

1;
__END__
