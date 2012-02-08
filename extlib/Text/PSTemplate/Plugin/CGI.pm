package Text::PSTemplate::Plugin::CGI;
use strict;
use warnings;
use utf8;
use base qw(Text::PSTemplate::PluginBase);
use CGI;

    my $a = CGI->new;
    
    sub query : TplExport {
        my ($self, $name) = @_;
        return $a->param($name);
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::CGI - CGI

=head1 DESCRIPTION

=head1 SYNOPSIS

This is a Plugin for Text::PSTemplate. This adds some functions related to
Environment variables into your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::CGI', '');

=head1 TEMPLATE FUNCTIONS

=head2 query

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
