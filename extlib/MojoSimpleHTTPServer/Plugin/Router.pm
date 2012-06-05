package MojoSimpleHTTPServer::Plugin::Router;
use strict;
use warnings;
use Mojo::Base 'MojoSimpleHTTPServer::Plugin';
    
    __PACKAGE__->attr('routes', sub {[]});
    
    ### --
    ### Register the plugin into app
    ### --
    sub register {
        my ($self, $app, $routes) = @_;
        
        if (ref $routes eq 'ARRAY') {
            $self->routes($routes);
        } else {
            $routes->($self);
        }
        
        $app->hook(around_dispatch => sub {
            my ($next, @args) = @_;
            
            my $tx = $MSHS::CONTEXT->tx;
            
            my @routes = @{$self->routes};
            
            while (@routes) {
                my $regex   = shift @routes;
                my $cond    = shift @routes if (ref $routes[0] eq 'HASH');
                my $cb      = shift @routes;
                
                if ($cond && ! _judge($tx->req, $cond)) {
                    next;
                }
                
                if (my @captures = ($tx->req->url->path =~ $regex)) {
                    $cb->(defined $1 ? @captures : ());
                    last;
                }
            }
            
            if (! $tx->res->code) {
                $next->(@args);
            }
        });
        return $self;
    }
    
    sub route {
        my ($self, $regex) = @_;
        push(@{$self->routes}, $regex, {});
        return $self;
    }
    
    sub to {
        my ($self, $cb) = @_;
        push(@{$self->routes}, $cb);
        return $self;
    }
    
    sub via {
        my ($self, $method) = @_;
        return $self->_add_cond(method => $method);
    }
    
    sub _add_cond {
        my ($self, $key, $value) = @_;
        my @routes = @{$self->routes};
        if (ref $routes[$#routes] ne 'HASH') {
            push(@routes, {});
        }
        $routes[$#routes]->{$key} = $value;
        return $self;
    }
    
    sub _judge {
        my ($req, $cond) = @_;
        
        if (defined $cond->{method} && uc $cond->{method} ne uc $req->method) {
            return;
        }
        
        return 1;
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::Plugin::Router - Router [EXPERIMENTAL]

=head1 SYNOPSIS

    $app->plugin(Router => [
        qr{^/index\.html} => sub {
            ### DO SOMETHING
        },
        qr{^/special\.html} => sub {
            ### DO SOMETHING
        },
        qr{^/capture/(.+)-(.+)\.html} => sub {
            my ($a, $b) = @_;
            ### DO SOMETHING
        },
        qr{^/rare/} => {method => 'get'}, sub {
            ### DO SOMETHING
        },
        qr{^/default} => sub {
            ### DO SOMETHING
        },
    ]);
    
    ### OR
    
    $app->plugin(Router => sub {
        my $r = shift;
        $r->route(qr{^/index\.html})->to(sub {
            ### DO SOMETHING
        });
        $r->route(qr{^/special\.html})->to(sub {
            ### DO SOMETHING
        });
        $r->route(qr{^/capture/(.+)-(.+)\.html})->to(sub {
            my ($a, $b) = @_;
            ### DO SOMETHING
        });
        $r->route(qr{^/rare/})->via('get')->to(sub {
            ### DO SOMETHING
        });
        $r->route(qr{^/default})->to(sub {
            ### DO SOMETHING
        });
    });

=head1 DESCRIPTION

=head1 METHODS

=head2 $instance->register($app, $hash_ref, $array_ref)

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
