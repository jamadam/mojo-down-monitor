package Text::PSTemplate;
use strict;
use warnings;
use Fcntl qw(:flock);
use Text::PSTemplate::Exception;
use Text::PSTemplate::Block;
use Text::PSTemplate::File;
our $VERSION = '0.44';
use 5.005;
use Carp;
use Try::Tiny;
use Scalar::Util qw( blessed weaken );
no warnings 'recursion';
$Carp::Internal{ (__PACKAGE__) }++;

    our $current_file;
    our $current_file_parser;
    our $current_parser;
    our $block;
    our $chop;
    
    my $MEM_MOTHER                  = 1;
    my $MEM_DELIMITER_LEFT          = 2;
    my $MEM_DELIMITER_RIGHT         = 3;
    my $MEM_ENCODING                = 4;
    my $MEM_RECUR_LIMIT             = 5;
    my $MEM_FUNC                    = 6;
    my $MEM_VAR                     = 7;
    my $MEM_FILENAME_TRANS          = 8;
    my $MEM_NONEXIST                = 9;
    my $MEM_FUNC_NONEXIST           = 10;
    my $MEM_VAR_NONEXIST            = 11;
    my $MEM_PLUGED                  = 12;
    my $MEM_TAG_FILTERS             = 13;

    my %CORE_LIST = (
        Control => '',
        Env     => '',
        Extends => '',
        Util    => '',
        FS      => 'FS',
    );
    
    ### ---
    ### debug
    ### ---
    sub dump {
        use Data::Dumper;
        my $dump = Dumper($_[0]); $dump =~ s/\\x{([0-9a-z]+)}/chr(hex($1))/ge;
        return $dump;
    }
    
    ### ---
    ### constructor
    ### my ($class, $mother) = @_;
    ### ---
    sub new {
        
        if (scalar @_ == 1) {
            $_[1] ||= $current_parser;
        }
        
        my $self = bless {$MEM_MOTHER => $_[1]}, $_[0];
        
        if (! defined $self->{$MEM_MOTHER}) {
            $self->{$MEM_ENCODING}          = 'utf8';
            $self->{$MEM_RECUR_LIMIT}       = 10;
            $self->{$MEM_DELIMITER_LEFT}    = '<%';
            $self->{$MEM_DELIMITER_RIGHT}   = '%>';
            $self->{$MEM_FUNC_NONEXIST}     =
                            $Text::PSTemplate::Exception::PARTIAL_NONEXIST_DIE;
            $self->{$MEM_VAR_NONEXIST}      =
                            $Text::PSTemplate::Exception::PARTIAL_NONEXIST_DIE;
            $self->{$MEM_NONEXIST}          =
                            $Text::PSTemplate::Exception::TAG_ERROR_DIE;
        }
        
        if ($self->_count_recursion() > $self->get_param($MEM_RECUR_LIMIT)) {
            my $err = 'Deep Recursion over '. $self->get_param($MEM_RECUR_LIMIT);
            die Text::PSTemplate::Exception->new($err);
        }
        
        if (! $_[1]) {
            for my $key (keys %CORE_LIST) {
                $self->plug('Text::PSTemplate::Plugin::'. $key, $CORE_LIST{$key});
            }
        }
        
        $self;
    }
    
    ### ---
    ### Get mother in caller context
    ### ---
    sub get_current_parser {
        if (ref $_[0]) {
            $_[0]->{$MEM_MOTHER};
        } else {
            $current_parser;
        }
    }
    
    ### ---
    ### Get file context mother
    ### ---
    sub get_current_file_parser {
        return
            $current_file_parser
            || $current_parser->get_current_parser
            || $current_parser;
    }
    
    ### ---
    ### Get current file name
    ### ---
    sub get_current_filename {
        if ($current_file) {
            return $current_file->name;
        }
    }
    
    ### ---
    ### Set Exception
    ### ---
    sub set_exception {
        my ($self, $code_ref) = @_;
        $self->{$MEM_NONEXIST} = $code_ref;
    }
    
    ### ---
    ### Set Exception
    ### ---
    sub set_func_exception {
        $_[0]->{$MEM_FUNC_NONEXIST} = $_[1];
    }
    
    ### ---
    ### Set Exception
    ### ---
    sub set_var_exception {
        $_[0]->{$MEM_VAR_NONEXIST} = $_[1];
    }
    
    ### ---
    ### Set Exception
    ### ---
    sub set_recur_limit {
        $_[0]->{$MEM_RECUR_LIMIT} = $_[1];
    }
    
    ### ---
    ### Set Encoding
    ### ---
    sub set_encoding {
        $_[0]->{$MEM_ENCODING} = $_[1];
    }
    
    ### ---
    ### Get a param
    ### ---
    sub get_param {
        if (defined $_[1]) {
            if (defined $_[0]->{$_[1]}) {
                return $_[0]->{$_[1]};
            }
            if (defined $_[0]->{$MEM_MOTHER}) {
                return $_[0]->{$MEM_MOTHER}->get_param($_[1]);
            }
        }
    }
    
    ### ---
    ### Set chop option which reduce newline chars
    ### ---
    sub set_chop {
        $chop = $_[0];
    }
    
    ### ---
    ### Add tag option
    ### ---
    sub set_filter {
        my ($self, $key, $cb) = @_;
        my $array = $self->{$MEM_TAG_FILTERS}->{$key} ||= [];
        push(@$array, $cb);
        $self;
    }
    
    ### ---
    ### Set delimiter
    ### ---
    sub set_delimiter {
        my ($self, $left, $right) = @_;
        $self->{$MEM_DELIMITER_LEFT} = $left;
        $self->{$MEM_DELIMITER_RIGHT} = $right;
        $self;
    }
    
    my $delim_tbl = [$MEM_DELIMITER_LEFT, $MEM_DELIMITER_RIGHT];
    
    ### ---
    ### Get delimiter
    ### ---
    sub get_delimiter {
        if (defined $_[0]->{$delim_tbl->[$_[1]]}) {
            return $_[0]->{$delim_tbl->[$_[1]]};
        }
        if (defined $_[0]->{$MEM_MOTHER}) {
            return $_[0]->{$MEM_MOTHER}->get_delimiter($_[1]);
        }
    }
    
    ### ---
    ### Set template variables
    ### ---
    sub set_var {
        my ($self, %args) = (@_);
        while (my ($key, $value) = each %args) {
            $self->{$MEM_VAR}->{$key} = $value;
        }
        $self;
    }
    
    ### ---
    ### Get a template variable
    ### my ($self, $name, $error_callback) = @_;
    ### ---
    sub var {
        $_[2] ||= $_[0]->{$MEM_VAR_NONEXIST};
        
        if (defined $_[1]) {
            if (defined $_[0]->{$MEM_VAR}->{$_[1]}) {
                return $_[0]->{$MEM_VAR}->{$_[1]};
            }
            if (defined $_[0]->{$MEM_MOTHER}) {
                return $_[0]->{$MEM_MOTHER}->var($_[1], $_[2]);
            }
            if (! exists $_[0]->{$MEM_VAR}->{$_[1]}) {
                return $_[2]->($_[0], '$'. $_[1], 'variable');
            }
            return;
        }
        $_[0]->{$MEM_VAR};
    }
    
    ### ---
    ### Set template function
    ### ---
    sub set_func {
        my ($self, %args) = (@_);
        while ((my $key, my $value) = each %args) {
            $self->{$MEM_FUNC}->{$key} = $value;
        }
        $self;
    }
    
    ### ---
    ### Get template function
    ### my ($self, $name, $error_callback) = @_;
    ### ---
    sub func {
        $_[2] ||= $_[0]->{$MEM_FUNC_NONEXIST};
        
        if (defined $_[1]) {
            if (defined $_[0]->{$MEM_FUNC}->{$_[1]}) {
                return $_[0]->{$MEM_FUNC}->{$_[1]};
            }
            if (defined $_[0]->{$MEM_MOTHER}) {
                return $_[0]->{$MEM_MOTHER}->func($_[1], $_[2]);
            }
            if (! exists $_[0]->{$MEM_FUNC}->{$_[1]}) {
                return $_[2]->($_[0], '&'. $_[1], 'function');
            }
        }
    }
    
    ### ---
    ### Parse template
    ### ---
    sub parse_file {
        my ($self, $file) = @_;
        
        local $current_file = $current_file;
        
        my $str;
        if (blessed($file) && $file->isa('Text::PSTemplate::File')) {
            $current_file = $file;
            $str = $file->content;
        } else {
            my $translate_ref = $self->get_param($MEM_FILENAME_TRANS);
            if (ref $translate_ref eq 'CODE') {
                $file = $translate_ref->($file);
            }
            $current_file = $self->get_file($file, undef);
            $str = $current_file->content;
        }
        local $current_file_parser = $self;
        
        my $res = try {
            $self->parse($str);
        } catch {
            $_->set_file($current_file);
            $_->finalize;
            die $_;
        };
        $res;
    }
    
    ### ---
    ### Parse template
    ### ---
    sub parse_str {
        my ($self, $str) = @_;
        if (blessed($str) && $str->isa('Text::PSTemplate::File')) {
            local $current_file_parser = $self;
            $current_file = $_[1];
            $str = $_[1]->content;
        }
        $self->parse($str);
    }
    
    sub get_block {
        my ($index, $args) = @_;
        if (ref $block && defined $index) {
            return $block->content($index, $args);
        }
        $block;
    }

    ### ---
    ### Get block and parse
    ### ---
    sub parse_block {
        my ($self, $index, $option) = @_;
        if (ref $block && defined $index) {
            my $res = try {
                $self->parse($block->content($index, $option) || '');
            } catch {
                my $exception = Text::PSTemplate::Exception->new($_);
                my $pos = $exception->position - 1;
                $pos += length($block->get_left_chomp($index));
                for (my $i = 0; $i < $index; $i++) {
                    $pos += length($block->content($i));
                    $pos += length($block->delimiter($i));
                }
                $exception->set_position($pos);
                die $exception;
            };
            return $res;
        }
        '';
    }
    
    ### ---
    ### Parse str
    ### ---
    sub parse {
        my ($self, $str) = @_;
        my $str_org = $str;
        
        if (! defined $str) {
            die Text::PSTemplate::Exception->new('No template string found');
        }
        my $out = '';
        my $eval_pos = 0;
        while ($str) {
            my $delim_l = $self->get_param($MEM_DELIMITER_LEFT);
            my $delim_r = $self->get_param($MEM_DELIMITER_RIGHT);
            my ($left, $all, $escape, $opt_l, $space_l, $prefix, $tag, $space_r, $right) =
            split(m{((\\*)$delim_l([^\s]*)(\s+)([\&\$]*)(.+?)(\s*)$delim_r)}s, $str, 2);
            
            if (! defined $tag) {
                return $out. $str;
            }
            $eval_pos += length($left) + length($all);
            $out .= $left;
            
            my $len = length($escape);
            $out .= ('\\' x int($len / 2));
            if ($len % 2 == 1) {
                $out .= $delim_l. $opt_l. $space_l. $prefix. $tag. $space_r. $delim_r;
            } else {
                local $block;
                local $current_parser = $self;
                local $chop;
                
                if ($tag =~ s{<<([a-zA-Z0-9_,]+)}{}) {
                    $block = 
                    Text::PSTemplate::Block->new($1, \$right, $delim_l, $delim_r);
                }
                
                my $interp = ($prefix || '&'). $tag;
                $interp =~ s{(\\*)([\$\&])([\w:]+)}{
                    $self->_interpolate_partial($1, $2, $3)
                }ge;
                
                my $result = try {
                    Text::PSTemplate::_EvalStage::_do($self, $interp);
                } catch {
                    my $exception = $_;
                    my $org = $opt_l. $space_l. $prefix. $tag. $space_r;
                    my $position = $exception->position || 0;
                    my $ret = try {
                        $self->get_param($MEM_NONEXIST)->($self, $org, $exception);
                    } catch {
                        my $exception = Text::PSTemplate::Exception->new($_);
                        $exception->set_position($position + $eval_pos);
                        die $exception;
                    };
                    return $ret;
                };
                
                if ($chop) {
                    $right =~ s{^(\r\n|\r|\n)}{};
                    $eval_pos += length($1);
                }
                
                # filter
                if (my $f = $self->get_param($MEM_TAG_FILTERS)) {
                    if (my $cbs = $f->{$opt_l}) {
                        for my $cb (@$cbs) {
                            $result = $cb->($result);
                        }
                    }
                }
                
                $out .= $result;
                
                if ($block) {
                    $eval_pos += $block->get_followers_offset;
                }
            }
            $str = $right;
        }
        $out;
    }
    
    ### ---
    ### Get template from a file
    ### ($self, $escape, $prefix, $ident)= @_;
    ### ---
    sub _interpolate_partial {
        my $out;
        if ($_[1]) {
            my $len = length($_[1]);
            $out = '\\' x int($len / 2);
            if ($len % 2 == 1) {
                return $out. $_[2]. $_[3];
            }
        }
        if ($_[2] eq '$') {
            $out .= qq{\$self->var('$_[3]')};
        } elsif ($_[2] eq '&') {
            $out .= qq!\$self->func('$_[3]')->!;
        } else {
            $out .= $_[2] . $_[3];
        }
        $out;
    }
    
    ### ---
    ### Get template from a file
    ### ---
    sub get_file {
        my ($self, $name, $translate_ref) = (@_);
        
        if (scalar @_ == 2) {
            $translate_ref = $self->get_param($MEM_FILENAME_TRANS);
        }
        if (ref $translate_ref eq 'CODE') {
            $name = $translate_ref->($name);
        }
        my $file = try {
            Text::PSTemplate::File->new($name, $self->get_param($MEM_ENCODING));
        } catch {
            die Text::PSTemplate::Exception->new($_);
        };
        $file;
    }
    
    ### ---
    ### Set file name transform callback
    ### ---
    sub set_filename_trans_coderef {
        my ($self, $coderef) = @_;
        $self->{$MEM_FILENAME_TRANS} = $coderef;
    }
    
    ### ---
    ### Translate file name
    ### ---
    sub file_name_trans {
        my ($self, $org) = @_;
        $self->{$MEM_FILENAME_TRANS}->($org);
    }
    
    ### ---
    ### couunt recursion
    ### ---
    sub _count_recursion {
        if (defined $_[0]->{$MEM_MOTHER}) {
            return $_[0]->{$MEM_MOTHER}->_count_recursion() + 1;
        }
        0;
    }
    
    sub plug {
        my ($self, @plugins) = (@_);
        $self->{$MEM_PLUGED} ||= {};
        my $last_plugin;
        while (scalar @plugins) {
            my $plugin = shift @plugins;
            my $as = shift @plugins;
            my $p_instance = $self->{$MEM_PLUGED}->{$plugin};
            if (! blessed($p_instance)) {
                no strict 'refs';
                if (! %{"$plugin\::"}) {
                    my $file = $plugin;
                    $file =~ s{::}{/}g;
                    eval {require "$file.pm"}; ## no critic
                    if ($@) {
                        croak $@;
                    }
                }
                $p_instance = $plugin->new($self, $as);
                $self->{$MEM_PLUGED}->{$plugin} = $p_instance;
                weaken $self->{$MEM_PLUGED}->{$plugin};
            }
            $last_plugin = $self->{$MEM_PLUGED}->{$plugin};
        }
        $last_plugin;
    }
    
    sub get_plugin {
        my ($self, $name) = @_;
        if (exists $self->{$MEM_PLUGED}->{$name}) {
            return $self->{$MEM_PLUGED}->{$name};
        }
        croak "Plugin $name not loaded";
    }

    sub get_func_list {
        my $self = shift;
        my $out = <<EOF;
=============================================================
List of all available template functions
=============================================================
EOF

        for my $plug (keys %{$self->{$MEM_PLUGED}}) {

            $out .= "\n-- $plug namespace";
            $out .= "\n";
            $out .= "\n";

            my $as = $self->{$MEM_PLUGED}->{$plug}->{1};
            $as = defined $as ? $as : $plug;
            
            for my $func (@{$plug->_get_tpl_exports}) {
                $out .= '<% '. join('::', grep {$_} $as, $func->[2]) . '() %>';
                $out .= "\n";
            }
            $out .= "\n";
        }
        return $out;
    }
    
