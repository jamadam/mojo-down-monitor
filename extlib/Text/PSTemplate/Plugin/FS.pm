package Text::PSTemplate::Plugin::FS;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;

    my $options = {
        e => sub {return -e $_[0]},
        f => sub {return -f $_[0]},
        d => sub {return -d $_[0]},
        M => sub {return -M $_[0]},
        C => sub {return -C $_[0]},
        A => sub {return -A $_[0]},
    };
    
    ### ---
    ### file test
    ### ---
    sub test : TplExport {
        
        my ($self, $path, $opt) = @_;
        return $options->{$opt || 'e'}->($path);
    }
    
    ### ---
    ### file find
    ### ---
    sub find : TplExport {
        
        my ($self, $dir, $regex, $default) = @_;
        
        opendir(my $DIR, $dir) or die "opendir $dir failed";
        
        my @files =
            map {File::Spec->catfile($dir, $_)}
            grep(/$regex/ && -f File::Spec->catfile($dir, $_), readdir($DIR));
        
        close($DIR);
        if (scalar @files) {
            return \@files;
        } else {
            return [$default];
        }
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::File - 

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds some functions related to
Environment variables into your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::FS', '');

Since this has promoted to core plugin, you don't have to explicitly load it.

=head1 TEMPLATE FUNCTIONS

=head2 test($path, $opt)

    <% File::test('path/to/file', 'f') %>

The following options available.

=over

=item e

=item f
    
=item d
    
=item M

=item C

=item A

=back

=head2 FS::find($dir, $regex, $default)

This function checks if files exists and returns file names.

    <% FS::find('path/to/dir', '^my_image.png', 'blank.png') %>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
