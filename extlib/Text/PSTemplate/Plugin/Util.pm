package Text::PSTemplate::Plugin::Util;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
    
    ### ---
    ### Conver to comma separated number
    ### ---
    sub commify : TplExport {
        
        my ($self, $num) = @_;
        
        if ($num) {
            while($num =~ s/(.*\d)(\d\d\d)/$1,$2/){};
            return $num;
        }
        if ($num eq '0') {
            return 0;
        }
        return;
    }
    
    sub length : TplExport {
        
        my ($self, $obj) = @_;
        if (ref $obj eq 'ARRAY') {
            return scalar @$obj;
        }
    }
    
    ### ---
    ### Substr
    ### ---
    sub substr : TplExport {
        
        my ($self, $target, $start, $length, $alter) = @_;
        
        defined $target or return '';
        
        my $output = substr($target, $start, $length);
        
        if ($alter && CORE::length($target) != CORE::length($output)) {
            $output .= $alter;
        }
        return $output;
    }
    
    ### ---
    ### Counter 
    ### ---
    my $_counters = {};
    
    sub counter : TplExport {
        
        my $self = shift;
        my %args = (
            name => 'default',
            print => 1,
            assign => undef,
            @_);
        
        my $name = ($Text::PSTemplate::get_current_filename||''). $args{name};
        
        $_counters->{$name} ||= _make_counter(%args);
        
        if (exists $args{start}||$args{skip}||$args{direction}) {
            $_counters->{$name}->{init}->(%args);
        } else {
            $_counters->{$name}->{count}->();
        }
        if ($args{assign}) {
            Text::PSTemplate->get_current_file_parser->set_var($args{assign} => $_counters->{$name}->{show}->());
        }
        if ($args{print}) {
            return $_counters->{$name}->{show}->();
        }
        return;
    }
    
    sub _make_counter {
        
        my $a = {
            start       => 1,
            skip        => 1,
            direction   => "up",
            @_};
        
        return {
            init    => sub{
                $a = {%$a, @_};
            },
            count   => sub{
                my $direction = {up => '1', down => '-1'}->{$a->{direction}};
                $a->{start} = $a->{start} + $a->{skip} * $direction;
            },
            show    => sub {
                return $a->{start};
            },
        };
    }
    
    ### ---
    ### split multi line into array
    ### ---
    sub split_line : TplExport {
        
        my ($self, $str) = @_;
        my @ret = split(/\r\n|\r|\n/, $str);
        return \@ret;
    }
    
    ### ---
    ### line count
    ### ---
    sub line_count : TplExport {
        
        my $self = shift;
        my @array = split(/\r\n|\r|\n/, shift);
        return scalar @array;
    }
    
    ### ---
    ### string replace
    ### ---
    sub replace : TplExport {
        
        my ($self, $str, $org, $rep) = @_;
        $str =~ s{$org}{$rep}g;
        return $str;
    }
    
    ### ---
    ### replace spaces to line break
    ### ---
    sub space2linebreak : TplExport {
        
        my ($self, $str) = @_;
        $str =~ s{\s|@}{\n}g;
        return $str;
    }
    
    ### ---
    ### delete_space
    ### ---
    sub delete_space : TplExport {
        
        my $self = shift;
        my $str = shift;
        $str =~ s{\s|@}{}g;
        
        return $str;
    }
    
    ### ---
    ### split and extract
    ### ---
    sub split : TplExport {
        
        my $self = shift;
        my @array;
        if ($_[2]) {
            @array = CORE::split($_[0],$_[1],$_[2]);
        } else {
            @array = CORE::split($_[0],$_[1]);
        }
        return \@array;
    }
    
    ### ---
    ### int
    ### ---
    sub int : TplExport {
        
        my ($self, $num) = @_;
        return CORE::int($num);
    }
    
    ### ---
    ### randomize array order
    ### ---
    sub randomize : TplExport {
        
        my ($self, $array) = @_;
        my @new = ();
        foreach (0..(scalar @$array - 1)) {
            my $rand = CORE::int(rand(@new + 1));
            push(@new, $new[$rand]);
            $new[$rand] = $array->[$_];
        }
        return @new;
    }
    
    ### ---
    ### random string of given length
    ### ---
    sub random_string : TplExport {
        
        my ($self, $length, $candidates) = @_;
        $candidates ||= 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
        my @c = split(//, $candidates);
        my $c_len = scalar @c;
        my $out = '';
        for (my $i = 0; $i < $length; $i++) {
            my $j = CORE::int(CORE::rand($c_len));
            $out .= $c[$j];
        }
        return $out;
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Util - Utility functions

=head1 SYNOPSIS
    
    <% commify($num) %>
    
    <% substr($var, $start, $length, $alterative) %>
    <% substr($some_var, 0, 2, '...') %>

    <% counter(start=10, skip=5) %>
    <% counter() %>
    <% counter() %>
    <% counter(start=10, direction=down) %>
    <% counter() %>

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds Utility functions into
your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Util', '');

Since this has promoted to core plugin, you don't have to explicitly load it.

=head1 TEMPLATE FUNCTIONS

=head2 commify($num)

Not written yet.

=head2 substr($var, $start, [$length, $alterative])

Not written yet.

=head2 counter([ string $name = 'default', [ int $start = 1, [ int $skip = 1, [ string $direction = "up", [ bool $print = true, [ string $assign = null ]]]]]])

Example

    <% counter(start=10, skip=5) %>
    <% counter() %>
    <% counter() %>
    <% counter(start=10, direction=down) %>
    <% counter() %>

Output

    10
    15
    20
    10
    5

=head2 split_line

=head2 split

=head2 substr

=head2 replace

=head2 space2linebreak

=head2 randomize

=head2 line_count

=head2 delete_space

=head2 length

=head2 int

=head2 random_string

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
