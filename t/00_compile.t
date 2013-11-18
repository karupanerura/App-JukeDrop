use strict;
use warnings;
use Test::More;


use App::JukeDrop;
use App::JukeDrop::Web;
use App::JukeDrop::Web::View;
use App::JukeDrop::Web::ViewFunctions;

use App::JukeDrop::DB::Schema;
use App::JukeDrop::Web::Dispatcher;


pass "All modules can load.";

done_testing;
