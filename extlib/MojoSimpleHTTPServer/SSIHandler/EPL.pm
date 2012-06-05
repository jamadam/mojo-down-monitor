package MojoSimpleHTTPServer::SSIHandler::EPL;
use strict;
use warnings;
use Mojo::Base 'MojoSimpleHTTPServer::SSIHandler';
use MojoSimpleHTTPServer::Cache;
use Mojo::Util qw/encode md5_sum/;
    
    __PACKAGE__->attr('template_cache' => sub {MojoSimpleHTTPServer::Cache->new});
    
    ### --
    ### Accessor to template cache
    ### --
    sub cache {
        my ($self, $path, $mt, $expire) = @_;
        
        my $cache = $self->template_cache;
        my $key = md5_sum(encode('UTF-8', $path));
        if ($mt) {
            $cache->set($key, $mt, $expire);
        } else {
            $cache->get($key);
        }
    }

    ### --
    ### EPL handler
    ### --
    sub render {
        my ($self, $path) = @_;
        
        my $context = $MSHS::CONTEXT;
        
        my $mt = $self->cache($path);
        
        my $output;
        
        if ($mt && $mt->compiled) {
            $output = $mt->interpret($self, $context);
        } else {
            if (! $mt) {
                $mt = Mojo::Template->new;
                $self->cache($path, $mt, sub {$_[0] < (stat($path))[9]});
            }
            $output = $mt->render_file($path, $self, $context);
        }
        
        return ref $output ? die $output : $output;
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::SSIHandler::EPL - EPL template handler

=head1 SYNOPSIS

    $app->add_handler(epl => MojoSimpleHTTPServer::SSIHandler::EPL->new);

=head1 DESCRIPTION

EPL handler.

=head1 ATTRIBUTES

=head1 METHODS

=head2 $instance->cache($path, $mt)

Get or set cache.

=head2 $instance->render($path)

Renders given template and returns the result. If rendering fails, die with
Mojo::Exception.

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
