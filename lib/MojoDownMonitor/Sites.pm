package MojoDownMonitor::Sites;
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
    "Site name" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '10', 'http://example.com', '', 'text/html', '301', 'a\@example.com,b\@example.com', 'example.com');
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '10', 'http://google.co.jp', '', '', '200', 'a\@example.com,b\@example.com', 'google');
INSERT INTO $table ("Content must match", "Interval", "URI", "HTTP header must match", "MIME type must be", "Status must be", "Mail to", "Site name") VALUES ('', '60', 'http://github.com', '', 'text/html; charset=utf-8', '200', 'a\@example.com,b\@example.com', 'github');
EOF
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
    
    sub validate_form {
        my ($self) = @_;
        my $params = $self->controller->req->body_params;
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
                    $self->user_err->stack('URI must be a digit');
                }
            }
            when ('delete') {
                
            }
        }
    }
    
    sub post {
        my ($self) = @_;
        my $c = $self->controller;
        
        $self->validate_form;
        
        if ($self->user_err->count) {
            my $template = $c->req->body_params->param('errorpage');
            $c->render(handler => 'tusu', template => $template);
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
                    $value ||= 0;
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
    
    sub create {
        my ($self) = @_;
        $self->SUPER::create($self->generate_dataset);
    }
    
    sub update {
        my ($self) = @_;
        my $json_parser = Mojo::JSON->new;
        my $where_seed = $self->controller->param('where');
        my $where = SQL::OOP::Where->and_hash($json_parser->decode($where_seed));
        $self->SUPER::update($self->generate_dataset, $where);
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
