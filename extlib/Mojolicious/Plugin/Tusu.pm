package Mojolicious::Plugin::Tusu;
use strict;
use warnings;
use Try::Tiny;
use Text::PSTemplate;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util;
use Carp;
use File::Basename;
use File::Spec;
use Mojolicious::Types;
use Mojo::Util 'url_unescape';

    our $APP;
    our $CONTROLLER;
    
    __PACKAGE__->attr('engine');
    __PACKAGE__->attr('extensions_to_render');
    __PACKAGE__->attr('directory_index');
    __PACKAGE__->attr('error_document');
    __PACKAGE__->attr('document_root');
    __PACKAGE__->attr('indexes');
    
    # internal use
    __PACKAGE__->attr('_default_route_set');
    
    sub _check_hash_key {
        my ($hash_ref, @keys) = @_;
        my %keys;
        $keys{$_} = 1 foreach(@keys);
        for my $key (keys %$hash_ref) {
            if (! $keys{$key}) {
                return $key;
            }
        }
    }

    sub register {
        my ($self, $app, $args) = @_;
        
        my $default_args = {
            document_root           => $app->home->rel_dir('public_html'),
            encoding                => 'utf8',
            extensions_to_render    => ['html','htm','xml'],
            directory_index         => ['index.html','index.htm'],
            error_document          => {},
            components              => {},
            indexes                 => 0,
        };
        
        if (my $key = _check_hash_key($args, keys %$default_args)) {
            croak "Unknown argument $key";
        }
        
        $args = {%$default_args, %$args};
        
        if (! -d $args->{document_root}) {
            die qq{Document root "$args->{document_root}" is not a directory};
        }
        
        $app->hook(after_build_tx => sub {
            my $app = $_[1];
            if (! $self->_default_route_set) {
                $self->_default_route_set(1);
                $app->routes
                    ->route('/:template', template => qr{.*})
                    ->name('')
                    ->to(cb => sub {$_[0]->render(handler => 'tusu')});
            }
        });
        
        $app->hook('around_dispatch' => sub {
            my ($next, $c) = @_;
            $self->_dispatch($c->app, $c);
            $next->();
        });
        
        $app->static->paths([$args->{document_root}, $self->_asset]);
        $app->renderer->paths([$args->{document_root}]);
        
        my $engine = Text::PSTemplate->new;
        $engine->set_filter('=', \&Mojo::Util::html_escape);
        $engine->set_filename_trans_coderef(sub {
            _filename_trans($args->{document_root}, $args->{directory_index}, @_);
        });
        
        {
            local $APP = $app;
            $engine->plug(
                'MojoX::Tusu::ComponentBase'            => undef,
                'MojoX::Tusu::Component::Util'          => '',
                'MojoX::Tusu::Component::Mojolicious'   => 'Mojolicious',
                %{$args->{components}}
            );
        }
        
        $engine->set_encoding($args->{encoding});
        
        $self->engine($engine);
        $self->directory_index($args->{directory_index});
        $self->error_document($args->{error_document});
        $self->extensions_to_render($args->{extensions_to_render});
        $self->document_root($args->{document_root});
        $self->indexes($args->{indexes});
        
        $app->renderer->add_handler(tusu => sub { $self->_render(@_) });
        
        return $self;
    }
    
    sub get_component {
        my ($self, $name) = @_;
        return $self->engine->get_plugin($name);
    }
    
    ### ---
    ### bootstrap for frameworking
    ### ---
    sub bootstrap {
        my ($self, $c, $component, $action, @args) = @_;
        local $CONTROLLER = $c;
        return $self->engine->get_plugin($component)->$action(@args);
    }
    
    ### ---
    ### Custom dispatcher
    ### ---
    sub _dispatch {
        my ($self, $app, $c) = @_;
        
        my $tx = $c->tx;
        if ($tx->is_websocket) {
            $c->res->code(undef);
        }
        $app->sessions->load($c);
        my $plugins = $app->plugins;
        $plugins->emit_hook(before_dispatch => $c);
        
        my $path = $tx->req->url->path->to_string || '/';
        
        my $not_found;
        
        my $check_result = $self->_check_file_type($path);
        
        if (! $check_result->{type}) {
            if ($path =~ qr{/$} && $self->indexes) {
                $self->_render_indexes($c);
                return;
            } else {
                $not_found = 1;
            }
        } elsif ($check_result->{type} eq 'directory') {
            $c->redirect_to($path. '/');
            $tx->res->code(301);
            return;
        } elsif (! _permission_ok($check_result->{path}, $app->static->paths->[0])) {
            $self->_render_error_document($c, 403);
            return;
        }
        
        if (! $not_found) {
            
            my $path = $check_result->{path};
            
            ### dynamic content
            for my $ext (@{$self->extensions_to_render}) {
                if ($path !~ m{\.} || $path =~ m{\.$ext$}) {
                    my $res = $tx->res;
                    if (my $code = ($tx->req->error)[1]) {
                        $res->code($code)
                    } elsif ($tx->is_websocket) {
                        $res->code(426)
                    }
                    if (! $app->routes->dispatch($c) || ! $res->code) {
                        $c->render_not_found;
                    }
                    return;
                }
            }
            
            ## This must not be happen
            if ($path =~ m{((\.(cgi|php|rb))|/)$}) {
                $self->_render_error_document($c, 403);
                return;
            }
        }
        
        my $relpath =
            ($check_result->{path})
                ? File::Spec->abs2rel($check_result->{path}, $app->static->paths->[0])
                : $path;
        ### defaults to static content
        if ($app->static->serve($c, $relpath)) {
            $c->stash->{'mojo.static'} = 1;
            $c->rendered;
        }
        if (! $tx->res->code) {
            $self->_render_error_document($c, 404);
        }
        $plugins->emit_hook_reverse(after_static_dispatch => $c);
    }

    ### ---
    ### Asset directory
    ### ---
    sub _asset {
        my ($class, $path) = @_;
        if ($path) {
            return File::Spec->catfile(dirname(__FILE__), 'Tusu', 'Asset', $path);
        }
        return File::Spec->catdir(dirname(__FILE__), 'Tusu', 'Asset');
    }
    
    sub _file_to_mime_class {
        my $name = shift;
        my $ext = ($name =~ qr{\.(\w+)$}) ? $1 : '';
        return (split('/', Mojolicious::Types->type($ext) || 'text/plain'))[0];
    }
    
    sub _file_timestamp {
        my $path = shift;
        my @dt = localtime((stat($path))[9]);
        return sprintf('%d-%02d-%02d %02d:%02d', 1900 + $dt[5], $dt[4] + 1, $dt[3], $dt[2], $dt[1]);
    }
    
    sub _file_size {
        my $path = shift;
        return ((stat($path))[7] > 1024)
            ? sprintf("%.1f",(stat($path))[7] / 1024) . 'KB'
            : (stat($path))[7]. 'B';
    }
    
    ### ---
    ### Render file list
    ### ---
    sub _render_indexes {
        my ($self, $c) = @_;
        my $req_path = url_unescape($c->tx->req->url->path);
        utf8::decode($req_path);
        my $dir = $self->document_root() . $req_path;
        
        opendir(my $DIR, $dir);
        my @file = readdir($DIR);
        closedir $DIR;
        
        my @dataset = ();
        for my $file (@file) {
            utf8::decode($file);
            $file = url_unescape($file);
            if ($file =~ qr{^\.$} || $req_path =~ qr{^/$} && $file =~ qr{^\.\.$}) {
                next;
            }
            my $path = $dir. $file;
            push(@dataset, {
                name        => -f $path ? $file : $file. '/',
                timestamp   => _file_timestamp($path),
                size        => _file_size($path),
                type        => -f $path ? _file_to_mime_class($file) : 'dir',
            });
        }
        @dataset = sort {
            ($a->{type} ne 'dir') <=> ($b->{type} ne 'dir')
            ||
            $a->{name} cmp $b->{name}
        } @dataset;
        my $tpl = Text::PSTemplate->new;
        $tpl->set_var(dir => $req_path, dataset => \@dataset);
        $c->render_text($tpl->parse_file($self->_asset('file_list.html')));
    }
    
    ### ---
    ### Render Error document
    ### ---
    sub _render_error_document {
        my ($self, $c, $code, $debug_message) = @_;
        
        $debug_message ||= 'Unknown Error';
        
        $c->app->log->debug($debug_message);
        
        if ($c->app->mode eq 'production') {
            if (my $template = $self->error_document->{$code}) {
                $c->render(handler => 'tusu', template => $template);
                $c->rendered($code);
                return;
            }
        }
        if ($code == 404) {
            $c->render_not_found;
        } else {
            $c->render_exception($debug_message);
        }
        $c->res->code($code);
    }
    
    ### ---
    ### fill directory_index candidate
    ### ---
    sub _fill_filename {
        my ($path, $directory_index) = @_;
        for my $default (@{$directory_index}) {
            my $path = File::Spec->catfile($path, $default);
            if (-f $path) {
                return $path;
            }
        }
        return;
    }
    
    ### ---
    ### find file and type
    ### ---
    sub _check_file_type {
        my ($self, $name) = @_;
        $name ||= '';
        my $leading_slash  = (substr($name, 0, 1) eq '/');
        my $trailing_slash = (substr($name, -1, 1) eq '/');
        $name =~ s{^/}{};
        my $path = File::Spec->catfile($self->document_root, $name);
        if (-f $path) {
            return {type => 'file', path => $path};
        }
        if ($trailing_slash) {
            if (my $fixed_path = _fill_filename($path, $self->directory_index)) {
                return {type => 'file', path => $fixed_path};
            }
        } elsif (-d $path) {
            return {type => 'directory'};
        }
        return {};
    }
    
    ### ---
    ### foo/bar.html    -> public_html/foo/bar.html
    ### foo/            -> public_html/foo/index.html
    ### foo             -> public_html/foo
    ### ---
    sub _filename_trans {
        my ($template_base, $directory_index, $name) = @_;
        $name ||= '';
        my $leading_slash = substr($name, 0, 1) eq '/';
        my $trailing_slash = substr($name, -1, 1) eq '/';
        $name =~ s{^/}{};
        my $dir;
        if ($leading_slash) {
            $dir = $template_base;
        } else {
            $dir = (File::Spec->splitpath(Text::PSTemplate->get_current_filename))[1];
        }
        my $path = File::Spec->catfile($dir, $name);
        if ($trailing_slash) {
            if (my $fixed_path = _fill_filename($path, $directory_index)) {
                return $fixed_path;
            }
        }
        return $path;
    }
    
    ### ---
    ### Check if others readable
    ### ---
    sub _permission_ok {
        my ($name, $base) = @_;
        $base ||= '';
        if ($^O eq 'MSWin32') {
            return 1;
        }
        if ($name && -f $name && ((stat($name))[2] & 4)) {
            $name =~ s{(^|/)[^/]+$}{};
            while (-d $name) {
                if ($name eq $base) {
                    return 1;
                }
                if (! ((stat($name))[2] & 1)) {
                    return 0;
                }
                $name =~ s{(^|/)[^/]+$}{};
            }
            return 1;
        }
        return 0;
    }
    
    ### ---
    ### tusu renderer
    ### ---
    sub _render {
        my ($self, $renderer, $c, $output, $options) = @_;
        
        try {
            local $SIG{__DIE__} = undef;
            local $CONTROLLER = $c;
            $$output = Text::PSTemplate ->new($self->engine)
                                        ->parse_file('/'. $options->{template});
        } catch {
            my $err = $_ || 'Unknown Error';
            $c->app->log->error(qq(Template error in "$options->{template}": $err));
            $self->_render_error_document($c, 500, "$err");
            $$output = '';
            return 0;
        };
        return 1;
    }

