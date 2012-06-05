package MojoDownMonitor::SMTP;
use strict;
use warnings;
use DBI;
use base 'MojoDownMonitor::SitesBase';
use Data::Dumper;
    
    sub init {
        my ($self, $app) = @_;
        my $file = './mojo-down-monitor.sqlite';
        my $dbh = DBI->connect_cached("DBI:SQLite:dbname=$file",
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
    "id" INTEGER PRIMARY KEY  NOT NULL ,
    "host" VARCHAR DEFAULT localhost,
    "port" INTEGER NOT NULL DEFAULT 25,
    "ssl" BOOL NOT NULL DEFAULT 0,
    "user" VARCHAR,
    "password" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table (id) VALUES (NULL);
EOF
    }
    
    sub server_info {
        my $self = shift;
        return ($self->fetch(
            where   => {id => 1},
            fields  => ['host','port','ssl','user', 'password']
        ))[0];
    }
    
    sub validate_form {
        my ($self) = @_;
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        my $params = $tx->req->body_params;
        my $cid_data = $self->cid_table;
        my $mode = $params->param('mode');
        if ($mode eq 'update' || $mode eq 'create') {
            if (! $cid_data->{'host'}) {
                $self->user_err->stack('Host name is required');
            }
        }
    }

1;

__END__

=head1 NAME MojoDownMonitor::SMTP

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
