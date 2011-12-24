package MojoDownMonitor::SMTP;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use DBI;
use base 'MojoDownMonitor::DB';
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
        $self->table('smtp');
        my $table = $self->table;
        
        $dbh->do(<<"EOF") or die $dbh->errstr;
CREATE TABLE IF NOT EXISTS $table (
    "host" VARCHAR PRIMARY KEY DEFAULT localhost,
    "port" INTEGER NOT NULL DEFAULT 25,
    "ssl" BOOL NOT NULL DEFAULT 0,
    "user" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table (rowid) VALUES (NULL);
EOF
    }

1;

__END__

=head1 NAME MojoDownMonitor::DB

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