package Text::PSTemplate::_EvalStage;
use strict;
use warnings;
use Carp qw(shortmess);
$Carp::Internal{ (__PACKAGE__) }++;
    
    {
        my $self;
        sub _do {
            $self = $_[0];
            my $res = eval $_[1]; ## no critic
            if ($@) {
                die Text::PSTemplate::Exception->new($@);
            }
            if (! defined $res) {
                die Text::PSTemplate::Exception->new('Tag resulted undefined');
            }
            return $res;
        }
        sub AUTOLOAD {
            our $AUTOLOAD;
            my $name = ($AUTOLOAD =~ qr/([^:]+)$/)[0];
            if ($self->func($name)) {
                return $self->func($name)->(@_);
            }
            die "Undefined subroutine $name called\n";
        }
    }

1;

__END__

=head1 NAME

Text::PSTemplate - Multi purpose template engine

=head1 SYNOPSIS

    use Text::PSTemplate;
    
    $template = Text::PSTemplate->new;
    
    $template->set_var(key1 => $value1, key2 => $value2);
    $template->set_func(key1 => \&func1, key2 => \&func2);
    
    $str = $template->parse($str);
    $str = $template->parse_str($str);
    $str = $template->parse_str($file_obj);
    $str = $template->parse_file($filename);
    $str = $template->parse_file($file_obj);
    $str = $template->parse_block($index);

