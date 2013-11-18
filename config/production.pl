+{
    'DBI' => [
        'DBI:mysql:database=drop_juke;host=127.0.0.1', 'drop_juke', '',
        +{
            RaiseError          => 1,
            PrintError          => 0,
            ShowErrorStatement  => 1,
            AutoInactiveDestroy => 1,
            mysql_enable_utf8   => 1,
        }
    ],
    'Dropbox' => +{
        authorize_uri   => 'https://www.dropbox.com/1/oauth2/authorize',
        authorize_param => +{
            client_id     => 'm6fi22a1482uthc',
            response_type => 'token',
        },
    },
};
