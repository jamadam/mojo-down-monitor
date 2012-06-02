package MojoSimpleHTTPServer::Stash;
use strict;
use warnings;
use Mojo::Base -base;
    
    sub get {
        my $self = shift;
        if (! $_[0]) {
            return $self;
        }
        
        return $self->{$_[0]};
    }
    
    sub set {
        my $self = shift;
        my $values = ref $_[0] ? $_[0] : {@_};
        for my $key (keys %$values) {
            $self->{$key} = $values->{$key};
        }
    }
    
    ### --
    ### Clone
    ### --
    sub clone {
        my $self = shift;
        (ref $self)->new(%{$self}, @_);
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::Stash - stash

=head1 SYNOPSIS

    use MojoSimpleHTTPServer::Stash;
    
    my $stash = MojoSimpleHTTPServer::Stash->new(a => 'b', c => 'd');
    is_deeply $stash->set(), {a => 'b', c => 'd'};
    
    $stash->set(e => 'f');
    is_deeply $stash->get(), {a => 'b', c => 'd', e => 'f'};
    
    $stash->set(e => 'g');
    is_deeply $stash->get(), {a => 'b', c => 'd', e => 'g'};
    
    my $clone = $stash->clone(h => 'i');
    is_deeply $clone->get(), {a => 'b', c => 'd', e => 'g', h => 'i'};
    is_deeply $stash->get(), {a => 'b', c => 'd', e => 'g'};

=head1 DESCRIPTION

A class represents stash. The instance is a code ref accessing to closed hash
ref.

=head1 METHODS

=head2 MojoSimpleHTTPServer::Stash->new(%key_value)

=head2 $instance->get($name)

Get stash value for given name.

=head2 $instance->set(%key_value)

Set stash values with given hash or hash reference.

=head2 $instance->clone(%key_value)

Clone stash with given hash or hash reference merged.

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
