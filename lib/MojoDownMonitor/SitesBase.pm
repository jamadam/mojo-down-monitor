package MojoDownMonitor::SitesBase;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use Mojo::JSON;
use DBI;
use base 'MojoX::Tusu::Component::SQLite';
use Data::Dumper;
use feature q/:5.10/;
	
	my $json_parser = Mojo::JSON->new;
    
    sub is_pjax : TplExport {
        my ($self) = @_;
        return defined $self->controller->req->headers->header('X-PJAX');
    }
    
    sub cid_table {
        my ($self, $c) = @_;
        my $t_def = $self->get_table_structure;
        my $out = {};
        my $p = ($c || $self->controller)->req->body_params;
        for my $name (keys %$t_def) {
            my $cid = 'cid-'. $t_def->{$name}->{cid};
            $out->{$name} = $p->param($cid)
        }
        return $out;
    }
    
    sub generate_dataset_hash_seed {
        my $self = shift;
        my @data;
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
            push(@data, $cname, $value);
        }
        return @data;
    }
    
    ### ---
    ### generate dataset for db insert or update with form data
    ### ---
    sub generate_dataset {
        my $self = shift;
        my $data = SQL::OOP::Dataset->new();
        my @array = $self->generate_dataset_hash_seed;
        while (my ($key, $value) = splice @array, 0, 2) {
            $data->append($key => $value);
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
            $self->redirect_to($c->req->body_params->param('nextpage'));
        }
        return;
    }
    
    sub create {
        my ($self, $data) = @_;
        $self->SUPER::create($data || $self->generate_dataset);
    }
    
    sub update {
        my ($self, $data, $where_seed) = @_;
		my $where_hash =
			$json_parser->decode($where_seed || $self->controller->param('where'));
		my $where = SQL::OOP::Where->and_hash($where_hash);
        $self->SUPER::update($data || $self->generate_dataset, $where);
    }
    
    sub delete {
        my ($self, $where_seed) = @_;
		my $where_hash =
			$json_parser->decode($where_seed || $self->controller->param('where'));
		my $where = SQL::OOP::Where->and_hash($where_hash);
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
