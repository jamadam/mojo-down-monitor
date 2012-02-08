package Text::PSTemplate::Plugin::TSV;
use strict;
use warnings;
use utf8;
use Fcntl qw(:flock);
use base qw(Text::PSTemplate::PluginBase);

    sub load_all_hashref : TplExport {
        my ($self, $file, $key, $namespace, $args) = @_;
        $args ||= ();
        my $data = &seek_tsv(file => $file, %$args);
        my $out = {};
        for my $e (@$data) {
            $out->{$e->[$key]} = $e;
        }
        my $template = Text::PSTemplate->get_current_parser;
        $template->set_var($namespace => $out);
        return;
    }
    
    sub load_record_set : TplExport {
        my ($self, $file, $args) = @_;
        my %seek_args = $args ? (%$args) : ();
        my $recordset = &seek_tsv(file => $file, %seek_args);
        return $recordset;
    }
    
    sub load_record : TplExport {
        my ($self, $file, $column, $value , $namespace, $args) = @_;
        my %seek_args = $args ? (%$args) : ();
        my $data = &seek_tsv(file => $file, cond => {$column => $value}, limit => 1, %seek_args);
        my $template = Text::PSTemplate->get_current_parser;
        
        if (scalar @$data) {
            for (my $idx = 0; $idx < scalar @{$data->[0]}; $idx++) {
                my $key = ($namespace) ? "$namespace\::$idx" : $idx;
                $template->set_var($key => $data->[0]->[$idx] || '');
            }
        }
    }
    
    sub list : TplExport {
        my $self = shift;
        my $file = shift;
        my %args = (@_);
        
        my $data = &seek_tsv(file => $file, %args);
        
        my $template = Text::PSTemplate->new();
        
        if (! scalar @$data) {
            if ($args{default}) {
                return $args{default};
            } else {
                return $template->parse(Text::PSTemplate::get_block(1));
            }
        }
        my $out = '';
        
        my $tplstr;
        if ($args{tpl}) {
            $tplstr = $template->get_file($args{tpl});
        } else {
            $tplstr = Text::PSTemplate::get_block(0);
        }
        
        for (my $lc = 0; $lc < scalar @$data; $lc++) {
            my $array_ref = @$data[$lc];
            for (my $idx = 0; $idx < scalar @$array_ref; $idx++) {
                $template->set_var($idx => $array_ref->[$idx]);
            }
            $template->set_var(
                'num'           => $lc + 1,
                'firstItem'     => $lc == 0,
                'lastItem'      => $lc == scalar @$data,
            );
            $out .= $template->parse_str($tplstr);
        }
        return $out;
    }
    
    ### ---
    ### Total line number
    ### ---
    sub lines : TplExport {
        my ($self, $file) = @_;
        open(my $fh, "<", $file) or die "open $file failed";
        flock($fh, LOCK_EX) or die 'flock failed';
        my $num = 0;
        while(<$fh>) {
            $num++;
        }
        return $num;
    }
    
    ### ---
    ### TSV
    ### ---
    sub seek_tsv {
        my %args = (
            file            => '',
            sortkey         => undef,
            numSort         => 0,
            reverse         => 1,
            cond            => {},
            cond_not        => {},
            regexp          => {},
            regexp_not      => {},
            key             => undef,
            limit           => 10000,
            random          => 0,
            not_null_field  => 0,
            not_null_fields => [],
            header_exist    => 0,
            encoding        => 'utf8',
            row_size        => 0,
            @_);
        
        my @rows = ();
        my $tsv = Text::PSTemplate::Plugin::TSV::_TSV->new({row_size => $args{row_size}});
        open(my $fh, "<:". $args{encoding}, $args{file}) or die "open $args{file} failed";
        flock($fh, LOCK_EX) or die 'flock failed';
        
        if ($args{header_exist}) {
            my $rubbish = $tsv->getline($fh);
        }
        my $limit_count = 0;
        FI: while (my $row = $tsv->getline($fh)) {
            
            if (defined $args{not_null_field} and ! $row->[$args{not_null_field}]) {
                next FI;
            }
            foreach my $val (@{$args{not_null_fields}}) {
                if (! $row->[$val]) {
                    next FI;
                }
            }
            foreach my $key (keys %{$args{cond}}) {
                if ($args{cond}->{$key}) {
                    if ((($row->[$key] || '') ne $args{cond}->{$key})) {
                        next FI;
                    }
                }
            }
            foreach my $key (keys %{$args{'cond_not'}}) {
                if ($args{'cond_not'}->{$key}) {
                    if ((($row->[$key] || '') eq $args{'cond_not'}->{$key})) {
                        next FI;
                    }
                }
            }
            foreach my $key (keys %{$args{regexp}}) {
                if ($args{regexp}->{$key}) {
                    if ((($row->[$key] || '') !~ $args{regexp}->{$key})) {
                        next FI;
                    }
                }
            }
            foreach my $key (keys %{$args{regexp_not}}) {
                if ($args{regexp_not}->{$key}) {
                    if ((($row->[$key] || '') =~ $args{regexp_not}->{$key})) {
                        next FI;
                    }
                }
            }
            if ($args{key}) {
                my @keys = split(/\s/, $args{key});
                my $hit = 0;
                DB: for (my $i = 0; $i < scalar @$row; $i++) {
                    for (my $j = 0; $j < scalar @keys; $j++) {
                        if ($row->[$i] =~ $keys[$j]) {
                            $hit = 1;
                            last DB;
                        }
                    }
                }
                if (! $hit) {
                    next FI;
                }
            }
            push @rows, $row;
            if (++$limit_count >= $args{limit}) {
                last FI;
            }
        }
        close $fh;
        
        if ($args{random}) {
            @rows = &randomize(\@rows);
        } elsif (defined $args{sortkey}) {
            ### 昇順
            if ($args{reverse}) {
                if ($args{numSort}) {
                    @rows = sort {
                        (@$b[$args{sortkey}] || 0) <=>  (@$a[$args{sortkey}] || 0)
                    } @rows;
                } else {
                    @rows = sort {
                        @$b[$args{sortkey}] cmp @$a[$args{sortkey}]
                    } @rows;
                }
            } 
            ### 降順 
            else {
                if ($args{numSort}) {
                    @rows = sort {
                        (@$a[$args{sortkey}] || 0) <=> (@$b[$args{sortkey}] || 0)
                    } @rows;
                } else {
                    @rows = sort {
                        @$a[$args{sortkey}] cmp @$b[$args{sortkey}] 
                    } @rows;
                }
            }
        }
        return \@rows;
    }

### ---
### TSV class
### ---
package Text::PSTemplate::Plugin::TSV::_TSV;
    
    sub new {
        my ($class, $params) = @_;
        return bless {row_size => $params->{row_size}}, $class;
    }
    
    sub getline {
        my ($self, $fh) = @_;
        my $line = <$fh>;
        if (defined $line) {
            $line =~ s/\r\n|\r|\n$//g;
            my @cells = split(/\t/, $line);
            if ($self->{row_size}) {
                return [@cells[0..$self->{row_size}]];
            } else {
                return \@cells;
            }
        }
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::TSV[experimental] - Tab separated values manipulation

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds some functions related to
Environment variables into your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::TSV', '');

=head1 SYNOPSIS

=head1 TEMPLATE FUNCTIONS

=head2 list

=head2 load_record

=head2 new

=head2 seek_tsv

=head2 load_all_hashref

=head2 lines

=head2 load_record_set

=head1 AUTHOR

jamadam <sugama@jamadam.com>

=head1 SEE ALSO

=cut
