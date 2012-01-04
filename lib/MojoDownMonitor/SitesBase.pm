package MojoDownMonitor::SitesBase;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use DBI;
use base 'MojoX::Tusu::Component::SQLite';
use Data::Dumper;
use feature q/:5.10/;
    
    sub common_dbh {
        my $self= shift;
        $self->get_engine->get_plugin(__PACKAGE__)->dbh;
    }
    
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
    }
    
    sub cid_table {
        my ($self) = @_;
        my $t_def = $self->get_table_structure;
        my $out = {};
        my $p = $self->controller->req->body_params;
        for my $name (keys %$t_def) {
            my $cid = 'cid-'. $t_def->{$name}->{cid};
            $out->{$name} = $p->param($cid)
        }
        return $out;
    }
    
    ### ---
    ### generate dataset for db insert or update with form data
    ### ---
    sub generate_dataset {
        my $self = shift;
        my $data = SQL::OOP::Dataset->new();
        my $tabe_structure = $self->get_table_structure;
        my @columns = split /,/, $self->controller->param('columns');
        if (! scalar @columns) {
            return;
        }
        COLUMN : for my $cname (@columns) {
            my $id = 'cid-'. $tabe_structure->{$cname}->{cid};
            my $value = $self->controller->param($id);
            given (lc $tabe_structure->{$cname}->{type}) {
                when ('bool') {
                    if ($value) {
                        $value = $self->true_for_sql_statement;
                    } else {
                        $value = $self->false_for_sql_statement;
                    }
                }
                when (['integer', 'real']) {
                    if (defined $value && $value eq '') {
                        next COLUMN;
                    }
                }
            }
            $data->append($cname => $value);
        }
        return $data;
    }
    
    sub post {
        my ($self) = @_;
        my $c = $self->controller;
        
        $self->validate_form;
        
        if ($self->user_err->count) {
            $self->render;
        } else {
            given ($c->req->body_params->param('mode')) {
                when ('update') {$self->update}
                when ('create') {$self->create}
                when ('delete') {$self->delete}
            }
            $c->redirect_to($c->req->body_params->param('nextpage'));
        }
        return;
    }
    
    sub create {
        my ($self, $data) = @_;
        $self->SUPER::create($data || $self->generate_dataset);
    }
    
    sub update {
        my ($self, $data) = @_;
        my $json_parser = Mojo::JSON->new;
        my $where_seed = $self->controller->param('where');
        my $where = SQL::OOP::Where->and_hash($json_parser->decode($where_seed));
        $self->SUPER::update($data || $self->generate_dataset, $where);
    }
    
    sub delete {
        my ($self) = @_;
        my $where_seed = $self->controller->param('where');
        my $where = SQL::OOP::Where->and_hash(Mojo::JSON->decode($where_seed));
        $self->SUPER::delete($where);
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
