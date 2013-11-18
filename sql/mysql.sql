CREATE TABLE IF NOT EXISTS user (
    id        INTEGER                      NOT NULL PRIMARY KEY AUTO_INCREMENT,
    uid       VARCHAR(255) CHARSET ascii   NOT NULL,
    UNIQUE INDEX (uid)
);
