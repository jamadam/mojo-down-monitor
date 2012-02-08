package Text::PSTemplate::Block;
use strict;
use warnings;
use Carp;

    my $MEM_BLOCKS = 1;
    my $MEM_LENGTH = 2;
    
    sub new {
        my ($class, $names, $right, $delim_l, $delim_r) = @_;
        my $length = 0;
        my @out = ();
        for my $a (split(',', $names)) {
            if ($$right =~ s{(.*?)($delim_l\s*$a\s*$delim_r)}{}s) {
                push(@out, [$1, $2]);
                $length += length($1) + length($2);
            } else {
                die "unclosed block $a found";
            }
        }
        bless {
            $MEM_BLOCKS => \@out,
            $MEM_LENGTH => $length
        }, $class;
    }
    
    sub get_left_chomp {
        my ($self, $index) = @_;
        my $data = $self->content($index);
        $data =~ m{^(\r\n|\r|\n)};
        $1;
    }
    
    ### ---
    ### Get inline data
    ### ---
    sub content {
        my ($self, $index, $args) = @_;
        if (defined $index) {
            my $data = $self->{$MEM_BLOCKS}->[$index]->[0];
            if ($data && $args) {
                if ($args->{chop_left}) {
                    $data =~ s{^(?:\r\n|\r|\n)}{};
                }
                if ($args->{chop_right}) {
                    $data =~ s{(?:\r\n|\r|\n)$}{};
                }
            }
            return $data;
        } else {
            return $self;
        }
    }

    sub delimiter {
        my ($self, $index) = @_;
        $self->{$MEM_BLOCKS}->[$index]->[1];
    }

    sub get_followers_offset {
        my ($self) = @_;
        $self->{$MEM_LENGTH};
    }
    
    sub length {
        my ($self) = @_;
        scalar @$self;
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Block - A Class represents template blocks

=head1 SYNOPSIS
    
=head1 DESCRIPTION

=head1 METHODS

=head2 Text::PSTemplate::Block->new();

=head2 $instance->content

=head2 $instance->delimiter

=head2 $instance->get_followers_offset

=head2 $instance->get_left_chomp

=head2 $instance->length

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
