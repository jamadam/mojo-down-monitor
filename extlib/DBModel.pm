package DBModel;
use strict;
use warnings;
use SQL::OOP;
use SQL::OOP::Select;
use SQL::OOP::Insert;
use SQL::OOP::Delete;
use SQL::OOP::Update;
use DBI;
use Mojo::Base -base;
use Data::Dumper;

    __PACKAGE__->attr('table_structure');
    __PACKAGE__->attr('table');
    __PACKAGE__->attr('dbh');

	### ---
	### Constructor
	### ---
    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
		$self->init;
        return $self;
    }
	
	### ---
	### unemptify
	### ---
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
    
	### ---
	### dump
	### ---
    sub dump {
        my ($self, $where, $fields, $limit, $orderby, $offset) = @_;
        my $select = SQL::OOP::Select->new;
        $select->set(
            $select->ARG_FIELDS 	=> $fields ? SQL::OOP::IDArray->new($fields) : '*',
            $select->ARG_FROM   	=> $self->table,
            $select->ARG_WHERE  	=> 
				(ref $where eq 'HASH') ? SQL::OOP::Where->and_hash($where) : $where,
            $select->ARG_ORDERBY  	=> SQL::OOP::Order->abstract($orderby),
            $select->ARG_LIMIT 		=> $limit,
            $select->ARG_OFFSET 	=> $offset,
        );
        my $dbh = $self->dbh;
        my $sth = $dbh->prepare($select->to_string) or die $dbh->errstr;
        $sth->execute($select->bind) or die $sth->errstr;
        return $sth;
    }
    
	### ---
	### total size
	### ---
	sub count {
		my $self = shift;
		my %args = (
			where  	=> undef,
			@_);
        my $select = SQL::OOP::Select->new;
        $select->set(
            $select->ARG_FIELDS 	=> 'count(*)',
            $select->ARG_FROM   	=> $self->table,
            $select->ARG_WHERE  	=> 
				(ref $args{where} eq 'HASH')
					? SQL::OOP::Where->and_hash($args{where}) : $args{where},
        );
        my $dbh = $self->dbh;
        my $sth = $dbh->prepare($select->to_string) or die $dbh->errstr;
        $sth->execute($select->bind) or die $sth->errstr;
		return $sth->fetchrow_arrayref->[0];
	}
	
	### ---
	### loop
	### ---
    sub fetch {
        my $self = shift;
		my %args = (
			fields 	=> undef,
			where  	=> undef,
			limit  	=> undef,
			orderby	=> undef,
			offset  => undef,
			@_);
		
        my $sth = $self->dump($args{where}, $args{fields},
							  $args{limit}, $args{orderby}, $args{offset});
		my $table_structure = $self->get_table_structure;
		my @ret;
        while (my $hash = $sth->fetchrow_hashref) {
			my $rec =
				DBModel::Record->new($hash, $table_structure, $args{fields});
			push(@ret, $rec);
        }
		$sth->finish;
        return @ret;
    }
    
	### ---
	### skeleton
	### ---
    sub skeleton {
        my $self = shift;
		my %args = (
			fields 	=> undef,
			@_);
		
		my $table_structure = $self->get_table_structure;
		return DBModel::Record->new(undef, $table_structure, $args{fields});
    }
	
	### ---
	### top
	### ---
	sub top {
		my $self = shift;
		my %args = (
			assign 	=> 'rec',
			field 	=> '',
			limit 	=> 10,
			@_);
		
		my $sql = SQL::OOP::Select->new();
		$sql->set(
			$sql->ARG_FIELDS 	=>
				SQL::OOP::IDArray->new(
					SQL::OOP::ID->new($args{field})->as($args{field}),
					SQL::OOP->new("count(*) AS count"),
				),
			$sql->ARG_FROM		=> SQL::OOP::ID->new($self->table),
			$sql->ARG_GROUPBY	=> SQL::OOP::ID->new($args{field}),
			$sql->ARG_ORDERBY	=> SQL::OOP::Order->new_desc('count'),
			$sql->ARG_LIMIT		=> $args{limit},
		);
		my $sth =
				$self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
		
		$sth->execute($sql->bind) or return;
		
        my @ret;
		
		my $table_structure = $self->get_table_structure;
        while (my $hash = $sth->fetchrow_hashref) {
			my $rec =
				DBModel::Record->new($hash, $table_structure, [$args{field}]);
			push(@ret, $rec);
        }
		$sth->finish;
		
        return @ret;
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
        my $sth =
				$self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
		$sth->finish;
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
        my $sth =
				$self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
        $sth->execute($sql->bind) or die $sth->errstr;
		$sth->finish;
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
            my $sth =
				$self->dbh->prepare($sql->to_string) or die $self->dbh->errstr;
            $sth->execute($sql->bind) or die $sth->errstr;
			$sth->finish;
        }
    }
    
    ### ---
    ### get_table_structure
    ### ---
    sub get_table_structure {
        die 'get_table_structure must be implemented.';
    }

package DBModel::Record;
use strict;
use warnings;

	my $MEM_DATA	= 1;
	my $MEM_FIELDS	= 2;
	
    sub new {
        my ($class, $hash, $table_structure, $fields) = @_;
        my $data = {};
        for my $key ($hash ? keys %$hash : @$fields) {
            $data->{$key} = DBModel::Column->new(
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
		if ($self->{$MEM_DATA}->{$name}) {
			return $self->{$MEM_DATA}->{$name}->value;
		}
    }
    
    sub columns {
        my ($self) = shift;
        my @fields = $self->{$MEM_FIELDS}
						? @{$self->{$MEM_FIELDS}} : keys %{$self->{$MEM_DATA}};
        return map {$self->{$MEM_DATA}->{$_}} @fields;
    }

package DBModel::Column;
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
        return defined $_[0]->{$MEM_KEY} ? $_[0]->{$MEM_KEY} : '';
    }
    
    sub value {
        return defined $_[0]->{$MEM_VALUE} ? $_[0]->{$MEM_VALUE} : '';
    }
    
    sub type {
        return defined $_[0]->{$MEM_TYPE} ? $_[0]->{$MEM_TYPE} : '';
    }
    
    sub cid {
        return defined $_[0]->{$MEM_CID} ? $_[0]->{$MEM_CID} : '';
    }

1;

__END__

=head1 NAME DBModel

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
