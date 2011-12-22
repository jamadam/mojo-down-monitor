package MojoX::Tusu::Component::Util;
use strict;
use warnings;
use base qw(MojoX::Tusu::ComponentBase);
use Mojo::Util;
use Mojo::DOM;
    
    sub escape : TplExport {
        my ($self, $val) = @_;
        my $c = $self->controller;
        return Mojo::Util::html_escape($val);
    }
    
    sub param : TplExport {
        
        my ($self, $name, $escape) = @_;
        my $c = $self->controller;
        my $val = $c->param($name);
        if ($val && $escape) {
            $val = Mojo::Util::html_escape($val);
        }
        return $val;
    }
    
    sub post_param : TplExport {
        
        my ($self, $name, $escape) = @_;
        my $c = $self->controller;
        my $val = $c->req->body_params->param($name);
        if ($val && $escape) {
            $val = Mojo::Util::html_escape($val);
        }
        return $val;
    }
    
    sub url_abs : TplExport {
        
        my ($self) = @_;
        my $c = $self->controller;
        my $path = $c->url_for(@_[1.. scalar (@_) - 1])->to_abs;
        return bless $path, 'MojoX::Tusu::Component::Util::URL';
    }
    
    sub url_for : TplExport {
        
        my ($self) = @_;
        my $c = $self->controller;
        my $path = $c->url_for(@_[1.. scalar (@_) - 1]);
        return bless $path, 'MojoX::Tusu::Component::Util::URL';
    }
    
    sub html_to_text : TplExport {
        
        my ($self, $html) = @_;
        return Mojo::DOM->new($html)->all_text;
    }

package MojoX::Tusu::Component::Util::URL;
use strict;
use warnings;
use Mojo::Base -base;
use base qw(Mojo::URL);
use File::Basename 'basename';
has base => sub { (ref $_[0])->new };
    
    sub clone {
        my $self = shift;
        return bless $self->SUPER::clone, ref $self;
    }
    
    sub to_string {
        my $self = shift;
        my $path = $self->SUPER::to_string;
        if ($ENV{SCRIPT_NAME}) {
            if (my $rubbish = basename($ENV{SCRIPT_NAME})) {
                $path =~ s{$rubbish/}{};
            }
        }
        return $path;
    }

1;

__END__

=head1 NAME

MojoX::Tusu::Component::Util - Utility functions for template

=head1 SYNOPSIS
    
    <% param(@your_args) %>
    <% post_param(@your_args) %>
    <% url_for(@your_args) %>
    <% escape(@your_args) %>

=head1 DESCRIPTION

=head1 Template Functions

=head2 url_for($path)

Generate a portable Mojo::URL object with base for a route, path or URL. This
also strips script name on CGI environment.

    <% url_for('/path/to/file') %>

=head2 param($name, [$escape])

Returns GET parameter value.

    <% param('key', 1) %>

=head2 post_param($name, [$escape])

Returns POST parameter value.

    <% post_param('key', 1) %>

=head2 escape($val)

Returns HTML escaped string.

    <% escape($value) %>

=head2 url_abs

Short cut for url_for($path)->to_abs()

=head1 SEE ALSO

L<Mojolicious::Controller>, L<Text::PSTemplate>, L<Mojolicious::Plugin::Renderer>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
