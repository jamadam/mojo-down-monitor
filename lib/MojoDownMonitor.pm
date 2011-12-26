package MojoDownMonitor;
use Mojo::Base 'Mojolicious';
use Text::PSTemplate;
use File::Basename 'dirname';
use Mojo::UserAgent;
use Data::Dumper;
use Encode;
use Net::SMTP;
use Net::SMTP::SSL;
use MIME::Lite;
use Authen::SASL;
use Time::Piece;
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
        $r->route('/smtp_edit_api.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::SMTP', 'post');
        });
        $r->route('/site_edit_api.html')->via('post')->to(cb => sub {
            $tusu->bootstrap($_[0], 'MojoDownMonitor::Sites', 'post');
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
                    my @mailto = split(',', $site->{'Mail to'});
                    $self->sendmail(
                        \@mailto,
                        '[ALERT] mojo-down-monitor detected an error',
                        $self->mail_body($site, $new_log),
                        $smtp->server_info,
                    );
                }
                $log->store($new_log);
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
    
    sub html_to_plaintext {
        my $html = shift;
        if ($html =~ qr{<body.*?>(.+?)</body>}s) {
            $html = $1;
        }
        $html =~ s{<.+?>}{}g;
        $html =~ s{\t}{  }g;
        return $html;
    }
    
    sub sendmail {
        
        my ($self, $to, $subject, $body, $smtp_info) = @_;
        
        $subject = encode('MIME-Header', $subject);
        
        my $plain = html_to_plaintext($body);
        
        utf8::encode($body);
        utf8::encode($plain);
        
        my $mime_sub = MIME::Lite->new(
            Type     => 'multipart/alternative',
        );
        $mime_sub->attach(
            Data     => $plain,
            Type     => 'text/plain; charset=utf-8',
            Encoding => 'Base64',
        );
        $mime_sub->attach(
            Data     => $body,
            Type     => 'text/html; charset=utf-8',
            Encoding => 'Quoted-printable',
        );
        
        my $from = 'mojo-down-monitor@'. $smtp_info->value('host');
        
        $to = (ref $to) ? $to : [$to];
        for my $addr (@$to) {
            my $smtp;
            if ($smtp_info->value('ssl')) {
                $smtp = Net::SMTP::SSL->new($smtp_info->value('host'), Port => $smtp_info->value('port'));
            } else {
                $smtp = Net::SMTP->new($smtp_info->value('host'), Port => $smtp_info->value('port'));
            }
            if ($smtp_info->value('user')) {
                $smtp->auth($smtp_info->value('user'), $smtp_info->value('pass'));
            }
            
            $smtp->mail($from);
            $smtp->to($addr);
            my $mime = MIME::Lite->new(
                From    => encode('MIME-Header', $from),
                To      => encode('MIME-Header', $addr),
                Subject => $subject,
                Type     => 'multipart/mixed',
            );
            $mime->attach($mime_sub);
            $smtp->data();
            $smtp->datasend($mime->as_string);
            $smtp->datasend();
            $smtp->quit();
        }
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
