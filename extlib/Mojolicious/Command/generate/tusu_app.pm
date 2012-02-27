package Mojolicious::Command::generate::tusu_app;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Command::generate::app';
use Text::PSTemplate;
use Text::PSTemplate::File;
use File::Basename;
use File::Spec;
use File::Path;
use File::Copy;
use LWP::Simple;

has description => <<'EOF';
Generate Tusu application directory structure.
EOF
has usage => <<"EOF";
usage: $0 generate tusu app [NAME]
EOF

# "I say, you've damaged our servants quarters... and our servants."
sub run {
    my ($self, $class) = @_;
    $class ||= 'MyTusuApp';
    
    # Prevent bad applications
    die <<EOF unless $class =~ /^[A-Z](?:\w|\:\:)+$/;
Your application name has to be a well formed (camel case) Perl module name
like "MyApp".
EOF

    # Script
    my $app = $self->class_to_file($class);
    $self->render_to_rel_file($class, "script/my_app", 'script/<<% $app %>>');
    $self->chmod_file("$app/script/$app", oct(744));
    $self->render_to_rel_file($class, "lib/MyApp.pm", 'lib/<<% $class %>>.pm');
    $self->render_to_rel_file($class, "lib/MyApp/YourComponent.pm", 'lib/<<% $class %>>/YourComponent.pm');
    $self->render_to_rel_file($class, "t/basic.t");
    $self->render_to_rel_file($class, 'public_html/index.cgi');
    $self->render_to_rel_file($class, 'public_html/index.html');
    $self->render_to_rel_file($class, 'public_html/copyright.html');
    $self->render_to_rel_file($class, 'public_html/htmlhead.html');
    $self->render_to_rel_file($class, 'public_html/commons/index.css');
    $self->render_to_rel_file($class, 'public_html/inquiry/index.html');
    $self->render_to_rel_file($class, 'public_html/inquiry/thanks.html');
    $self->render_to_rel_file($class, 'public_html/error_document/404.html');
    $self->render_to_rel_file($class, 'public_html/.htaccess');
    $self->create_rel_dir("$app/log");
    
    print "  [bundle distribution] Tusu\n";
    my @bundle = qw(
        lib/Mojolicious/Command/generate/tusu_app.pm
        lib/Mojolicious/Command/generate/tusu_app/lib/MyApp.pm
        lib/Mojolicious/Command/generate/tusu_app/lib/MyApp/YourComponent.pm
        lib/Mojolicious/Command/generate/tusu_app/public_html/.htaccess
        lib/Mojolicious/Command/generate/tusu_app/public_html/commons/index.css
        lib/Mojolicious/Command/generate/tusu_app/public_html/copyright.html
        lib/Mojolicious/Command/generate/tusu_app/public_html/error_document/404.html
        lib/Mojolicious/Command/generate/tusu_app/public_html/htmlhead.html
        lib/Mojolicious/Command/generate/tusu_app/public_html/index.cgi
        lib/Mojolicious/Command/generate/tusu_app/public_html/index.html
        lib/Mojolicious/Command/generate/tusu_app/public_html/inquiry/index.html
        lib/Mojolicious/Command/generate/tusu_app/public_html/inquiry/thanks.html
        lib/Mojolicious/Command/generate/tusu_app/script/my_app
        lib/Mojolicious/Command/generate/tusu_app/t/basic.t
        lib/Mojolicious/Plugin/Tusu.pm
        lib/Text/PSTemplate.pm
        lib/Text/PSTemplate/Block.pm
        lib/Text/PSTemplate/DateTime.pm
        lib/Text/PSTemplate/Exception.pm
        lib/Text/PSTemplate/File.pm
        lib/Text/PSTemplate/Plugin/CGI.pm
        lib/Text/PSTemplate/Plugin/Control.pm
        lib/Text/PSTemplate/Plugin/Developer.pod
        lib/Text/PSTemplate/Plugin/Env.pm
        lib/Text/PSTemplate/Plugin/Extends.pm
        lib/Text/PSTemplate/Plugin/FS.pm
        lib/Text/PSTemplate/Plugin/HTML.pm
        lib/Text/PSTemplate/Plugin/Time.pm
        lib/Text/PSTemplate/Plugin/Time2.pm
        lib/Text/PSTemplate/Plugin/TSV.pm
        lib/Text/PSTemplate/Plugin/Util.pm
        lib/Text/PSTemplate/PluginBase.pm
        lib/Tusu.pm
        lib/Tusu/Asset/file_list.html
        lib/Tusu/Asset/tusu_asset/file_list.css
        lib/Tusu/Asset/tusu_asset/file_list.js
        lib/Tusu/Asset/tusu_asset/jquery.1.7.1.js
        lib/Tusu/Asset/tusu_asset/yui-fonts.css
        lib/Tusu/Asset/tusu_asset/yui-reset.css
        lib/Tusu/Component/Mojolicious.pm
        lib/Tusu/Component/Util.pm
        lib/Tusu/ComponentBase.pm
        lib/Tusu/UserError.pm
    );
    for my $file (@bundle) {
        $file =~ s{^lib/}{};
        $self->bundle_lib($class, $file);
    }
}

