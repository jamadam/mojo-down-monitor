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
use MojoDownMonitor::UserError;
use base 'DBModel::SQLite';
use Data::Dumper;
use feature q/:5.10/;
    
    my $json_parser = Mojo::JSON->new;
    
    sub cid_table {
        my ($self) = @_;
        my $t_def = $self->get_table_structure;
        my $out = {};
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        my $p = $tx->req->body_params;
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
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        my @columns = split /,/, $tx->req->param('columns');
        if (! scalar @columns) {
            return;
        }
        COLUMN : for my $cname (@columns) {
            my $id = 'cid-'. $tabe_structure->{$cname}->{cid};
            my $value = $tx->req->param($id);
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
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        
        $self->validate_form;
        
        if ($self->user_err->count) {
            $self->render;
        } else {
            given ($tx->req->body_params->param('mode')) {
                when ('update') {$self->update}
                when ('create') {$self->create}
                when ('delete') {$self->delete}
            }
            my $app = $MojoSimpleHTTPServer::CONTEXT->app;
            $app->serve_redirect($tx->req->body_params->param('nextpage'));
        }
        return;
    }
    
    sub create {
        my ($self, $data) = @_;
        $self->SUPER::create($data || $self->generate_dataset);
    }
    
    sub update {
        my ($self, $data, $where_seed) = @_;
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        my $where_hash =
            $json_parser->decode($where_seed || $tx->req->param('where'));
        my $where = SQL::OOP::Where->and_hash($where_hash);
        $self->SUPER::update($data || $self->generate_dataset, $where);
    }
    
    sub delete {
        my ($self, $where_seed) = @_;
        my $tx = $MojoSimpleHTTPServer::CONTEXT->tx;
        $where_seed ||= $tx->req->param('where');
        my $where_hash =
            ref $where_seed ? $where_seed : $json_parser->decode($where_seed);
        my $where = SQL::OOP::Where->and_hash($where_hash);
        $self->SUPER::delete($where);
    }
	
	### ---
	### user_error
	### ---
    sub user_err {
        my ($self) = @_;
        my $stash = $MojoSimpleHTTPServer::CONTEXT->stash;
        if (! $stash->{user_err}) {
            $stash->set('user_err', MojoDownMonitor::UserError->new);
        }
        return $stash->{user_err};
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