=head1 DESCRIPTION

Text::PSTemplate is a multi purpose template engine.
This module allows you to include variables and function calls into your
templates.

=head2 Essential syntax

The essential syntax for writing template is as follows.

=over

=item Special tagging

    <% ... %>

=item Perl style variable and function calls

    <% $some_var %>
    <% some_func(...) %>

=item Line breaks in tags

    <%
        product_list(
            limit       => 20,
            category    => 'books',
        )
    %>

=item Block syntax

    <% your_func()<<EOF,EOF2 %>
        inline data
    <% EOF %>
        inline data2
    <% EOF2 %>

=item escaping

tag delimiter can be escaped by backslashes so that the delimiter
characters themselves appear to the output. If you want to parse the statement
after backslash, you can double escape.

    \<% this appears literally %>   ### literally
    \\<% $var %>                    ### A backlash and parsed value
    \\\<% this appears literally %> ### A backslash and literal
    \\\\<% $var %>                  ### Two backlashes and parsed value
    ....

Character $ and & is interpolated in any part of statements even in single
quotes. So you must escape them with backslashes when it's needed. 

    <% some_func(price => '\$10.25') %>

=back

=head2 Plugin

This template engine provides a plugin mechanism. A plugin can define functions
for templates.

A plugin must inherits Text::PSTemplate::PluginBase. Once inherit it, the
plugin class get capable of TplExport attribute.
    
    package MyPlug;
    use base qw(Text::PSTemplate::PluginBase);

    sub say_hello_to : TplExport {
        my ($self, $name) = (@_);
        return "Hello $name";
    }

