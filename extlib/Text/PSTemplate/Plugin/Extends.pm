package Text::PSTemplate::Plugin::Extends;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
    
    ### ---
    ### Extend
    ### ---
    sub extends : TplExport {
        my ($self, $file) = @_;
        my $tpl = Text::PSTemplate->new;
        $tpl->plug('Text::PSTemplate::Plugin::Extends::_Sub', '');
        $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
        return $tpl->parse_file($file);
    }

package Text::PSTemplate::Plugin::Extends::_Sub;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
    
    ### ---
    ### block specification
    ### ---
    sub block : TplExport {
        my ($self, $name) = @_;
        my $tpl = Text::PSTemplate->get_current_parser;
        $tpl->set_var($name => $tpl->parse_block(0, {chop_left => 1, chop_right => 1}));
        return;
    }
    
    ### ---
    ### placeholder specification
    ### ---
    sub placeholder : TplExport {
        my ($self, $name) = @_;
        my $tpl = Text::PSTemplate::get_current_parser;
        my $val = eval {$tpl->var($name)};
        if ($val) {
            return $val;
        } else {
            return $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
        }
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Extends - Port to extends syntax of Django

=head1 SYNOPSIS

    base.html
    
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    <head>
        <link rel="stylesheet" href="style.css" />
        <title><% placeholder('title')<<DEFAULT %>My amazing site<% DEFAULT %></title>
    </head>
    
    <body>
        <div id="sidebar">
            <% placeholder('sidebar')<<DEFAULT %>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/blog/">Blog</a></li>
            </ul>
            <% DEFAULT %>
        </div>
    
        <div id="content">
            <% placeholder('content')<<DEFAULT %><% DEFAULT %>
        </div>
    </body>
    </html>
    
    child.html
    
    <% extends('base.html')<<EXTENDS %>
        <% block('title')<<BLOCK %>My amazing blog<% BLOCK %>
        <% block('content')<<BLOCK %><% each($blog_entries, 'entry')<<ENTRIES %>
            <h2><% $entry->{title} %></h2>
            <p><% $entry->{body} %></p>
        <% ENTRIES %><% BLOCK %>
    <% EXTENDS %>

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds Common control structures into
your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Control', '');

Since this has promoted to core plugin, you don't have to explicitly load it.

=head1 TEMPLATE FUNCTIONS

=head2 extends

=head2 block

=head2 placeholder

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