1;

__END__

=head1 NAME

Mojolicious::Plugin::Tusu - Apache-like dispatcher for Mojolicious

=head1 SYNOPSIS

    use Mojolicious::Plugin::Tusu;

For non lite app

    sub startup {
        my $self = shift;
        my $tusu = $self->plugin(tusu => {});
    }

OR

    sub startup {
        my $self = shift;
        my $tusu = $self->plugin(tusu => {
            document_root => $self->home->rel_dir('www2'),
            components => {
                'Your::Component' => 'YC',
            },
            extensions_to_render => [qw(html htm xml txt)],
        });
        
        $r->route('/specific/path')->to(cb => sub {
            $tusu->bootstrap($_[0], 'Your::Component', 'your_method');
        });
    }

For lite app

    my $tusu = plugin tusu => {...};

=head1 DESCRIPTION

C<Mojolicious::Plugin::Tusu> is a sub framework on Mojolicious using
Text::PSTemplate for renderer. With this framework, you can deploy directory
based web sites onto Mojolicious at once.

This framework automatically activate own dispatcher which behaves like apache
web server. You can build your web site into single document root directory
named public_html in hierarchal structure. The document root directory can
contain both server-parsed-documents and static files such as images.

Mojolicious::Plugin::Tusu doesn't require files to be named like index.html.ep
style but just like index.html. You can specify which files to be server
parsable by telling it the extensions. It also provides some more apache-like
features such as directory_index, error_document and file permissions checking.