You can activate it as follows.

    $template->plug('MyPlug');
    
    # or with namespace
    
    $template->plug('MyPlug','My::Name::Space');

The function is available as follows.

    <% say_hello_to('Nick') %>

=head2 Core plugins

Text::PSTemplate automatically activate some core plugins.

=over

=item Core plugins

    Control
    Env
    Extends
    Util
    FS

=back

Text::PSTemplate::Plugin::Control plugin

    <% if_equals($some_var, 'a')<<THEN,ELSE %>
        then
    <% THEN %>
        else
    <% ELSE %>
    
    <% if($some_var)<<THEN,ELSE %>
        true
    <% THEN %>
        not true
    <% ELSE %>
    
    <% if_in_array($some_var, ['a','b','c'])<<THEN,ELSE %>
        found
    <% THEN %>
        not found
    <% ELSE %>
    
    <% switch($some_var, ['a', 'b'])<<CASE1,CASE2,DEFAULT %>
        match a
    <% CASE1 %>
        match b
    <% CASE2 %>
        default
    <% DEFAULT %>
    
    <% tpl_switch($some_var, {
        a => 'path/to/tpl_a.txt',
        b => 'path/to/tpl_b.txt',
    }, 'path/to/tpl_default.txt') %>
    
    <% substr($some_var, 0, 2, '...') %>
    
    <% each($array_ref, 'name')<<TPL %>
        This is <%$name%>.
    <% TPL %>

    <% each($array_ref, 'index' => 'name')<<TPL %>
        No.<%$index%> is <%$name%>.
    <% TPL %>

    <% each($hash_ref, 'name')<<TPL %>
        This is <%$name%>.
    <% TPL %>

    <% each($has_href, 'key' => 'name')<<TPL %>
        Key '<%$key%>' contains <%$name%>.
    <% TPL %>
    
    <% include('path/to/file.txt', {some_var => 'aaa'}) %>
    
    <% default($var, $default) %>

