package MojoX::Tusu::ComponentBase;
use strict;
use warnings;
use Mojo::Base;
use MojoX::Tusu::UserError;
use base qw(Text::PSTemplate::PluginBase);

    sub attr {
        Mojo::Base::attr(@_);
    }

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        $self->init($Mojolicious::Plugin::Tusu::APP);
        return $self;
    }
    
    sub init {
        ### Must be implemented on sub classes.
    }
	
	sub component : TplExport {
		my ($self, $name) = @_;
        if ($name) {
    		return $self->get_engine->get_plugin($name);
        }
		return $self;
	}
    
    sub _dummy : TplExport {
        
    }
    
    sub controller {
        return $Mojolicious::Plugin::Tusu::CONTROLLER;
    }
    
    sub render {
        my ($self) = shift;
        my $c = $Mojolicious::Plugin::Tusu::CONTROLLER;
        $c->render(
            handler => 'tusu',
            template => $c->req->url->path->to_string,
            @_
        );
    }
	
	sub redirect_to {
		my ($self, $url) = @_;
		my $c = $self->controller;
		
		my $base;
		if ($ENV{REQUEST_URI}) {
			$base = $c->req->url->base->clone->path($ENV{REQUEST_URI})->to_abs;
		} else {
			$base = $c->req->url->clone->to_abs;
		}
		$base->userinfo(undef);
		
		my $res     = $c->res;
		my $headers = $res->headers;
		$headers->location(Mojo::URL->new($url)->base($base)->to_abs);
		$c->rendered($res->is_status_class(300) ? undef : 302);
		return $c;
	}
    
	### ---
	### user_error
	### ---
    sub user_err : TplExport {
        my ($self) = @_;
        my $c = $self->controller;
        if (! $c->stash('user_err')) {
            $c->stash('user_err', MojoX::Tusu::UserError->new)
        }
        return $c->stash('user_err');
    }

1;

__END__

=head1 NAME

MojoX::Tusu::ComponentBase - Base Class for WAF component

=head1 SYNOPSIS
    
    package YourComponent;
    use strict;
    use warnings;
    use base qw(MojoX::Tusu::ComponentBase);
    
    sub your_action1 {
        my ($self, $controller) = @_;
        $controller->render(
            handler => 'tusu',
            format  => 'html',
            template => 'some_template',
        );
    }
    sub your_action2 {
        my ($self, $controller) = @_;
        # ...
    }
    # ...
    sub some_func : TplExport {
        my ($self, @your_args) = @_;
        # ...
        return '';
    }
    
    <% YourComponent::some_func(@your_args) %>
    <% YourComponent::component() %>

=head1 DESCRIPTION

C<MojoX::Tusu::ComponentBase> is a Component Base class for
MojoX::Tusu sub framework on mojolicious. This class inherits
all methods from Text::PSTemplate::PluginBase.

=head1 METHODS

=head2 controller

Returns current Mojolicious::Controller instance.

=head2 $self->init($app)

This is a hook method for initializing component. This will automatically be
called from constructor.

=head2 $instance->attr

=head2 $class->new

=head2 $instance->redirect_to

This is a wrapper method for $c->redirect_to to avoid using PATH_INFO on CGI
environment.

    $self->redirect_to('./foo.html');
    $self->redirect_to('/foo/bar.html');
    $self->redirect_to('http://example.com/foo/bar.html');
    $self->redirect_to('/');

=head2 $instance->component($class)

Returns component instance of given class. If $class is null, this returns
current class instance.

=head2 $instance->user_error

=head1 SEE ALSO

L<Text::PSTemplate>, L<Mojolicious::Plugin::Renderer>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
