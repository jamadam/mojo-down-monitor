package MojoDownMonitor;
use Mojo::Base 'Mojolicious';
use Text::PSTemplate;
use File::Basename 'dirname';
use Mojo::UserAgent;
use Data::Dumper;
use Time::Piece;
use SQL::OOP::Dataset;
use MojoDownMonitor::Util::Sendmail;
our $VERSION = '0.01';
    
    my $ua = Mojo::UserAgent->new;
    
    sub startup {
        my $self = shift;
        #my $home2 = Mojo::Home->new($self->home);
        $self->app->secret(time());
        $self->home->parse(File::Spec->catdir(dirname(__FILE__), 'MojoDownMonitor'));
        my $tusu = $self->plugin(tusu => {
            components => {
                'MojoDownMonitor::Sites'    => 'Sites',
                'MojoDownMonitor::Log'      => 'Log',
                'MojoDownMonitor::SMTP'     => 'SMTP',
            },
            document_root => $self->home->rel_dir('public_html'),
        });
        
        # special route
        my $r = $self->routes;
        $r->route('/site_list.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::Sites', 'post');
            $self->set_cron($tusu);
        });
        $r->route('/site_new.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::Sites', 'post');
            $self->set_cron($tusu);
        });
        $r->route('/site_edit.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::Sites', 'post');
            $self->set_cron($tusu);
        });
        $r->route('/smtp_edit.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::SMTP', 'post');
            $self->set_cron($tusu);
        });
        
        $self->set_cron($tusu);
    }
    
    my @loop_ids;
    
    sub set_cron {
        my ($self, $tusu) = @_;
        
        while (my $id = shift @loop_ids) {
            Mojo::IOLoop->drop($id);
        }
        
        my $log = $tusu->get_component('MojoDownMonitor::Log');
        my $sth = $tusu->get_component('MojoDownMonitor::Sites')->dump();
        my $smtp = $tusu->get_component('MojoDownMonitor::SMTP');
        while (my $site = $sth->fetchrow_hashref) {
            my $loop_id = Mojo::IOLoop->recurring($site->{'Interval'} => sub {
                my $new_log = $self->check($site);
                if (! $new_log->{OK}) {
                    my $smtp_info = $smtp->server_info;
                    my $sendmail = MojoDownMonitor::Util::Sendmail->new(
                        $smtp_info->value('host'),
                        $smtp_info->value('port'),
                        $smtp_info->value('ssl'),
                        $smtp_info->value('user'),
                        $smtp_info->value('password'),
                    );
                    my @mailto = split(',', $site->{'Mail to'});
                    $sendmail->sendmail(
                        \@mailto,
                        '[ALERT] mojo-down-monitor detected an error',
                        $self->mail_body($site, $new_log),
                    );
                }
                $log->create(SQL::OOP::Dataset->new($new_log));
            });
            push(@loop_ids, $loop_id);
        }
    }
    
    sub check {
        my ($self, $site) = @_;
        my $tx = $ua->get($site->{URI});
        my $res = $tx->res;
        my $code = $res->code;
        my $type = $res->headers->content_type || '';
        my $body = $res->body || '';
        my $err;
        if ($code) {
            $err ||= is($code, $site->{'Status must be'}, qq{Got wrong status '$code'});
            $err ||= is($type, $site->{'MIME type must be'}, qq{Got wrong MIME type '$type'});
            $err ||= is($body, $site->{'Content must match'}, qq{Content doesn't match expectation});
        } else {
            $err ||= $tx->error || 'Unknown error';
        }
        my $time = Time::Piece::localtime()->datetime;
        $time =~ s{T}{ };
        return {
            'Site id'   => $site->{'id'},
            'OK'        => $err ? '0' : '1',
            'Error'     => $err,
            'timestamp' => $time,
        };
    }
    
    sub is {
        my ($got, $expected, $err) = @_;
        if ($expected && $got && $got ne $expected) {
            return $err;
        }
    }
    
    sub mail_body {
        my ($self, $site, $log) = @_;
        my $parser = Text::PSTemplate->new;
        for my $key (keys %$site) {
            my $key2 = $key;
            $key2 =~ s{ }{_};
            $parser->set_var('site_'. $key2 => $site->{$key});
        }
        for my $key (keys %$log) {
            my $key2 = $key;
            $key2 =~ s{ }{_};
            $parser->set_var('log_'. $key2 => $log->{$key});
        }
        return $parser->parse_file($self->home->rel_file('mail_body.html'));
    }

1;

__END__

=head1 NAME MojoDownMonitor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
