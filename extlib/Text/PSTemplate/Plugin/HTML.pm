package Text::PSTemplate::Plugin::HTML;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
    
    ### ---
    ### escape
    ### ---
    sub escape : TplExport {
        my ($self, $html) = @_;
        $html =~ s/&/&amp;/go;
        $html =~ s/</&lt;/go;
        $html =~ s/>/&gt;/go;
        $html =~ s/"/&quot;/go;
        $html =~ s/'/&#39;/go;
        return $html;
    }
    
    ### ---
    ### replace linebreaks to <br /> tag
    ### ---
    sub linebreak2br : TplExport {
        my ($self, $str) = @_;
        $str =~ s{\r\n|\r|\n}{<br />}g;
        return $str;
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::HTML - 

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds some functions related to
Environment variables into your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::HTML', '');

=head1 TEMPLATE FUNCTIONS

=head2 escape($html)

=head2 linebreak2br($html)

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