One of the intent of this module is to enhance existing static websites into
dynamic with minimal effort. The chances are that most typical website data are
transplantable with no change at all.

=head1 OPTIONS

=head2 document_root => string

This option sets root directory for templates and static files. Following
example is default setting.

    my $tusu = $self->plugin(tusu => {
        document_root => $self->home->rel_dir('public_html')
    });

=head2 components => hash

    my $tusu = $self->plugin(tusu => {
        components => {
            'Namespace::A' => 'A',   # namespace is A
            'Namespace::B' => '',    # namespace is ''
            'Namespace::C' => undef, # namespace is Namespace::C
        },
    });

=head2 encoding => string or array ref

This option sets encoding for template files. Array ref causes auto detection
active.

    my $tusu = $self->plugin(tusu => {
        encoding => 'Shift-JIS',
    });
    
    or..
    
    my $tusu = $self->plugin(tusu => {
        encoding => ['Shift-JIS', 'utf8'],
    });

=head2 directory_index => array ref

This option sets default file names for searching files in directory when
the request path doesn't ended with file name. And this setting also affects to
inside template context such as include('path') function. Following example is
the default setting.

    my $tusu = $self->plugin(tusu => {
        directory_index => ['index.html', 'index.htm'],
    });

=head2 indexes => bool

