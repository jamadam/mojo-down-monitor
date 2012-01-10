package MojoDownMonitor;
use strict;
use warnings;
use Mojo::Base 'Mojolicious';
use Text::PSTemplate;
use File::Basename 'dirname';
use Mojo::UserAgent;
use Data::Dumper;
use Time::Piece;
use SQL::OOP::Dataset;
use MojoDownMonitor::Util::Sendmail;
use Time::HiRes qw ( time );
our $VERSION = '0.07';
    
    __PACKAGE__->attr('mdm_sites');
    __PACKAGE__->attr('mdm_log');
    __PACKAGE__->attr('mdm_smtp');
    
    my $json_parser = Mojo::JSON->new;
    
    sub startup {
        my $self = shift;
        $self->app->secret(time());
        $self->home->parse(File::Spec->catdir(dirname(__FILE__), 'MojoDownMonitor'));
        my $tusu = $self->plugin(tusu => {
            components => {
                'MojoDownMonitor::SitesBase'=> 'SitesBase',
                'MojoDownMonitor::Sites'    => 'Sites',
                'MojoDownMonitor::Log'      => 'Log',
                'MojoDownMonitor::SMTP'     => 'SMTP',
            },
            document_root => $self->home->rel_dir('public_html'),
            error_document => {
                404 => '/error_document/404.html',
                500 => '/error_document/500.html',
            },
        });
        
        $self->mdm_log($tusu->get_component('MojoDownMonitor::Log'));
        $self->mdm_sites($tusu->get_component('MojoDownMonitor::Sites'));
        $self->mdm_smtp($tusu->get_component('MojoDownMonitor::SMTP'));
        
        # special route
        my $r = $self->routes;
        $r->route('/index.html')->via('post')->to(cb => sub {
            my $c = $_[0];
            $tusu->bootstrap($c, 'MojoDownMonitor::Sites', 'post');
            $c->app->_set_cron($json_parser->decode($c->param('where'))->{id});
        });
        $r->route('/site_new.html')->via('post')->to(cb => sub {
            my $c = $_[0];
            $tusu->bootstrap($c, 'MojoDownMonitor::Sites', 'post');
            $c->app->_set_cron($c->app->mdm_sites->last_insert_rowid);
        });
        $r->route('/site_test.html')->via('post')->to(cb => sub {
            my $c = $_[0];
            my %data = $tusu->bootstrap($c, 'MojoDownMonitor::Sites', 'generate_dataset_hash_seed');
            eval {
                my $res = $c->app->check(\%data);
                $c->render_json({result => $res});
            };
            if ($@) {
                $c->render_json({error => $@});
            }
        });
        $r->route('/site_edit.html')->via('post')->to(cb => sub {
            my $c = $_[0];
            $tusu->bootstrap($c, 'MojoDownMonitor::Sites', 'post');
            $c->app->_set_cron($json_parser->decode($c->param('where'))->{id});
        });
        $r->route('/smtp_edit.html')->via('post')->to(cb => sub {
            my $c = $_[0];
            $tusu->bootstrap($c, 'MojoDownMonitor::SMTP', 'post');
        });
        
        $self->_set_cron();
    }
    
    my %loop_ids;
    
    sub _set_cron {
        my ($self, $site_id) = @_;
        my $sth = $self->mdm_sites->dump({id => $site_id});
        
        while (my $site = $sth->fetchrow_hashref) {
            if ($loop_ids{$site->{'id'}}) {
                Mojo::IOLoop->drop($loop_ids{$site->{'id'}});
                delete $loop_ids{$site->{'id'}};
            }
            my $loop_id = Mojo::IOLoop->recurring($site->{'Interval'} => sub {
                my $new_log = $self->check($site);
                my $last_log =
                    $self->mdm_log
                    ->dump({'Site id' => $site->{'id'}}, ['OK'], 1, [['id', 1]])
                    ->fetchrow_hashref;
                
                $self->mdm_log->create(SQL::OOP::Dataset->new($new_log));
                $self->mdm_log->vacuum($site->{'Max log'}, $site->{'id'});
                
                if ($last_log && ! $new_log->{OK} || ! $last_log->{OK}) {
                    
                    my $smtp_info = $self->mdm_smtp->server_info;
                    my $sendmail = MojoDownMonitor::Util::Sendmail->new(
                        $smtp_info->value('host'),
                        $smtp_info->value('port'),
                        $smtp_info->value('ssl'),
                        $smtp_info->value('user'),
                        $smtp_info->value('password'),
                    );
                    
                    my @change_msg_tbl = ();
                    $change_msg_tbl[1][0] = 'An error detected';
                    $change_msg_tbl[0][1] = 'An error resolved';
                    $change_msg_tbl[0][0] = 'An error continuously detected';
                    my $title = $change_msg_tbl[$last_log->{OK}][$new_log->{OK}];
                    
                    my @mailto = split(',', $site->{'Mail to'});
                    $sendmail->sendmail(
                        \@mailto,
                        "[ALERT] $title",
                        $self->_mail_body($site, $new_log, $title),
                    );
                }
            });
            $loop_ids{$site->{'id'}} = $loop_id;
        }
    }
    
    sub check {
        my ($self, $site) = @_;
        my $ua = Mojo::UserAgent->new->name($site->{'User Agent'} || "mojo-down-monitor/$VERSION (+https://github.com/jamadam/mojo-down-monitor)");
        $ua->connect_timeout($site->{'Connect timeout'} || 10);
        
        my $time_s = time;
        my $tx = $ua->get($site->{URI});
        my $time_e = time;
        
        my $res_time = (int($time_e * 1000000) - int($time_s * 1000000)) / 1000;
        
        my $res = $tx->res;
        my $code = $res->code;
        my $type = $res->headers->content_type || '';
        my $body = $res->body || '';
        my $body_size = $res->body_size;
        my $err;
        if ($code) {
            $err ||= _is($code, $site->{'Status must be'}, qq{Got wrong status '$code'});
            $err ||= _is($type, $site->{'MIME type must be'}, qq{Got wrong MIME type '$type'});
            $err ||= _is($body, $site->{'Content must match'}, qq{Content doesn't match expectation});
            $err ||= _is($body_size, $site->{'Body size must be'}, qq{Got wrong body size $body_size bytes});
        } else {
            $err ||= $tx->error || 'Unknown error';
            utf8::decode($err);
        }
        
        my $time = Time::Piece::localtime()->datetime;
        $time =~ s{T}{ };
        return {
            'Site id'   => $site->{'id'},
            'OK'        => $err ? '0' : '1',
            'Error'     => $err || undef,
            'timestamp' => $time,
            'Response time' => $res_time,
        };
    }
    
    sub _is {
        my ($got, $expected, $err) = @_;
        if ($expected && $got && $got ne $expected) {
            return $err;
        }
    }
    
    sub _mail_body {
        my ($self, $site, $log, $title) = @_;
        my $parser = Text::PSTemplate->new;
        $parser->set_var('title' => $title);
        for my $key (keys %$site) {
            my $key2 = $key;
            $key2 =~ s{ }{_};
            $parser->set_var('site_'. $key2 => $site->{$key} || '');
        }
        for my $key (keys %$log) {
            my $key2 = $key;
            $key2 =~ s{ }{_};
            $parser->set_var('log_'. $key2 => $log->{$key} || '');
        }
        return $parser->parse_file($self->home->rel_file('mail_body.html'));
    }

1;

__END__

=head1 NAME MojoDownMonitor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 $instance->startup

=head2 $instance->check

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
