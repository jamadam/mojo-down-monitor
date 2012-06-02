package MyApp::Plan;
use strict;
use warnings;
use utf8;
use DBIx::UTF8Key;
use SQL::OOP;
use SQL::OOP::Where;
use SQL::OOP::Dataset;
use base qw(DBModel::SQLite);
use Mojo::JSON;
use Switch;

	__PACKAGE__->attr('file_dir');
	
	my $json_parser = Mojo::JSON->new;
	
    sub init {
        my ($self) = @_;
		my $app = $MojoSimpleHTTPServer::CONTEXT->app;
		$self->file_dir($app->home->rel_file('web/imgm/plan'));
        my $file = $app->home->rel_file('data/plan.sqlite');
        my $dbh = DBIx::UTF8Key->connect("DBI:SQLite:dbname=$file",
            undef, undef, {
                AutoCommit      => 1,
                RaiseError      => 1,
                sqlite_unicode  => 1,
                sqlite_allow_multiple_statements => 1,
            }
        ) or die 'Connect to SQLite file '. $file. ' failed';

        $self->dbh($dbh);
		$self->table('main');
    }
    
    sub validate_form {
        my ($self) = @_;
        my $c = $self->controller;
        #$self->user_err->stack('un error');
    }
    
    sub post {
        my ($self) = @_;
        my $c = $self->controller;
        
        $self->validate_form;
        
        if ($self->user_err->count) {
            $self->render;
        } else {
            switch ($c->req->body_params->param('mode')) {
                case 'update' {$self->update}
                case 'create' {$self->create}
                case 'delete' {$self->delete}
            }
            $self->redirect_to($c->req->body_params->param('nextpage'));
        }
        return;
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
            switch (lc $tabe_structure->{$cname}->{type}) {
                case ('bool') {
                    $value ||= 0;
                }
                case (['integer', 'real']) {
                    if (defined $value && $value eq '') {
                        next COLUMN;
                    }
                }
            }
            $data->append($cname => $value);
        }
		$data->append('update_date' => SQL::OOP->new(q{datetime('now','localtime')}));
        return $data;
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
		$self->component('MyApp::TopicsUpload')->delete($where_hash->{id}. '_');
        $self->SUPER::delete($where);
    }

1;

__END__

=head1 NAME

NT::Plugin::Visith::Topics

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 TEMPLATE FUNCTIONS

=head1 AUTHOR

jamadam <sg@cutout.jp>

=head1 SEE ALSO

=cut
