package MojoDownMonitor::Log;
use strict;
use warnings;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use DBI;
use base 'MojoDownMonitor::SitesBase';
use Data::Dumper;

    __PACKAGE__->attr('max_log', 1000);
    
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
        
        $dbh->do(<<'EOF') or die $dbh->errstr;
CREATE TABLE IF NOT EXISTS "log" (
    "id" INTEGER PRIMARY KEY  NOT NULL ,
    "Site id" VARCHAR,
    "OK" BOOL NOT NULL ,
    "Error" TEXT,
    "timestamp" DATETIME DEFAULT (datetime('now','localtime')),
    "Response time" REAL
)
EOF
        $self->table('log');
    }
    
    sub create {
        my $self = shift;
        $self->dbh->begin_work;
        $self->SUPER::create(@_);
        $self->vacuum($self->max_log);
        $self->dbh->commit;
    }
    
    ### ---
    ### limit logs number into max_log
    ### DELETE FROM log WHERE id IN (select id  FROM log WHERE "Site id" = 4 ORDER BY id LIMIT -1 OFFSET 400);
    ### ---
    sub vacuum {
        my ($self, $max, $site_id) = @_;
        my $sql = SQL::OOP::Delete->new();
        $sql->set(
            $sql->ARG_TABLE => SQL::OOP::ID->new($self->table),
            $sql->ARG_WHERE => sub {
                my $sub = SQL::OOP::Select->new;
                $sub->set(
                    $sub->ARG_FIELDS    => 'id',
                    $sub->ARG_FROM      => 'log',
                    $sub->ARG_WHERE     => SQL::OOP::Where->cmp('=', 'Site id', $site_id),
                    $sub->ARG_ORDERBY   => SQL::OOP::Order->new_desc('id'),
                    $sub->ARG_LIMIT     => -1,
                    $sub->ARG_OFFSET    => $max || $self->max_log,
                );
                return SQL::OOP::Where->in('id', $sub);
            }
        );
        my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
    }

1;

__END__

=head1 NAME MojoDownMonitor::Log

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
