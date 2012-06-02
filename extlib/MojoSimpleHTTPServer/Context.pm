package MojoSimpleHTTPServer::Context;
use strict;
use warnings;
use Mojo::Base -base;
    
    ### ---
    ### App
    ### ---
    __PACKAGE__->attr('app');
    
    ### ---
    ### Transaction
    ### ---
    __PACKAGE__->attr('tx');
    
    ### ---
    ### Stash
    ### ---
    sub stash {
        my ($self, $stash) = @_;
        if ($stash) {
            $self->{stash} = $stash;
        } else {
            $self->{stash} ||= $self->app->stash->clone;
        }
        return $self->{stash};
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::Context - Context

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 app

MojoSimpleHTTPServer instance.

=head2 tx

Mojo::Transaction instance.

=head2 stash

A stash that inherits app's one.

=head1 METHODS

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