This option emulates apache's indexes option. When the value is 1,
the server generates file list page for directory access.

    my $tusu = $self->plugin(tusu => {
        indexes => 1,
    });

=head2 extensions_to_render => array ref

This option sets the extensions to be parsed by tusu renderer. If request
doesn't match any of extensions, dispatcher try to render it as static file.
Following setting is the default.

    my $tusu = $self->plugin(tusu => {
        extensions_to_render => ['html','htm','xml'],
    });

=head2 error_document => hash ref

This option setup custom error pages like apache's ErrorDocument.

    my $tusu = $self->plugin(tusu => {
        error_document => {
            404 => '/errors/404.html',
            403 => '/errors/403.html',
            500 => '/errors/405.html',
        },
    });

=head1 METHODS

=head2 Mojolicious::Plugin::Tusu->new($app)

Constructor. 
    
    $tusu = Mojolicious::Plugin::Tusu->new($app)

=head2 $instance->register($app)

This method internally called.

=head2 $instance->engine

This returns Text::PSTemplate instance. You can customize the template system
behavior by calling parser methods directly.
    
    my $tusu = Mojolicious::Plugin::Tusu->new($app);
    my $pst = $tusu->engine;
    $pst->set_delimiter('<!--', '-->');

=head2 $instance->bootstrap($controller, $component, $method)

This method is a sub dispatcher method. You can specify a class and a method the
route to be dispatched to.

    my $tusu = Mojolicious::Plugin::Tusu->new($self);
    $r->route('/some/path')->via('post')->to(cb => sub {
        $tusu->bootstrap($c, 'Your::Component', 'post');
    });

=head2 $instance->get_component($name)

This is an alias to Text::PSTemplate->get_plugin. With this method, you can get
component instance.

    my $component = $tusu->get_component('Your::Component');

=head1 What does Tusu mean?

Tusu means mojo in Ainu languages which is spoken by the native inhabitants of
Hokkaido prefecture, Japan.

=head1 SEE ALSO

L<Mojolicious>, L<Text::PSTemplate>

L<http://en.wikipedia.org/wiki/Ainu_languages>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
