package MojoX::Tusu::Component::SQLite;
use strict;
use warnings;
use utf8;
use base 'MojoX::Tusu::Component::DB';

    ### ---
    ### get table information
    ### ---
    sub get_table_structure {
        my ($self) = @_;
        if (! $self->table_structure) {
            my $table = $self->table;
            my $sql = qq{PRAGMA table_info ("$table")};
            my $sth = $self->dbh->prepare($sql) or die $DBI::errstr;
            my %ret = ();
            
            $sth->execute();
            
            while (my $res = $sth->fetchrow_hashref) {
                $ret{$res->{name}} = {
                    cid     => $res->{cid},
                    type    => $res->{type},
                };
            }
            $self->table_structure(\%ret);
        }
        return $self->table_structure;
    }
    
    ### ---
    ### timestamp of sqlite file
    ### ---
    sub get_timestamp {
        my $self = shift;
        my $file = File::Spec->catfile($self->db_name);
        if (-e $file) {
            return (stat($file))[9];
        }
    }
    
    ### ---
    ### get last inserted rowid
    ### ---
    sub last_insert_rowid {
        my $self = shift;
        my $sth = $self->dbh->prepare('SELECT last_insert_rowid() as curval')
            or die $DBI::errstr;
        my $count_view = $sth->execute();
        return $sth->fetchrow_hashref->{curval};
    }
    
    ### ---
    ### check if table exists
    ### ---
    sub table_exists {
        my ($self, $dbh, $table) = @_;
        return $dbh->selectrow_array(<<EOF);
SELECT
    tbl_name
FROM
    main.sqlite_master
WHERE
    type = 'table'
    AND
    tbl_name = '$table';
EOF
    }
    
    ### ---
    ### true value for sql statement
    ### ---
    sub true_for_sql_statement {
        return '1';
    }
    
    ### ---
    ### true value for sql statement
    ### ---
    sub false_for_sql_statement {
        return '0';
    }

1;

__END__

=head1 NAME MojoDownMonitor::SQLite

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
