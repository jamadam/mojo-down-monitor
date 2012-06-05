package MojoSimpleHTTPServer::ErrorDocument;
use strict;
use warnings;
use Mojo::Base -base;
use Mojo::Cache;
use Mojo::Util qw'encode';
    
    my %messages = (
        404 => 'File Not Found',
        500 => 'Internal Server Error',
        403 => 'Forbidden',
    );
    
    my $type = Mojolicious::Types->new->type('html');
    
    __PACKAGE__->attr('template', sub {
        MojoSimpleHTTPServer::asset('error_document.html.ep');
    });
    
    __PACKAGE__->attr('status_template' => sub {{}});
    
    ### --
    ### Serve error document
    ### --
    sub serve {
        my ($self, $code, $message) = @_;
        
        $message ||= $messages{$code};
        
        my $context     = $MSHS::CONTEXT;
        my $tx          = $context->tx;
        my $stash       = $context->stash;
        my $template    = ($self->status_template)->{$code} || $self->template;
        my $ep          = $context->app->ssi_handlers->{ep};
        
        if ($context->app->under_development) {
            my $snapshot = $stash->clone;
            $ep->add_function(snapshot => sub {$snapshot});
            $stash->set(
                static_dir  => 'static',
                code        => $code,
                message     =>
                    ref $message ? $message : Mojo::Exception->new($message),
            );
            $template = MojoSimpleHTTPServer::asset('debug_screen.html.ep');
        } else {
            $stash->set(
                static_dir  => 'static',
                code        => $code,
            );
            $stash->set(message => ref $message ? $messages{$code} : $message);
        }
        
        $tx->res->code($code);
        $tx->res->body(encode('UTF-8', $ep->render_traceable($template)));
        $tx->res->headers->content_type($type);
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::ErrorDocument - ErrorDocument

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

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
