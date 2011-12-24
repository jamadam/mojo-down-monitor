package MojoDownMonitor::Sites;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use DBI;
use base 'MojoDownMonitor::SQLite';
use Data::Dumper;
    
    sub init {
        my ($self, $app) = @_;
        my $file = $app->home->rel_file('data/sites.sqlite');
        my $dbh = DBI->connect("DBI:SQLite:dbname=$file",
            undef, undef, {
                AutoCommit      => 1,
                RaiseError      => 1,
                sqlite_unicode  => 1,
                sqlite_allow_multiple_statements => 1,
            }
        ) or die 'Connect to SQLite file '. $file. ' failed';
        
        $self->dbh($dbh);
        $self->table('sites');
        my $table = $self->table;
        
        $dbh->do(<<"EOF") or die $dbh->errstr;
CREATE TABLE IF NOT EXISTS $table (
    "id" INTEGER PRIMARY KEY  NOT NULL ,
    "URI" VARCHAR NOT NULL ,
    "Interval" INTEGER NOT NULL  DEFAULT (3600) ,
    "Mail to" VARCHAR,
    "Status must be" VARCHAR DEFAULT (200) ,
    "MIME type must be" VARCHAR,
    "Content must match" VARCHAR,
    "HTTP header must match" VARCHAR,
    "Site name" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '10', 'http://example.com', '', 'text/html', '301', 'a\@example.com,b\@example.com', 'example.com');
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '10', 'http://google.co.jp', '', '', '200', 'a\@example.com,b\@example.com', 'google');
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '60', 'http://github.com', '', 'text/html; charset=utf-8', '200', 'a\@example.com,b\@example.com', 'github');
EOF
    }

1;

__END__

=head1 NAME MojoDownMonitor::Sites

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
