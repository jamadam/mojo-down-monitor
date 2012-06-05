package MojoDownMonitor::Sites;
use strict;
use warnings;
use DBI;
use base 'MojoDownMonitor::SitesBase';
use Data::Dumper;
use feature q/:5.10/;
    
    my $json_parser = Mojo::JSON->new;
    
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
    "Site name" VARCHAR,
    "Max log" INTEGER NOT NULL DEFAULT (50),
    "Connect timeout" INTEGER DEFAULT (10),
    "Body size must be" INTEGER,
    "User Agent" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name", "Site name") VALUES ('', '10', 'http://example.com', '', 'text/html', '301', 'a\@example.com,b\@example.com', 'example.com', 50);
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name", "Site name") VALUES ('', '10', 'http://google.co.jp', '', '', '200', 'a\@example.com,b\@example.com', 'google', 50);
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name", "Site name") VALUES ('', '60', 'http://github.com', '', 'text/html; charset=utf-8', '200', 'a\@example.com,b\@example.com', 'github', 50);
EOF
    }
    
    sub validate_form {
        my ($self) = @_;
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        my $params = $tx->req->body_params;
        my $cid_data = $self->cid_table;
        given ($params->param('mode')) {
            when ($_ ~~ ['update','create']) {
                if (! $cid_data->{'Site name'}) {
                    $self->user_err->stack('Site name is required');
                }
                if (! $cid_data->{'Interval'} || $cid_data->{'Interval'} =~ /\D+/) {
                    $self->user_err->stack('Interval must be a digit');
                }
                if (! $cid_data->{'URI'}) {
                    $self->user_err->stack('URI is required');
                }
            }
            when ('delete') {
                
            }
        }
    }
    
    sub delete {
        my ($self, $where_seed) = @_;
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        $where_seed ||= $tx->req->param('where');
        my $where_hash =
            ref $where_seed ? $where_seed : $json_parser->decode($where_seed);
        $self->controller->app->mdm_log->delete({'Site id' => $where_hash->{id}});
        $self->SUPER::delete($where_seed);
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