Text::PSTemplate::Plugin::Extends plugin

    base.html
    
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    <head>
        <link rel="stylesheet" href="style.css" />
        <title><% placeholder('title')<<DEFAULT %>My amazing site<% DEFAULT %></title>
    </head>
    
    <body>
        <div id="sidebar">
            <% placeholder('sidebar')<<DEFAULT %>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/blog/">Blog</a></li>
            </ul>
            <% DEFAULT %>
        </div>
    
        <div id="content">
            <% placeholder('content')<<DEFAULT %><% DEFAULT %>
        </div>
    </body>
    </html>
    
    child.html
    
    <% extends('base.html')<<EXTENDS %>
        <% block('title')<<BLOCK %>My amazing blog<% BLOCK %>
        <% block('content')<<BLOCK %><% each($blog_entries, 'entry')<<ENTRIES %>
            <h2><% $entry->{title} %></h2>
            <p><% $entry->{body} %></p>
        <% ENTRIES %><% BLOCK %>
    <% EXTENDS %>

Text::PSTemplate::Plugin::Util plugin

    <% commify($num) %>
    
    <% substr($var, $start, $length, $alterative) %>
    <% substr($some_var, 0, 2, '...') %>

    <% counter(start=10, skip=5) %>
    <% counter() %>
    <% counter() %>
    <% counter(start=10, direction=down) %>
    <% counter() %>

