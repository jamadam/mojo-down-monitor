package MojoX::Tusu;
use strict;
use warnings;
our $VERSION = '0.29';
$VERSION = eval $VERSION; ## no critic

1;

__END__

=head1 NAME

MojoX::Tusu - Apache-like dispatcher for Mojolicious

=head1 SYNOPSIS

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

C<MojoX::Tusu> is a sub framework on Mojolicious using
Text::PSTemplate for renderer. With this framework, you can deploy directory
based web sites onto Mojolicious at once.

This framework automatically activate own dispatcher which behaves like apache
web server. You can build your web site into single document root directory
named public_html in hierarchal structure. The document root directory can
contain both server-parsed-documents and static files such as images.

MojoX::Tusu doesn't require files to be named like index.html.ep
style but just like index.html. You can specify which files to be server
parsable by telling it the extensions. It also provides some more apache-like
features such as directory_index, error_document and file permissions checking.

One of the intent of this module is to enhance existing static websites into
dynamic with minimal effort. The chances are that most typical website data are
transplantable with no change at all.

=head2 Installation

    $ sudo -s 'curl -L cpanmin.us | perl - https://github.com/jamadam/MojoX-Tusu/tarball/master/v0.25'

=head2 Getting Started

    $ mojo generate tusu_app MyApp
    $ cd ./my_app
    $ prove
    $ ./script/my_app daemon
    Server available at http://127.0.0.1:3000.

=head2 Template Syntax

See L<https://github.com/jamadam/Text-PSTemplate> for detail.

In addition to Text::PSTemplate's default syntax, MojoX::Tusu
provides short cut for html escaping as follows

    <% $var %> normal
    <%= $var %> escaped
    <%= some_func(...) %> escaped

=head2 Components

Mojo::Tusu provides object oriented component framework. You can easily add your
custom features into your website. The following is an example for component
development.

    <span><% questionize('Hello') %></span>

To make it possible, you should write a module like this. 

    package MyUtility;
    use strict;
    use warnings;
    use base 'MojoX::Tusu::ComponentBase';
    
    sub questionize : TplExport {
        my ($self, $sentence) = @_;
        my $c = $self->controller; # mojolicious controller in case you need
        return $sentence . '?';
    }

To activate this component, you must plug-in this at mojolicious startup method.

    sub startup {
        my $self = shift;
        my $tusu = $self->plugin(tusu => {
            components => {
                'YourUtility' =>  '' ## namespace is ''
            }
        });
    }

Here is another example for component development.

    <div id="productContainer">
        <% Product::list_by_category('books', 10) %>
    </div>

To make it possible, you should write a module like this.

    package Product;
    use strict;
    use warnings;
    use base 'MojoX::Tusu::ComponentBase';
    
    __PACKAGE__->attr('some_data');
    
    sub init {
        my ($self, $app) = @_;
        $self->some_data('value'); ### DB SETTING OR SOMETHING
    }
    
    sub list_by_category : TplExport {
        my ($self, $category, $limit) = @_;
        my $c = $self->controller; # mojolicious controller in case you need
        
        # MAY BE ACCESS TO YOUR DB HERE
        
        return $html_snippet;
    }

To activate this component, you must plug-in this at mojolicious startup method.

    sub startup {
        my $self = shift;
        my $tusu = $self->plugin(tusu => {
            components => {
                Product => undef
            },
        });
    }

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
