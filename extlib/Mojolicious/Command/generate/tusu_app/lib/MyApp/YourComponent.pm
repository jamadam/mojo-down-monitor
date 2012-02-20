package <<% $class %>>::YourComponent;
use base 'MojoX::Tusu::ComponentBase';

  # This function can be called inside templates.
  sub your_function : TplExport {
    my ($self) = @_;
    my $c = $self->controller;
    return 'your_function called';
  }
  
  sub post {
    my ($self) = @_;
    my $c = $self->controller;
    
    # validate
    
    # sendmail
    
    $c->render(handler => 'tusu', template => '/inquiry/thanks.html');
  }

1;

__END__

=head1 NAME <<% $class %>>::YourComponent

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
