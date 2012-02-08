package Text::PSTemplate::File;
use strict;
use warnings;
use Fcntl qw(:flock);
use Carp;
use Encode;
use Encode::Guess;

    my $MEM_FILENAME    = 1;
    my $MEM_CONTENT     = 2;
    my $MEM_ENCODE      = 3;
    
    sub new {
        my ($class, $name, $encode) = @_;
        $encode ||= 'utf8';
        
        if (! $name) {
            die "file name is empty\n";
        }
        
        if (! -f $name) {
            die "$name is not found\n";
        }
        
        open(my $fh, "<", $name) || die "File '$name' cannot be opened\n";
        
        if ($fh and flock($fh, LOCK_EX)) {
            my $out = do { local $/; <$fh> };
            close($fh);
            
            if (ref $encode) {
                my $guess = guess_encoding($out, @$encode);
                if (ref $guess) {
                    $out = Encode::decode($guess, $out);
                    $encode = $guess->name;
                } else {
                    if (my $parent = $Text::PSTemplate::current_file) {
                        my $parent_encode = $parent->detected_encoding;
                        $out = Encode::decode($parent_encode, $out);
                        $encode = $parent_encode;
                    } else {
                        $out = Encode::decode($encode->[0], $out);
                        $encode = $encode->[0];
                    }
                }
            } else {
                $out = Encode::decode($encode, $out);
            }
            
            return bless {
                $MEM_FILENAME   => $name,
                $MEM_CONTENT    => $out,
                $MEM_ENCODE     => $encode,
            }, $class;
        } else {
            die "File '$name' cannot be opened\n";
        }
    }
    
    sub name {
        return $_[0]->{$MEM_FILENAME};
    }
    
    sub content {
        return $_[0]->{$MEM_CONTENT};
    }
    
    sub detected_encoding {
        return $_[0]->{$MEM_ENCODE};
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Block - A Class represents template blocks

=head1 SYNOPSIS
    
    $file_obj = Text::PSTemplate::File->new($filename);
    $file_obj->content;
    $file_obj->name;

=head1 DESCRIPTION

This class represents template files. With this class, you can take file
contents with the original file path. This class instance can be thrown at
parse_file method and parse_str method. This is useful if you have to iterate
template parse for same file.

=head1 METHODS

=head2 TEXT::PSTemplate::File->new($filename, [$encode or $encode_array_ref])

Constructor. The filename must be given in string. 

=head2 $instance->name

Returns file name may be with path name.

=head2 $instance->content

Returns file content.

=head2 $instance->detected_encoding

Returns file encoding.

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
