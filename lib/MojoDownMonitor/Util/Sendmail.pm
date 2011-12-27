package MojoDownMonitor::Util::Sendmail;
use strict;
use warnings;
use Text::PSTemplate;
use Net::SMTP;
use Net::SMTP::SSL;
use MIME::Lite;
use Authen::SASL;
use Encode;
use feature q/:5.10/;

    my $MEM_HOST = 1;
    my $MEM_PORT = 2;
    my $MEM_SSL  = 3;
    my $MEM_USER = 4;
    my $MEM_PASS = 5;
    
    sub new {
        my ($class, $host, $port, $ssl, $user, $pass) = @_;
        return bless {
            $MEM_HOST => $host,
            $MEM_PORT => $port,
            $MEM_SSL  => $ssl,
            $MEM_USER => $user,
            $MEM_PASS => $pass,
        }, $class;
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
        
        my ($self, $to, $subject, $body) = @_;
        
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
        
        my $from = 'mojo-down-monitor@'. $self->{$MEM_HOST};
        
        $to = (ref $to) ? $to : [$to];
        for my $addr (@$to) {
            my $smtp;
            if ($self->{$MEM_SSL}) {
                $smtp = Net::SMTP::SSL->new($self->{$MEM_HOST}, Port => $self->{$MEM_PORT});
            } else {
                $smtp = Net::SMTP->new($self->{$MEM_HOST}, Port => $self->{$MEM_PORT});
            }
            if ($self->{$MEM_USER}) {
                $smtp->auth($self->{$MEM_USER}, $self->{$MEM_PASS});
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

=head1 NAME MojoDownMonitor::SMTP

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<startup>

Not written yet.

=head1 SEE ALSO

=cut
