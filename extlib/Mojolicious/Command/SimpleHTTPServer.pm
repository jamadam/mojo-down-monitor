package Mojolicious::Command::SimpleHTTPServer;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Commands';

use Getopt::Long 'GetOptions';
use Mojo::Server::Daemon;
use MojoSimpleHTTPServer;

  has description => <<'EOF';
Start SimpleHTTPServer.
EOF

  has usage => <<"EOF";
usage: $0 SimpleHTTPServer [OPTIONS]

These options are available:
  
  -dr, --document_root <path>  Set document root path, defaults to current dir.
  -df, --default_file <name>   Set default file name and activate auto fill.
  -ai, --auto_index            Activate auto index, defaults to 0.
  -ud, --under_development     Activate debug screen for server-side include.
  -b, --backlog <size>         Set listen backlog size, defaults to
                               SOMAXCONN.
  -c, --clients <number>       Set maximum number of concurrent clients,
                               defaults to 1000.
  -g, --group <name>           Set group name for process.
  -i, --inactivity <seconds>   Set inactivity timeout, defaults to the value
                               of MOJO_INACTIVITY_TIMEOUT or 15.
  -l, --listen <location>      Set one or more locations you want to listen
                               on, defaults to the value of MOJO_LISTEN or
                               "http://*:3000".
  -p, --proxy                  Activate reverse proxy support, defaults to
                               the value of MOJO_REVERSE_PROXY.
  -r, --requests <number>      Set maximum number of requests per keep-alive
                               connection, defaults to 25.
  -u, --user <name>            Set username for process.
EOF

# "It's an albino humping worm!
#  Why do they call it that?
#  Cause it has no pigment."
sub run {
  $ENV{MOJO_APP} ||= 'MojoSimpleHTTPServer';
  my $self   = shift;
  
  my $app = MojoSimpleHTTPServer->new;
  my $daemon = Mojo::Server::Daemon->new;
  $daemon->app($app);

  # Options
  local @ARGV = @_;
  my @listen;
  GetOptions(
    'b|backlog=i'           => sub { $daemon->backlog($_[1]) },
    'c|clients=i'           => sub { $daemon->max_clients($_[1]) },
    'g|group=s'             => sub { $daemon->group($_[1]) },
    'i|inactivity=i'        => sub { $daemon->inactivity_timeout($_[1]) },
    'l|listen=s'            => \@listen,
    'p|proxy'               => sub { $ENV{MOJO_REVERSE_PROXY} = 1 },
    'r|requests=i'          => sub { $daemon->max_requests($_[1]) },
    'u|user=s'              => sub { $daemon->user($_[1]) },
    'dr|document_root=s'    => sub { $app->document_root($_[1]) },
    'ai|auto_index'         => sub { $app->plugin('AutoIndex') },
    'df|default_file=s'     => sub { $app->default_file($_[1]) },
    'ud|under_development'  => sub { $app->under_development(1) },
  );
  
  $app->document_root || $app->document_root('./');

  # Start
  $daemon->listen(\@listen) if @listen;
  $daemon->run;
}

1;
__END__

=head1 NAME

Mojolicious::Command::SimpleHTTPServer - SimpleHTTPServer command

=head1 SYNOPSIS

  use Mojolicious::Command::SimpleHTTPServer;

  my $app = Mojolicious::Command::SimpleHTTPServer->new;
  $app->run(@ARGV);

=head1 DESCRIPTION

=head1 METHODS

=head2 run

=head1 SEE ALSO

=cut
