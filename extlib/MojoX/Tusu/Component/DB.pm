package MojoX::Tusu::Component::DB;
use strict;
use warnings;
use Text::PSTemplate;
use SQL::OOP::Select;
use SQL::OOP::Dataset;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use SQL::OOP::Update;
use DBI;
use base 'MojoX::Tusu::ComponentBase';
use Data::Dumper;

    __PACKAGE__->attr('table');
    __PACKAGE__->attr('dbh');
    
    sub user_err {
        my ($self) = @_;
        my $c = $self->controller;
        if (! $c->stash('user_err')) {
            $c->stash('user_err', MojoX::Tusu::Component::DB::User_error->new)
        }
        return $c->stash('user_err');
    }
    
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
    
    sub dump {
        my ($self, $where, $fields, $limit, $orderby) = @_;
        my $select = SQL::OOP::Select->new;
        $select->set(
            $select->ARG_FIELDS 	=> $fields ? SQL::OOP::IDArray->new($fields) : '*',
            $select->ARG_FROM   	=> $self->table,
            $select->ARG_WHERE  	=> SQL::OOP::Where->and_hash($where),
            $select->ARG_ORDERBY  	=> SQL::OOP::Order->abstract($orderby),
            $select->ARG_LIMIT 		=> $limit,
        );
        my $dbh = $self->dbh;
        my $sth = $dbh->prepare($select->to_string) or die $dbh->errstr;
        $sth->execute($select->bind) or die $sth->errstr;
        return $sth;
    }
    
    sub loop : TplExport {
        my $self = shift;
		my %args = (
			fields 	=> undef,
			where  	=> undef,
			limit  	=> undef,
			orderby	=> undef,
			assign	=> 'rec',
			@_);
		
        my $template = Text::PSTemplate::get_block(0);
        my $sth = $self->dump($args{where}, $args{fields}, $args{limit}, $args{orderby});
        my $out = '';
		my $table_structure = $self->get_table_structure;
        while (my $hash = $sth->fetchrow_hashref) {
            my $tpl = Text::PSTemplate->new();
			my $rec = MojoX::Tusu::Component::DB::Record->new($hash, $table_structure, $args{fields});
			$tpl->set_var($args{assign} => $rec);
            $out .= $tpl->parse_str($template);
        }
        return $out;
    }
    
    sub skeleton : TplExport {
        my $self = shift;
		my %args = (
			fields 	=> undef,
			assign	=> 'rec',
			@_);
		
        my $template = Text::PSTemplate::get_block(0);
		my $table_structure = $self->get_table_structure;
		my $tpl = Text::PSTemplate->new();
		my $rec = MojoX::Tusu::Component::DB::Record->new(undef, $table_structure, $args{fields});
		$tpl->set_var($args{assign} => $rec);
		return $tpl->parse_str($template);
    }
    
    sub load {
        my $self = shift;
		my %args = (
			fields 	=> undef,
			where  	=> undef,
			limit  	=> undef,
			orderby	=> undef,
			@_);
		
        my $sth = $self->dump($args{where}, $args{fields}, $args{limit}, $args{orderby});
		my $table_structure = $self->get_table_structure;
        if (my $hash = $sth->fetchrow_hashref) {
			return MojoX::Tusu::Component::DB::Record->new($hash, $table_structure, $args{fields});
        }
    }
    
    ### ---
    ### create
    ### ---
    sub create {
        my ($self, $dataset) = @_;
        my $table = $self->table;
        my $sql = SQL::OOP::Insert->new();
        $sql->set(
            $sql->ARG_TABLE     => SQL::OOP::ID->new($table),
            $sql->ARG_DATASET   => $dataset,
        );
        my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
    }
    
    ### ---
    ### update
    ### ---
    sub update {
        my ($self, $dataset, $where) = @_;
        my $table = $self->table;
        my $sql = SQL::OOP::Update->new();
        $sql->set(
            $sql->ARG_TABLE     => SQL::OOP::ID->new($table),
            $sql->ARG_WHERE     => $where,
            $sql->ARG_DATASET   => $dataset,
        );
        my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
    }
    
    ### ---
    ### delete
    ### ---
    sub delete {
        my ($self, $where) = @_;
        my $table = $self->table;
        if ($where) {
            my $sql = SQL::OOP::Delete->new();
            $sql->set(
                $sql->ARG_TABLE    => SQL::OOP::ID->new($table),
                $sql->ARG_WHERE    => $where,
            );
            my $sth = $self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
            $sth->execute($sql->bind) or die $sth->errstr;
        }
    }
    
    sub put_user_err : TplExport {
        my ($self, $id) = @_;
        my $c = $self->controller;
        if ($self->user_err->count) {
            $id ||= 'error';
            my @errs = map {'<li>'. $_. '</li>'} $self->user_err->array;
            return '<ul id="'. $id. '">'. join('', @errs). '</ul>';
        }
        return;
    }
    
    ### ---
    ### get_table_structure
    ### ---
    sub get_table_structure {
        die 'get_table_structure must be implemented.';
    }

package MojoX::Tusu::Component::DB::Record;
use strict;
use warnings;

	my $MEM_DATA	= 1;
	my $MEM_FIELDS	= 2;
	
    sub new {
        my ($class, $hash, $table_structure, $fields) = @_;
        my $data = {};
        for my $key ($hash ? keys %$hash : @$fields) {
            $data->{$key} = MojoX::Tusu::Component::DB::Column->new(
                $key,
                $hash ? $hash->{$key} : undef,
                $table_structure->{$key}->{type},
                $table_structure->{$key}->{cid},
            );
        }
        return bless {$MEM_DATA => $data, $MEM_FIELDS => $fields}, $class;
    }
	
    sub retrieve {
        my ($self, $name) = @_;
        return $self->{$MEM_DATA}->{$name};
    }
    
    sub value {
        my ($self, $name) = @_;
        return $self->{$MEM_DATA}->{$name}->value;
    }
    
    sub each {
        my ($self) = shift;
        my @fields = $self->{$MEM_FIELDS} ? @{$self->{$MEM_FIELDS}} : keys %{$self->{$MEM_DATA}};
        my @data = map {$self->{$MEM_DATA}->{$_}} @fields;
        Text::PSTemplate::Plugin::Control->each(\@data, @_);
    }

package MojoX::Tusu::Component::DB::Column;
use strict;
use warnings;
	
	my $MEM_KEY			= 1;
	my $MEM_VALUE		= 2;
	my $MEM_TYPE 		= 3;
	my $MEM_CID			= 4;

    sub new {
        my ($class, $key, $value, $type, $cid, $annotation) = @_;
        return bless {
            $MEM_KEY 		=> $key,
            $MEM_VALUE		=> $value,
            $MEM_TYPE		=> $type,
            $MEM_CID		=> $cid,
        }, $class;
    }
    
    sub key {
        return $_[0]->{$MEM_KEY} // '';
    }
    
    sub value {
        return $_[0]->{$MEM_VALUE} // '';
    }
    
    sub type {
        return $_[0]->{$MEM_TYPE} // '';
    }
    
    sub cid {
        return $_[0]->{$MEM_CID} // '';
    }

### ---
### Stackable user err class
### ---
package MojoX::Tusu::Component::DB::User_error;
use strict;
use warnings;

    sub new {
        return bless [], shift;
    }
    
    sub stack {
        my ($self, $err) = @_;
        push(@$self, $err);
        return $self;
    }
    
    sub count {
        my ($self) = @_;
        return scalar @$self;
    }
    
    sub array {
        my ($self) = @_;
        return @$self;
    }

1;

__END__

=head1 NAME MojoX::Tusu::Component::DB

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
