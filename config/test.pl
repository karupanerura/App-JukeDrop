
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
        authorize_uri   => 'https://localhost',
        authorize_param => +{
            client_id     => 'DUMMY',
            response_type => 'token',
        },
    },
};
