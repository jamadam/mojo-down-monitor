package MojoX::Tusu::ComponentBase;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Mojo::Base;
    
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
    
    sub _dummy : TplExport {
        
    }
    
    sub controller {
        
        return $Mojolicious::Plugin::Tusu::CONTROLLER;
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

=head1 SEE ALSO

L<Text::PSTemplate>, L<Mojolicious::Plugin::Renderer>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
