package MojoDownMonitor::DB;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use DBI;
use base 'MojoX::Tusu::ComponentBase';
use Data::Dumper;

    __PACKAGE__->attr('table');
    __PACKAGE__->attr('dbh');
    
    sub unemptify {
        my ($self, $sql) = @_;
        my $table = $self->table;
        my $count = $self->dbh->selectall_arrayref(<<"EOF")->[0]->[0];
SELECT count(*) FROM $table;
EOF
        
        if (! $count) {
            $self->dbh->do($sql);
        }
    }
    
    sub store {
        my ($self, $record) = @_;
        my $sql = SQL::OOP::Insert->new;
        $sql->set(
            $sql->ARG_TABLE     => SQL::OOP::ID->new('log'),
            $sql->ARG_DATASET   => SQL::OOP::Dataset->new($record),
        );
        my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
    }
    
    sub dump {
        my ($self) = @_;
        my $select = SQL::OOP::Select->new;
        $select->set(
            $select->ARG_FIELDS => '*',
            $select->ARG_FROM   => $self->table,
        );
        my $dbh = $self->dbh;
        my $sth = $dbh->prepare($select->to_string) or die $dbh->errstr;
        $sth->execute($select->bind) or die $sth->errstr;
        return $sth;
    }
    
    sub loop : TplExport {
        my ($self, $fields) = @_;
        my $template = Text::PSTemplate::get_block(0);
        my $sth = $self->dump;
        my $out = '';
        while (my $result = $sth->fetchrow_hashref) {
            my $tpl = Text::PSTemplate->new();
            my $num = 0;
            for my $key (@$fields) {
                $tpl->set_var($num++ => $result->{$key} || '');
            }
            $out .= $tpl->parse_str($template);
        }
        return $out;
    }
    
    sub load_record {
        my ($self, $fields, $id) = @_;
        my $select = SQL::OOP::Select->new();
        $select->set(
            $select->ARG_FIELDS => SQL::OOP::IDArray->new(@{$fields}),
            $select->ARG_FROM   => SQL::OOP::ID->new($self->table),
            $select->ARG_WHERE  => SQL::OOP::Where->cmp('=', 'id', $id),
        );
        my $dbh = $self->dbh;
        my $sth = $dbh->prepare($select->to_string) or die $dbh->errstr;
        $sth->execute($select->bind) or die $sth->errstr;
        return $sth->fetchrow_hashref();
    }
    
    ### ---
    ### load record data into template
    ### ---
    sub load : TplExport {
        my ($self, $fields, $id, $assign_to) = @_;
        my $template = Text::PSTemplate::get_current_parser;
        my $data = $self->load_record($fields, $id);
        my $table_structure = $self->get_table_structure;
        my @a = map {
            MojoDownMonitor::DB::Column->new(
                $_,
                $data->{$_},
                $table_structure->{$_}->{type},
                $table_structure->{$_}->{cid},
            );
        } @{$fields};
        $template->set_var($assign_to => \@a);
        return;
    }

package MojoDownMonitor::DB::Column;
use strict;
use warnings;

    sub new {
        my ($class, $key, $value, $type, $cid) = @_;
        return bless {
            key     => $key,
            value   => $value,
            type    => $type,
            cid     => $cid,
        }, $class;
    }
    
    sub key {
        return $_[0]->{key} || '';
    }
    
    sub value {
        return $_[0]->{value} || '';
    }
    
    sub type {
        return $_[0]->{type} || '';
    }
    
    sub cid {
        return $_[0]->{cid} || '';
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
