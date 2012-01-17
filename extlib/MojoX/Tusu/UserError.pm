package MojoX::Tusu::UserError;
use strict;
use warnings;

    sub new {
        return bless [], shift;
    }
    
    sub stack {
        my ($self, $err) = @_;
        push(@$self, $err);
        return $self;
    }
    
    sub count {
        my ($self) = @_;
        return scalar @$self;
    }
    
    sub array {
        my ($self) = @_;
        return @$self;
    }
    
    sub each {
        my ($self) = @_;
        my @array = @$self;
		return Text::PSTemplate::Plugin::Control->each(\@array, @_);
    }

1;

__END__

=head1 NAME

MojoX::Tusu::ComponentBase::UserError - User error container

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 MojoX::Tusu::ComponentBase::UserError->new

=head2 $instance->stack($error);

=head2 $instance->count;

=head2 $instance->array;

=head1 SEE ALSO

L<Text::PSTemplate>, L<Mojolicious::Plugin::Renderer>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
