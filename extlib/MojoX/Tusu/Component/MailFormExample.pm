package MojoX::Tusu::Component::MailFormExample;
use strict;
use warnings;
use utf8;
use base qw(MojoX::Tusu::Component::MailFormBase);
use Fcntl qw(:flock);
	
    sub init {
        my ($self, $app) = @_;
		$self->tmp_dir('');
		$self->mailto([]);
		$self->logfile($app->home->rel_file(__PACKAGE__));
		$self->smtp_from('noreply'); ## you can fill @host if needed
		$self->smtp_server('localhost');
		$self->form_elements([qw{name mail pref addr company tel1 tel2 tel3 fax1 fax2 fax3 etc}]);
		$self->auto_respond_to('mail');
		$self->upload({
			allowed_extention => ['doc','xls','txt','pdf'],
			max_filesize => 100000,
		});
    }

    sub validate_form {
        
        my ($self) = @_;
        my $c = $self->controller;
        my $formdata = $c->req->body_params;
        my $user_err = $self->user_err;
        
        for my $key ('tel1','tel2','tel3') {
            if (! $formdata->param($key)) {
                $user_err->stack('お電話番号は必須項目です');
                last;
            }
        }
        
        if (my $mail = $formdata->param('mail')) {
            $mail =~ tr/Ａ-Ｚａ-ｚ０-９/A-Za-z0-9/;
            if ($mail !~ /^[^@]+@[^.]+\..+/){
                $user_err->stack('メールアドレスが正しくありません');
            }
        }
        if ($formdata->param('etc') && length($formdata->param('etc')) > 10000) {
            $user_err->stack('お問い合わせ内容がサイズの上限を超えました');
        }
    }
    
    sub mail_attr {
        
        my ($self) = @_;
        my $c = $self->controller;
        
        my $tpl = Text::PSTemplate->new($self->get_engine);
        my $subject = 'Someone send inquiry';
        
        my $body = $tpl->parse(<<'EOF');
<html>
<head>
	<style type="text/css">
		* {font-size:1em; font-weight:normal;}
		h2 {border-left:5px solid #ccc; padding:3px 10px;}
		th {text-align:right; padding:5px; background-color:#dde}
		td {padding:5px;}
		pre{font-family:inhefit}
	</style>
</head>
<body>
<p>
    お問い合わせがありました
</p>

<hr />

<h2>
    お問い合わせ内容
</h2>

<table>
	<tr>
		<th>お名前</th>
		<td><%= post_param('name') %></td>
	</tr>
	<tr>
		<th>メール</th>
		<td><%= post_param('mail') %></td>
	</tr>
	<tr>
		<th>住所</th>
		<td><%= post_param('pref') %><%= post_param('addr') %></td>
	</tr>
	<tr>
		<th>会社名</th>
		<td><%= post_param('company') %></td>
	</tr>
	<tr>
		<th>お電話</th>
		<td><%= post_param('tel1') %>-<%= post_param('tel2') %>-<%= post_param('tel3') %></td>
	</tr>
	<tr>
		<th>FAX</th>
		<td><%= post_param('fax1') %>-<%= post_param('fax2') %>-<%= post_param('fax3') %></td>
	</tr>
	<tr>
		<th>備考</th>
		<td><pre><%= post_param('etc') %></pre></td>
	</tr>
</table>
EOF
        
        return $subject, $body;
    }
    
    sub mail_attr_respond {
        
        my ($self) = @_;
        
        my $c = $self->controller;
        my $tpl = Text::PSTemplate->new($self->get_engine);
        my $subject = 'Thank you';
        
        my $body = $tpl->parse(<<'EOF');
<html>
<head>
	<style type="text/css">
		* {font-size:1em; font-weight:normal;}
		h2 {border-left:5px solid #ccc; padding:3px 10px;}
		th {text-align:right; padding:5px; background-color:#dde}
		td {padding:5px;}
		pre{font-family:inhefit}
	</style>
</head>
<body>
<p>
    <%= $rep %>様
</p>

<p>
    お問い合わせありがとうございました。
</p>

<h2>
    お問い合わせ内容
</h2>

<hr />

<table>
	<tr>
		<th>お名前</th>
		<td><%= post_param('name') %></td>
	</tr>
	<tr>
		<th>メール</th>
		<td><%= post_param('mail') %></td>
	</tr>
	<tr>
		<th>住所</th>
		<td><%= post_param('pref') %><%= post_param('addr') %></td>
	</tr>
	<tr>
		<th>会社名</th>
		<td><%= post_param('company') %></td>
	</tr>
	<tr>
		<th>お電話</th>
		<td><%= post_param('tel1') %>-<%= post_param('tel2') %>-<%= post_param('tel3') %></td>
	</tr>
	<tr>
		<th>FAX</th>
		<td><%= post_param('fax1') %>-<%= post_param('fax2') %>-<%= post_param('fax3') %></td>
	</tr>
	<tr>
		<th>備考</th>
		<td><pre><%= post_param('etc') %></pre></td>
	</tr>
</table>

<hr />

<p>
    上記の内容で間違いがないか必ずご確認ください。
    万一、お申込みに覚えがない場合や、記載内容に間違いがある場合は、
    ご面倒ですが下記までご連絡ください。
</p>
<pre>
◆◇………………………………………………
test@example.com
………………………………………………◇◆
</pre>
</body>
</html>
EOF

        return $subject, $body;
    }

1;

__END__

=head1 NAME

MojoX::Tusu::Component::MailFormExample

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 TEMPLATE FUNCTIONS

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
