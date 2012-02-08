package Text::PSTemplate::Plugin::Env;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
use Text::PSTemplate::Plugin::Control;
    
    ### ---
    ### Get Environment variable
    ### ---
    sub env : TplExport {
        my ($self, $key) = @_;
        return $ENV{$key};
    }
    
    ### ---
    ### Get Environment variable
    ### ---
    sub if_env : TplExport {
        my ($self, $key, @args) = @_;
        return $self->Text::PSTemplate::Plugin::Control::if($ENV{$key}, @args);
    }
    
    ### ---
    ### Get Environment variable
    ### ---
    sub if_env_equals : TplExport {
        my ($self, $key, @args) = @_;
        return $self->Text::PSTemplate::Plugin::Control::if_equals($ENV{$key}, @args);
    }
    
    ### ---
    ### Get Environment variable
    ### ---
    sub if_env_like : TplExport {
        my ($self, $key, @args) = @_;
        return $self->Text::PSTemplate::Plugin::Control::if_like($ENV{$key}, @args);
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Env - Environment functions

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds some functions related to
Environment variables into your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Env', '');

Since this has promoted to core plugin, you don't have to explicitly load it.

=head1 TEMPLATE FUNCTIONS

Note that this document contains many keywords for specifying block endings such
as THEN or ELSE etc. These keywords are just examples. As the matter of
fact, you can say 'EOF' for any of them. The template engine only matters the
order of blocks. Think of Perl's here document. That's it. 
So do not attempt to memorize them. 

=head2 env($name)

Not written yet.

=head2 if_env($name, $then, $else)

=head2 if_env($name)<<THEN,ELSE

Not written yet.

=head2 if_env_equals($name, $then, $else)

=head2 if_env_equals($name)<<THEN,ELSE

Not written yet.

=head2 if_env_like($name, $pattern, $then, $else)

=head2 if_env_like($name, $pattern)<<THEN,ELSE

Not written yet.

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
