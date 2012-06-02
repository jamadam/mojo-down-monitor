package MojoSimpleHTTPServer::Plugin::AutoIndex;
use strict;
use warnings;
use Mojo::Base 'MojoSimpleHTTPServer::Plugin';
use Mojo::Util qw'url_unescape encode decode';
    
    ### --
    ### Register the plugin into app
    ### --
    sub register {
        my ($self, $app, $args) = @_;
        
        push(@{$app->roots}, $self->_asset());
        
        $app->hook(around_dispatch => sub {
            my ($next, @args) = @_;
            
            $next->();
            
            my $context = $MojoSimpleHTTPServer::CONTEXT;
            
            if (! $context->tx->res->code) {
                my $app = $context->app;
                my $path = $context->tx->req->url->path->clone->canonicalize;
                if (@{$path->parts}[0] && @{$path->parts}[0] eq '..') {
                    return;
                }
                if (-d File::Spec->catdir($app->document_root, $path)) {
                    $self->_serve_index($path);
                }
            }
        });
    }
    
    ### ---
    ### Render file list
    ### ---
    sub _serve_index {
        my ($self, $path) = @_;
        
        my $context = $MojoSimpleHTTPServer::CONTEXT;
        my $app = $context->app;
        
        $path = decode('UTF-8', url_unescape($path));
        my $dir = File::Spec->catdir($app->document_root, $path);
        
        opendir(my $DIR, $dir);
        my @file = readdir($DIR);
        closedir $DIR;
        
        my @dset = ();
        for my $file (@file) {
            $file = url_unescape(decode('UTF-8', $file));
            if ($file =~ qr{^\.$} || $file =~ qr{^\.\.$} && $path eq '/') {
                next;
            }
            my $fpath = File::Spec->catfile($dir, $file);
            my $name;
            my $type;
            if (-f $fpath) {
                $name = $file;
                $name =~ s{(\.\w+)$app->{_handler_re}}{$1};
                $type = (($app->path_to_type($name) || 'text') =~ /^(\w+)/)[0];
            } else {
                $name = $file. '/';
                $type = 'dir';
            }
            push(@dset, {
                name        => $name,
                type        => $type,
                timestamp   => _file_timestamp($fpath),
                size        => _file_size($fpath),
            });
        }
        
        @dset = sort {
            ($a->{type} ne 'dir') <=> ($b->{type} ne 'dir')
            ||
            $a->{name} cmp $b->{name}
        } @dset;
        
        my $tx = $context->tx;
        $context->stash->set(
            dir         => $path,
            dataset     => \@dset,
            static_dir  => 'static'
        );
        
        $tx->res->body(
            encode('UTF-8',
                MojoSimpleHTTPServer::SSIHandler::EPL->new->render_traceable(
                                            __PACKAGE__->_asset('index.epl')))
        );
        $tx->res->code(200);
        $tx->res->headers->content_type($app->types->type('html'));
        
        return $app;
    }

    ### ---
    ### Asset directory
    ### ---
    sub _asset {
        my $class = shift;
        my @seed = (substr(__FILE__, 0, -3), 'Asset');
        if ($_[0]) {
            return File::Spec->catdir(@seed, $_[0]);
        }
        return File::Spec->catdir(@seed);
    }
    
    ### ---
    ### Get file utime
    ### ---
    sub _file_timestamp {
        my $path = shift;
        my @dt = localtime((stat($path))[9]);
        return sprintf('%d-%02d-%02d %02d:%02d',
                            1900 + $dt[5], $dt[4] + 1, $dt[3], $dt[2], $dt[1]);
    }
    
    ### ---
    ### Get file size
    ### ---
    sub _file_size {
        my $path = shift;
        return ((stat($path))[7] > 1024)
            ? sprintf("%.1f",(stat($path))[7] / 1024) . 'KB'
            : (stat($path))[7]. 'B';
    }

1;

__END__

=head1 NAME

MojoSimpleHTTPServer::Plugin::Router - Router [EXPERIMENTAL]

=head1 SYNOPSIS

    $app->load_plugin(Router => {
        qr/index\.html/ => sub {
            my $context = MyApp->context;
            ### DO SOMETHING
        },
        qr/special\.html/ => sub {
            my $context = MyApp->context;
            ### DO SOMETHING
        },
    });

=head1 DESCRIPTION

=head1 METHODS

=head2 $instance->register($app, $hash_ref)

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
