package App::JukeDrop::Web;
use strict;
use warnings;
use utf8;
use parent qw/App::JukeDrop Amon2::Web/;
use File::Spec;

use App::JukeDrop::Web::Request;
sub create_request { App::JukeDrop::Web::Request->new($_[1], __PACKAGE__) }

# dispatcher
use App::JukeDrop::Web::Dispatcher;
sub dispatch {
    return (App::JukeDrop::Web::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

# load plugins
__PACKAGE__->load_plugins(
    'Web::FillInFormLite',
    'Web::CSRFDefender',
    'Web::JSON',
    'Web::Streaming',
    '+App::JukeDrop::Web::Plugin::Session',
);

# setup view
use App::JukeDrop::Web::View;
{
    my $view = App::JukeDrop::Web::View->make_instance(__PACKAGE__);
    sub create_view { $view } # Class cache.
}

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

1;
