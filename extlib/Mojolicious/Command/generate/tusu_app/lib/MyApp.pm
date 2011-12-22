package <<% $class %>>;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;
    my $tusu = $self->plugin(tusu => {
        components => {
            '<<% $class %>>::YourComponent' => 'YC'
        },
        error_document => {
            404 => '/error_document/404.html',
        },
        extensions_to_render    => [qw(html htm xml)],
        encoding                => ['Shift_JIS', 'utf8'],
        document_root           => $self->home->rel_dir('public_html'),
    });
    
    # special route
    my $r = $self->routes;
    $r->route('/inquiry/')->via('post')->to(cb => sub {
        $tusu->bootstrap($_[0], '<<% $class %>>::YourComponent', 'post');
    });
}

1;

__END__

=head1 NAME <<% $class %>>

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
