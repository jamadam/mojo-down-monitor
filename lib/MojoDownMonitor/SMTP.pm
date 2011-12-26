package MojoDownMonitor::SMTP;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use SQL::OOP::Dataset;
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
        $self->table('smtp');
        my $table = $self->table;
        
        $dbh->do(<<"EOF") or die $dbh->errstr;
CREATE TABLE IF NOT EXISTS $table (
    "id" INTEGER PRIMARY KEY  NOT NULL ,
    "host" VARCHAR DEFAULT localhost,
    "port" INTEGER NOT NULL DEFAULT 25,
    "ssl" BOOL NOT NULL DEFAULT 0,
    "user" VARCHAR,
    "password" VARCHAR
);
EOF
        
        $self->unemptify(<<"EOF");
INSERT INTO $table (id) VALUES (NULL);
EOF
    }
    
    sub server_info {
        my $self = shift;
        return $self->load_record(1, ['host','port','ssl','user', 'password']);
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
            my $template = $c->req->body_params->param('errorpage');
            warn $template;
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
        my $c = $self->controller;
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

=head1 NAME MojoDownMonitor::SMTP

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
