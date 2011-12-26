package MojoDownMonitor::Log;
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

    __PACKAGE__->attr('max_log', 50);
    
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
        
        $dbh->do(<<'EOF') or die $dbh->errstr;
CREATE TABLE IF NOT EXISTS "log" (
    "id" INTEGER PRIMARY KEY  NOT NULL ,
    "Site id" VARCHAR,
    "OK" BOOL NOT NULL ,
    "Error" TEXT,
    "timestamp" DATETIME DEFAULT (datetime('now','localtime'))
)
EOF
        $self->table('log');
    }
    
    sub create {
        my $self = shift;
        $self->SUPER::create(@_);
        $self->vacuum();
    }
    
    ### ---
    ### limit logs number into max_log
    ### ---
    sub vacuum {
        my ($self) = @_;
        my $sql = SQL::OOP::Delete->new();
        $sql->set(
            $sql->ARG_TABLE => SQL::OOP::ID->new($self->table),
            $sql->ARG_WHERE => SQL::OOP::Where->cmp('<=', 'id', sub {
                my $sub = SQL::OOP::Select->new;
                return $sub->set(
                    $sub->ARG_FIELDS    => 'max(id) - '. $self->max_log,
                    $sub->ARG_FROM      => SQL::OOP::ID->new($self->table),
                );
            }),
        );
        my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
    }
    
    sub loop : TplExport {
        my ($self, $fields, $id) = @_;
        my $where = SQL::OOP::Where->cmp('=', 'Site id', $id);
        $self->SUPER::loop($fields, $where);
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