=head1 METHODS

=head2 Text::PSTemplate->new($mother)

Constructor. This method can take an argument $mother which should be a
Text::PSTemplate instance. Most member attributes will be inherited from their
mother at referring phase. So you don't have to set all settings again and
again. Just tell a mother to the constructor. If this constructor is
called from a template function, meaning the instantiation is recursive, this
constructor auto detects the nearest mother to be set to new instance's mother.

If you want really new instance, give an undef to constructor explicitly.

    Text::PSTemplate->new(undef)

=head2 Text::PSTemplate::get_current_parser()

This can be called from template functions. If current context is recursed
instance, this returns mother instance.
    
    $parser = Text::PSTemplate::get_current_parser;

=head2 Text::PSTemplate::get_current_file_parser()

This can be called from template functions. This returns file-contextual mother
template instance.

    $parser = Text::PSTemplate::get_current_file_parser;

=head2 Text::PSTemplate::get_current_filename()

This can be called from template functions. If current context is originated
from a file, this returns the file name.

=head2 $instance->set_filter($key, $filter_code_ref)

Add a filter for given key in code ref.

    my $tpl = Text::PSTemplate->new;
    $tpl->set_filter('[escape]', \&escape);
    
    # in templates..
    
    <%[escape] $val %>

=head2 Text::PSTemplate::set_chop($mode)

This method set the behavior of the parser how they should treat follow up line
breaks. If argument $mode is 1, line breaks will not to be output. 0 is default.

=head2 Text::PSTemplate::get_block($index, $options)

This can be called from template functions. This Returns block data specified
in templates.
    
In a template
    
    <% your_func()<<EOF1,EOF2 %>
    foo
    <% EOF1 %>
    bar
    <% EOF2 %>
    
Function definition
    
    sub your_func {
        my $block1 = Text::PSTemplate::get_block(0) # foo with newline chara
        my $block2 = Text::PSTemplate::get_block(1) # bar with newline chara
        my $block1 = Text::PSTemplate::get_block(0, {chop_left => 1}) # foo
        my $block2 = Text::PSTemplate::get_block(1, {chop_right => 1}) # bar
    }

=head2 $instance->set_encoding($encode or $encode_array_ref)

This setting will be thrown at file open method. Default is 'utf8'.

    $instance->set_encoding('cp932')

You can set a array reference for guessing encoding. The value will be thrown at
Encode::guess_encoding.

    $instance->set_encoding(['euc-jp', 'shiftjis', '7bit-jis'])

