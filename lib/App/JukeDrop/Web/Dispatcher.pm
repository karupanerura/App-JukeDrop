package App::JukeDrop::Web::Dispatcher;
use strict;
use warnings;
use utf8;

use JSON 2 qw/decode_json/;
use URI;
use AnyEvent;
use AnyEvent::Util;
use AnyEvent::HTTP;
use Amon2::Web::Dispatcher::RouterBoom;

use App::JukeDrop::Model::User;

get '/' => sub {
    my ($c) = @_;
    my $user_id = $c->session->get('user_id');
    if ($user_id) {
        return $c->streaming(sub {
            my $respond = shift;

            App::JukeDrop::Model::User->fetch_by_id($user_id => sub {
                my $user = shift;
                $respond->(@{ $c->render('home.tx', +{ user => $user })->finalize });
            });
        });
    }
    else {
        return $c->render('index.tx', {});
    }
};

post '/login' => sub {
    my $c = shift;
    my $dropbox = $c->config->{Dropbox};

    my $state         = $c->get_csrf_defender_token;
    my $authorize_uri = URI->new($dropbox->{authorize_uri});
    my $redirect_uri  = do {
        my $uri = $c->req->base;
        $uri->scheme('https');
        $uri->path('/login/callback');
        $uri;
    };

    $authorize_uri->query_form(
        %{ $dropbox->{authorize_param} },
        redirect_uri  => $redirect_uri->as_string,
        state         => $state,
    );

    return $c->redirect($authorize_uri->as_string);
};

get '/login/callback' => sub {
    my $c = shift;
    if ($c->req->parameters->get('state') ne $c->get_csrf_defender_token) {
        return $c->res_403;
    }

    my $access_token = $c->req->parameters->get('access_token');
    my $token_type   = $c->req->parameters->get('token_type');
    my $uid          = $c->req->parameters->get('uid');

    my $session = $c->session;
    $session->set(auth_info => +{
        access_token => $access_token,
        token_type   => $token_type,
        uid          => $uid,
    });

    my $redirect_uri = do {
        my $uri = $c->req->base;
        $uri->scheme('https');
        $uri;
    };

    return $c->streaming(sub {
        my $respond = shift;

        App::JukeDrop::Model::User->fetch_by_uid($uid => sub {
            my $user = shift;

            if ($user) {
                $session->set(user_id => $user->{id});
                $respond->(302, [Location => $redirect_uri->as_string], []);
            }
            else {
                App::JukeDrop::Model::User->create($uid => sub {
                     $c->App::JukeDrop::Model::User->fetch_by_uid($uid => sub {
                         my $user = shift;
                         $session->set(user_id => $user->{id});
                         $respond->(302, [Location => $redirect_uri->as_string], []);
                     });
                });
            }
        });
    });
};

get '/play.mp3' => sub {
    my $c = shift;

    my $env = $c->req->env;

    my $authorization = sprintf q{OAuth %s}, $c->session->set('auth_info')->{access_token};

    my $user_id = $c->session->get('user_id');
    return $c->redirect('/') unless $user_id;
    return $c->streaming(sub {
        my $respond = shift;

        my $writer = $respond->([ 200, [ 'Content-Type' => 'audio/mpeg' ] ]);
        my $stream = App::JukeDrop::Web::Response::ContentStream->new($writer);
        App::JukeDrop::Model::User->fetch_by_id($user_id => sub {
            my $user = shift;

            my $root = 'Juke-Drop';
            my $path = '/';
            play($root, $path, $authorization, $stream);
        });
    });
};

sub play {
    my ($root, $path, $authorization, $stream) = @_;
    $path =~ s{^/}{};

    http_get "https://api.dropbox.com/1/metadata/${root}/${path}",
        Authorization => $authorization,
        sub {
            my ($json, $headers) = @_;
            my $data = decode_json $json;

            for my $content (@{ $data->{contents} }) {
                if ($content->{is_dir}) {
                    play($root, $content->{path}, $authorization, $stream);
                }
                else {
                    next unless $content->{path} =~ /\.mp3$/;

                    warn $content->{path};
                    my $writer = $stream->add($content->{path});
                    http_get "https://api-content.dropbox.com/1/files/${root}/$content->{path}",
                        Authorization => $authorization,
                        on_body => sub {
                            my ($data, $headers) = @_;

                            if ($headers->{Status} =~ /^2/) {
                                $writer->write($data);
                            }

                            return 1;
                        },
                        sub {
                            $writer->close();
                        };
                }
            }
        };
}

package App::JukeDrop::Web::Response::ContentStream {
    use AnyEvent;
    use AnyEvent::Handle;
    use AnyEvent::Util qw/fh_nonblocking/;
    use File::Temp qw/tempfile tempdir/;

    sub new {
        my ($class, $writer) = @_;

        return bless +{
            writer  => $writer,
            file    => +{},
            fh      => +{},
            tempdir => tempdir(CLEANUP => 1),
            current => undef,
            queue   => [],
        } => $class;
    }

    sub add {
        my ($self, $file) = @_;

        my $file_info = $self->{file}->{$file} //= +{
            writer     => App::JukeDrop::Web::Response::ContentStream::Writer->new($self, $file),
            position   => 0,
            is_closed  => 0,
            cache_file => do {
                my (undef, $file) = tempfile(UNLINK => 0, OPEN => 0, DIR => $self->{tempdir});
                $file;
            },
        };
        $self->{current} //= $file;
        push @{ $self->{queue} } => $file if $self->{current} ne $file;

        return $file_info->{writer};
    }

    sub write :method {
        my ($self, $file, $data) = @_;
        my $file_info = $self->{file}->{$file};
        return if $file_info->{is_closed};

        my $fh = $self->{fh}->{$file} //= do {
            open my $fh, '>', $file_info->{cache_file} or die $!;
            fh_nonblocking $fh, 1;
            $fh;
        };
        print $fh $data;

        my $current = $self->{current};
        if ($self->{current} eq $file) {
            $self->{writer}->write($data);
            $file_info->{position} += length $data;
        }
    }

    sub stream_from_current_cache {
        my $self = shift;

        my $file       = $self->{current};
        my $file_info  = $self->{file}->{$file};
        my $max_length = $file_info->{position};
        my $length     = 0;
        open my $fh, '<', $file_info->{cache_file};
        fh_nonblocking $fh, 1;
        my $w; $w = AnyEvent->io(
            fh   => $fh,
            poll => 'r',
            cb   => sub {
                sysread $fh, my $buf, 1024;
                $length += length $buf;
                $self->{writer}->write($buf);
                if ($length >= $max_length) {
                    close $fh;
                    undef $w;
                    $self->next_queue();
                }
            });
    }

    sub next_queue {
        my $self = shift;

        my $current = $self->{current} = pop @{ $self->{queue} };
        if ($current) {
            $self->stream_from_current_cache();
        }
        else {
            $self->{writer}->close();
        }
    }

    sub end {
        my ($self, $file) = @_;
        my $file_info = $self->{file}->{$file};
        $file_info->{is_closed} = 1;
        close $self->{fh}->{$file};

        if ($self->{current} eq $file) {
            $self->next_queue();
        }
    }
};

package App::JukeDrop::Web::Response::ContentStream::Writer {

    sub new {
        my ($class, $stream, $file) = @_;

        weaken($stream);
        return bless +{
            stream => $stream,
            file   => $file,
        } => $class;
    }

    sub write :method {
        my ($self, $data) = @_;
        $self->{stream}->write($self->{file} => $data);
    }

    sub close :method {
        my ($self) = @_;
        $self->{stream}->end($self->{file});
    }
}

1;