sub render_to_rel_file {
    my ($self, $class, $path, $path_to) = @_;
    my $app = $self->class_to_file($class);
    my $parser = Text::PSTemplate->new;
    $parser->set_delimiter('<<%', '%>>');
    $parser->set_var(class => $class, app => $app);
    my $template = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), 'tusu_app', $path));
    my $content = $parser->parse_file($template);
    $path_to = $path_to ? $parser->parse($path_to) : $path;
    $self->write_file("$app/". $path_to, $content);
    return $self;
}

sub bundle_lib {
    my ($self, $class, $lib) = @_;
    my $app = $self->class_to_file($class);
    my $path_to = File::Spec->catfile($app,'extlib', $lib);
    $self->create_dir(dirname($path_to));
    copy(find_lib($lib), $path_to);
    print "  [copy] $path_to\n";
    return $self;
}

sub find_lib {
    
    my $name = shift;
    for my $base (@INC) {
        if (-e "$base/$name") {
            return "$base/$name";
        }
    }
    return;
}

sub bundle_dist {
    my ($self, $class, $dist_name) = @_;
    my @libs = eval {
        _get_lib_names($dist_name);
    };
    if ($@) {
        warn $@;
    } else {
        for my $modules (@libs) {
            $self->bundle_lib($class, $modules);
        }
        print "  [bundle distribution] $dist_name\n";
        return $self;
    }
}

sub _get_lib_names {
    my $dist = shift;
    my $uri = "http://cpanmetadb.appspot.com/v1.0/package/$dist";
    if (my $yaml = LWP::Simple::get($uri)) {
        if ($yaml =~ qr{distfile:\s+(.+)\-[\d\.]+\.tar.gz}) {
            my @paths = split(qr{/}, $1);
            my $path = (uc $paths[-2]). '/'. $paths[-1];
            no strict 'refs';
            my $dist_file = $dist;
            $dist_file =~ s{::}{/}g;
            eval {
                require "$dist_file.pm"; ## no critic
            };
            my $ver = ${"$dist\::VERSION"};
            my $uri2 = "http://cpansearch.perl.org/src/$path-$ver/MANIFEST";
            if (my $manifest = LWP::Simple::get($uri2)) {
                return
                    map {my $a = $_; $a =~ s{^lib/}{}; $a}
                    grep {$_ =~ qr{^lib/}}
                    split(qr{\s+}s, $manifest);
            } else {
                die qq{Can't find manifest for $dist via CPAN (maybe your libs are too old?)."
                    ."\nPlease copy your libs into extlib directorymanualy};
            }
        }
    }
}

1;

__END__

=head1 NAME

Mojolicious::Command::generate::tusu_app - Tusu App Generator Command

=head1 SYNOPSIS

  use Mojolicious::Command::generate::tusu_app;

  my $app = Mojolicious::Command::generate::tusu_app->new;
  $app->run(@ARGV);

=head1 DESCRIPTION

L<Mojolicious::Command::generate::app> is a application generator.

=head1 ATTRIBUTES

L<Mojolicious::Command::generate::tusu_app> inherits all attributes from
L<Mojo::Command> and implements the following new ones.

=head2 C<description>

  my $description = $app->description;
  $app            = $app->description('Foo!');

Short description of this command, used for the command list.

=head2 C<usage>

  my $usage = $app->usage;
  $app      = $app->usage('Foo!');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Mojolicious::Command::generate::tusu_app> inherits all methods from
L<Mojo::Command> and implements the following new ones.

=head2 C<run>

  $app->run(@ARGV);

=head2 C<render_to_file>

Not written yet.

=head2 C<render_to_rel_file>

Not written yet.

=head2 C<bundle_dist>

Not written yet.

=head2 C<bundle_lib>

Not written yet.

=head2 C<find_lib>

Not written yet.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