=head2 $instance->set_exception($code_ref)

This is a callback setter. If any errors occurred at parsing phase, the $code_ref
will be called. Your callback subroutine can get following arguments.

    $template->set_exception(sub {
        my ($self, $line, $err) = (@_);
    });

With these arguments, you can log the error, do nothing and return '', or
reconstruct the tag and return it as if the tag was escaped. See also
Text::PSTemplate::Exception Class for example.

=head2 $instance->set_var_exception($code_ref)

=head2 $instance->set_func_exception($code_ref)

=head2 $instance->set_recur_limit($number)

This class instance can recursively have a mother instance as an attribute.
This setting limits the recursion at given number. The default is 10.

    $template->set_recur_limit(10);

=head2 $instance->get_param($name)

=head2 $instance->set_delimiter($left, $right)

Set delimiters.

    $instance->set_delimiter('<!-- ', ' -->')

=head2 $instance->get_delimiter(0 or 1)

Get delimiters

    $instance->get_delimiter(0) # left delimiter
    $instance->get_delimiter(1) # right delimiter

=head2 $instance->set_var(%datasets)

This method Sets variables which can be referred from templates.

    $instance->set_var(a => 'b', c => 'd')

This can take null string too. You can't set undef for value.

=head2 $instance->var($name)

Get template variables

    $instance->var('a')

=head2 $instance->set_func(some_name => $code_ref)

Set template functions

    $a = sub {
        return 'Hello '. $_[0];
    };
    $instance->set_func(say_hello_to => $a)
    
    Inside template...
    <% say_hello_to('Fujitsu san') %>

=head2 $instance->func(name)

Get template functions. This method is aimed at internal use.

=head2 $instance->parse($str)

This method parses templates given in string.

    $tpl->parse('...')

=head2 $instance->parse_str($str)

=head2 $instance->parse_str($file_obj)

This method parses templates given in string or Text::PSTemplate::File
instance.

    $tpl->parse_str('...')
    $tpl->parse_str($obj)

=head2 $instance->parse_file($file_path)

=head2 $instance->parse_file($file_obj)

This method parses templates given in filename or Text::PSTemplate::File
instance.

    $tpl->parse_file($file_path)
    $tpl->parse_file($obj)

=head2 $instance->parse_block($index, $args)

    $tpl->parse_block(0, {chop_left => 1})

=head2 $instance->get_file($name, $trans_ref)

This returns a Text::PSTemplate::File instance of given file name which contains
file name and file content together. If $trans_ref is set or $instance already
has a translation code in its attribute, the file name is translated
with the code. You can set undef for $trans_ref then both options are
bypassed.

=head2 $instance->set_filename_trans_coderef($code_ref)

This method sets a callback subroutine which defines a translating rule for file
name.

This example sets the base template directory.

    $tpl->set_filename_trans_coderef(sub {
        my $name = shift;
        return '/path/to/template/base/directory'. $name;
    });

This example allows common extension to be omitted.

    $trans = sub {
        my $name = shift;
        if ($name !~ /\./) {
            return $name . '.html'
        }
        return $name;
    }
    $tpl->set_filename_trans_coderef($trans)

This also let you set a default template in case the template not found.

=head2 file_name_trans($name)

Translate file name with prepared code reference.

=head2 Text::PSTemplate::dump($object)

Debug

=head2 $instance->plug($package, $namespace)

This method activates a plugin into your template instance.

    $instance->plug('Path::To::SomePlugin');

The functions will available as follows.

    <% Path::To::SomePlugin::some_function(...) %>

You can load plugins into specific namespaces.

    $instance->plug('Path::To::SomePlugin', 'MyNamespace');

This functions will available as follows

    <% MyNamespace::some_function(...) %>

You can merge plugins into single namespace or even the root namespace which
used by core plugins.

    $instance->plug('Plugin1', 'MyNamespace');
    $instance->plug('Plugin2', 'MyNamespace');
    $instance->plug('Plugin1', '');

=head2 $instance->get_plugin($name)

This method returns the plugin instance for given name.

=head2 $instance->get_as($plug_id)

This method returns the namespace for the plugin. Since it's just to be called
from PluginBase abstract class, you don't worry about it.

=head2 get_func_list

Output list of available template function in text format.

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
