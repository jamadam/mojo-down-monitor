package MojoSimpleHTTPServer::SSIHandler::EP;
use strict;
use warnings;
use Mojo::Base 'MojoSimpleHTTPServer::SSIHandler::EPL';
use File::Basename 'dirname';
use Mojo::ByteStream;

    ### --
    ### Function definitions for inside template
    ### --
    __PACKAGE__->attr(funcs => sub {{}});
    
    ### --
    ### Add helper
    ### --
    sub add_function {
        my ($self, $name, $cb) = @_;
        $self->funcs->{$name} = $cb;
        return $self;
    }
    
    ### --
    ### ep handler
    ### --
    sub render {
        my ($self, $path) = @_;
        
        if (! $self->cache($path)) {
            my $mt = Mojo::Template->new();
            $mt->auto_escape(1);
            
            # Be a bit more relaxed for helpers
            my $prepend = q/no strict 'refs'; no warnings 'redefine';/;
    
            # Helpers
            $prepend .= 'my $_H = shift;';
            for my $name (sort keys %{$self->funcs}) {
                if ($name =~ /^\w+$/) {
                    $prepend .=
                    "sub $name; *$name = sub {\$_H->funcs->{$name}->(\$_H, \@_)};";
                }
            }
        
            my $context = $MojoSimpleHTTPServer::CONTEXT;
            
            $prepend .= 'use strict;';
            for my $var (keys %{$context->stash}) {
                if ($var =~ /^\w+$/) {
                    $prepend .= " my \$$var = stash '$var';";
                }
            }
            $mt->prepend($prepend);
            
            $self->cache($path, $mt, sub {$_[0] < (stat($path))[9]});
        }
        
        return $self->SUPER::render($path);
    }
    
    ### --
    ### load preset
    ### --
    sub init {
        my ($self) = @_;
        
        $self->funcs->{app} = sub {
            shift;
            return $MojoSimpleHTTPServer::CONTEXT->app;
        };
        
        $self->funcs->{param} = sub {
            shift;
            return $MojoSimpleHTTPServer::CONTEXT->tx->req->param($_[0]);
        };
        
        $self->funcs->{stash} = sub {
            shift;
            my $stash = $MojoSimpleHTTPServer::CONTEXT->stash;
            if ($_[0] && $_[1]) {
                return $stash->set(@_);
            } elsif (! $_[0]) {
                return $stash;
            } else {
                return $stash->{$_[0]};
            }
        };
        
        $self->funcs->{current_template} = sub {
            return shift->current_template(@_);
        };
        
        $self->funcs->{dumper} = sub {
            shift;
            return Data::Dumper->new([@_])->Indent(1)->Terse(1)->Dump;
        };
        
        $self->funcs->{to_abs} = sub {
            return shift->_to_abs(@_);
        };
        
        $self->funcs->{include} = sub {
            my ($self, $path, @args) = @_;
            
            my $c = $MojoSimpleHTTPServer::CONTEXT;
            local $c->{stash} = $c->{stash}->clone;
            $c->{stash}->set(@args);
            return
                Mojo::ByteStream->new($c->app->render_ssi($self->_to_abs($path)));
        };
        
        $self->funcs->{override} = sub {
            my ($self, $name, $value) = @_;
            my $path = $self->current_template;
            $MojoSimpleHTTPServer::CONTEXT->stash->set($name => sub {
                return $self->render_traceable($path, $value);
            });
            return;
        };
        
        $self->funcs->{placeholder} = sub {
            my ($self, $name, $defalut) = @_;
            my $block =
                    $MojoSimpleHTTPServer::CONTEXT->stash->{$name} || $defalut;
            return $block->() || '';
        };
        
        $self->funcs->{extends} = sub {
            my ($self, $path, $block) = @_;
            
            my $c = $MojoSimpleHTTPServer::CONTEXT;
            
            local $c->{stash} = $c->{stash}->clone;
            
            $block->();
            
            return
                Mojo::ByteStream->new($c->app->render_ssi($self->_to_abs($path)));
        };
        
        return $self;
    }
    
    ### --
    ### abs
    ### --
    sub _to_abs {
        my ($self, $path) = @_;
        
        my $path_abs = dirname($self->current_template). '/'. $path;
        
        return $path_abs;
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::SSIHandler::EP - EP template handler

=head1 SYNOPSIS

    $app->add_handler(ep => MojoSimpleHTTPServer::SSIHandler::EP->new);

=head1 DESCRIPTION

EP handler.

=head1 ATTRIBUTES

=head1 FUNCTIONS

=head2 <% current_template() %>

Returns current template path.

=head2 <% extends($path, block) %>

Base template.

    <!doctype html>
    <html>
        <head>
            <title><%= placeholder 'title' => begin %>DEFAULT TITLE<% end %></title>
        </head>
        <body>
            <div id="main">
                <%= placeholder 'main' => begin %>
                    DEFAULT MAIN
                <% end %>
            </div>
            <div id="main2">
                <%= placeholder 'main2' => begin %>
                    DEFAULT MAIN2
                <% end %>
            </div>
        </body>
    </html>

Extended template.

    <%= extends './layout/common.html.ep' => begin %>
        <% override 'title' => begin %>
            title
        <% end %>
        <% override 'main' => begin %>
            <div>
                main content<%= time %>
            </div>
        <% end %>
    <% end %>

Extends template.

=head2 <% include('./path/to/template.html.ep', key => value) %>

Include a template into current template. Note that the path must be relative to
current template directory.

=head2 <% override($name, $block) %>

Override placeholder. See extends method.

=head2 <% param('key') %>

Returns request parameters for given key.

=head2 <% placeholder($name, $default_block) %>

Set placeholder with default block. See extends method.

=head2 <% stash('key') %>

Returns stash value for given key.

=head2 <% to_abs() %>

Generate absolute path with given relative one

=head1 METHODS

=head2 $instance->init

=head2 $instance->new

Constructor.

=head2 $instance->add_function(name => sub {...})

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
