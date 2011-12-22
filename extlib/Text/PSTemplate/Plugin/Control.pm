package Text::PSTemplate::Plugin::Control;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
    
    ### ---
    ### Parse inline template if the variable is in array
    ### ---
    sub if_in_array : TplExport {
        
        my ($self, $target, $array_ref, $then, $else) = @_;
        
        my $tpl = Text::PSTemplate->get_current_parser;
        
        if (defined $target && defined $array_ref && grep {$_ eq $target} @$array_ref) {
            if ($then) {
                return $then;
            } else {
                return $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
            }
        } else {
            if ($else) {
                return $else;
            } else {
                return $tpl->parse_block(1, {chop_left => 1, chop_right => 1});
            }
        }
        return;
    }
    
    ### ---
    ### Parse inline template if the variable equals to value
    ### ---
    sub if : TplExport {
        
        my ($self, $condition, $then, $else) = @_;
        
        my $tpl = Text::PSTemplate->get_current_parser;
        
        if ($condition) {
            if ($then) {
                return $then;
            } else {
                return $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
            }
        } else {
            if ($else) {
                return $else;
            } else {
                return $tpl->parse_block(1, {chop_left => 1, chop_right => 1});
            }
        }
        return;
    }
    
    ### ---
    ### Parse inline template if the variable equals to value
    ### ---
    sub if_equals : TplExport {
        
        my ($self, $target, $value, $then, $else) = @_;
        
        my $tpl = Text::PSTemplate->new;
        
        if (defined $target && defined $value && $target eq $value) {
            if ($then) {
                return $then;
            } else {
                return $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
            }
        } else {
            if ($else) {
                return $else;
            } else {
                return $tpl->parse_block(1, {chop_left => 1, chop_right => 1});
            }
        }
        return;
    }
    
    ### ---
    ### Parse inline template if the variable equals to value
    ### ---
    sub if_like : TplExport {
        
        my ($self, $target, $pattern, $then, $else) = @_;
        
        my $tpl = Text::PSTemplate->get_current_parser;
        
        if (defined $target && defined $pattern && $target =~ /$pattern/) {
            if ($then) {
                return $then;
            } else {
                return $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
            }
        } else {
            if ($else) {
                return $else;
            } else {
                return $tpl->parse_block(1, {chop_left => 1, chop_right => 1});
            }
        }
        return;
    }
    
    ### ---
    ### Switch inline Templates and parse on given cases
    ### ---
    sub switch : TplExport {
        
        my ($self, $target, $case_ref, $default) = @_;
        
        my $tpl = Text::PSTemplate->get_current_parser;
        
        if (ref $case_ref eq 'ARRAY') {
            my $i = 0;
            for (; $i < scalar @$case_ref; $i++) {
                if ($target eq $case_ref->[$i]) {
                    return $tpl->parse_block($i, {chop_left => 1, chop_right => 1});
                }
            }
            if (defined $default) {
                return $tpl->parse($default);
            } else {
                return $tpl->parse_block($i, {chop_left => 1, chop_right => 1});
            }
        } elsif (ref $case_ref eq 'HASH') {
            if (exists $case_ref->{$target}) {
                return $case_ref->{$target};
            }
        }
        return $default;
    }
    
    ### ---
    ### Switch file Templates and parse on given cases
    ### ---
    sub tpl_switch : TplExport {
        
        my ($self, $target, $case_ref, $default) = @_;
        
        my $tpl = Text::PSTemplate->get_current_parser;
        
        if (exists $case_ref->{$target}) {
            return $tpl->parse_file($case_ref->{$target});
        } else {
            if ($default) {
                return $tpl->parse_file($default);
            }
        }
        return;
    }
    
    ### ---
    ### each
    ### ---
    sub each : TplExport {
        
        my ($self, $data, $asign1, $asign2) = @_;
        
        my $tpl = Text::PSTemplate->new;
        if (! ref $data) {
            $data = [$data];
        }
        
        my $out = '';
        if (ref $data eq 'ARRAY') {
            if (scalar @_ == 3) {
                for my $val (@$data) {
                    $tpl->set_var($asign1 => $val);
                    $out .= $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
                }
            } elsif (scalar @_ == 4) {
                my $idx = 0;
                for my $val (@$data) {
                    $tpl->set_var($asign1 => $idx++);
                    $tpl->set_var($asign2 => $val);
                    $out .= $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
                }
            }
        } elsif (ref $data eq 'HASH') {
            if (scalar @_ == 3) {
                while (my ($key, $value) = each(%$data)) {
                    $tpl->set_var($asign1 => $value);
                    $out .= $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
                }
            } elsif (scalar @_ == 4) {
                while (my ($key, $value) = each(%$data)) {
                    $tpl->set_var($asign1 => $key);
                    $tpl->set_var($asign2 => $value);
                    $out .= $tpl->parse_block(0, {chop_left => 1, chop_right => 1});
                }
            }
        }
        return $out;
    }
    
    ### ---
    ### Do nothing and returns null string
    ### <!-- <% bypass(' -->
    ### <base href="../">
    ### <!-- ') %> -->
    ### ---
    sub bypass : TplExport(chop => 1) {
        
        return '';
    }
    
    ### ---
    ### include a file into template
    ### ---
    sub include : TplExport {
        
        my ($self, $file, $vars) = @_;
        my $tpl = Text::PSTemplate->new->set_var(%$vars);
        return $tpl->parse_file($file);
    }
    
    ### ---
    ### set variable
    ### ---
    sub extract : TplExport {
        
        my ($self, $obj, $name) = @_;
        
        if (ref $obj eq 'ARRAY') {
            if (! defined $obj->[$name]) {
                die 'Undefined';
            }
            return $obj->[$name];
        }
        if (ref $obj eq 'HASH') {
            if (! defined $obj->{$name}) {
                die 'Undefined';
            }
            return $obj->{$name};
        }
        return;
    }
    
    ### ---
    ### set variable[deprecated]
    ### ---
    sub set_var : TplExport(chop => 1) {
        warn 'set_var is deprecated. Use assign instead.';
        my $self = shift;
        Text::PSTemplate->get_current_file_parser->set_var(@_);
        return;
    }
    
    ### ---
    ### assign variables
    ### ---
    sub assign : TplExport(chop => 1) {
        
        my $self = shift;
        Text::PSTemplate->get_current_file_parser->set_var(@_);
        return;
    }
    
    ### ---
    ### set delimiter
    ### ---
    sub set_delimiter : TplExport(chop => 1) {
        
        my ($self, $left, $right) = @_;
        Text::PSTemplate->get_current_file_parser->set_delimiter($left, $right);
        return;
    }
    
    ### ---
    ### output default instead of false value
    ### ---
    sub default : TplExport {
        
        my ($self, $value, $default) = @_;
        if ($value) {
            return $value;
        }
        return $default;
    }
    
    ### ---
    ### Counter 
    ### ---
    sub with : TplExport {
        
        my ($self, $dataset) = @_;
        my $tpl = Text::PSTemplate->new;
        my $out = '';
        while (my ($key, $value) = CORE::each(%$dataset)) {
            $tpl->set_var($key => $value);
            $out .= $tpl->parse_block(0);
        }
        return $out;
    }
    
    ### ---
    ### echo
    ### ---
    sub echo : TplExport {
        
        my ($self, $data) = @_;
        return $data;
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Control - Common control structures

=head1 SYNOPSIS

    <% if_equals($some_var, 'a', 'then', 'else') %>
    
    <% if_equals($some_var, 'a')<<THEN,ELSE %>
    then
    <% THEN %>
    else
    <% ELSE %>
    
    <% if($some_var, 'true', 'not true') %>
    
    <% if($some_var)<<THEN,ELSE %>
    true
    <% THEN %>
    not true
    <% ELSE %>
    
    <% if_in_array($some_var, ['a','b','c'], 'found', 'not found') %>
    
    <% if_in_array($some_var, ['a','b','c'])<<THEN,ELSE %>
    found
    <% THEN %>
    not found
    <% ELSE %>
    
    <% switch($some_var, {a => 'match a', b => 'match b'}, 'default') %>
    
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

=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds Common control structures into
your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Control', '');

Since this has promoted to core plugin, you don't have to explicitly load it.

=head1 TEMPLATE FUNCTIONS

Note that this document contains many keywords for specifying block endings such
as THEN or ELSE etc. These keywords are just examples. As the matter of
fact, you can say 'EOF' for any of them. The template engine only matters the
order of blocks. Think of Perl's here document. That's it. 
So do not attempt to memorize them. 

=head2 if_equals($var, $case, $then, [$else])

=head2 if_equals($var, $case)<<THEN[,ELSE]

Conditional branch. If $var equals to $case, $then is returned. Otherwise
returns $else. $else if optional.

    <% if_equals($a, '1', 'matched') %>

Instead of arguments, you can pass 1 or 2 blocks for each conditions. The blocks
will recursively be parsed as template.

    <% if_equals($a, '1')<<THEN %>
        This is <% escape_or_something($a) %>.
    <% THEN %>

=head2 if($var, $then, [$else])

=head2 if($var)<<THEN[,ELSE]

Conditional branch. If $var is a true value, returns $then. Otherwise returns
$else. The true means 'not 0' and 'not 0 length'. The exact definition about
true, see documents of perl itself. 

    <% if($var, 'true', 'not true') %>

For more about Block syntax, See if_equals function.

    <% if($var)<<THEN,ELSE %>
        This is <% escape_or_something_if_you_need($var) %>.
    <% THEN %>
        not true
    <% ELSE %>

=head2 if_in_array($var, $array_ref, $then, [$else])

=head2 if_in_array($var, $array_ref)<<THEN[,ELSE]

Conditional branch for searching in array. If $var is in the array, returns
$then, otherwise returns $else.

    <% if_in_array($var, [1,2,3,'a'], 'found', 'not found') %>

Block syntax is also available.

    <% if_in_array($var, [1,2,3,'a'])<<THEN,ELSE %>
        Found <% escape_or_something_if_you_need($var) %>.
    <% THEN %>
        Not found
    <% ELSE %>

=head2 switch($var, $hash_ref, [$default])

=head2 switch($var, $array_ref, [$default])<<CASE1,CASE2,...

Conditional branch for switching many cases.

    switch($var, {1 => 'case1', 2 => 'case2'}, 'default')

Block syntax is also available.

    switch($var, [1, 2])<<CASE1,CASE2,DEFAULT %>
        case1
    <% CASE1 %>
        case2 <% escape_or_something_if_you_need($var) %>
    <% CASE2 %>
        default
    <% DEFAULT %>

=head2 tpl_switch($var, $hash_ref)

Conditional branch for switching many cases. This function parses file templates
for each cases and returns the parsed string.

=head2 if_like($var, $pattern, $then, $else)

=head2 if_like($var, $pattern)<<THEN,ELSE

Regular expression matching. If matched, returns $then otherwise returns $else.

    <% if_like($var, '^\d+$', 'match', 'unmatch') %>

Block syntax is also available. 

    <% if_like($var, '^\d+$')<<THEN,ELSE %>
        match
    <% THEN %>
        unmatch
    <% ELSE %>

=head2 each($var, $value)<<TPL

=head2 each($var, $key => $value)<<TPL

Iteration control for given array or hash.

    <% each($array => 'name')<<EOF%>
        <% $name %>
    <% EOF %>

    <% each($hash, 'key' => 'value')<<EOF %>
        <% $key %>
        <% $value %>
    <% EOF %>

=head2 bypass('')

This function do nothing and returns null string.

    <!-- <% bypass(' -->
    <base href="../">
    <!-- ') %> -->

Above results as..

    <!--  -->

=head2 include(FILENAME, [VARIABLES])

This function include a file content of given name into current template.

    <% include('path/to/file.txt', {some_var => 'aaa'}) %>

=head2 assign(%dataset)

=head2 set_var(%dataset) [deprecated]

Assigns variables with given dataset. The variables will be available in current
file context. 

    <% set_var({some_name => 'some value'}) %>
    <% $some_name %>

Note that the variable is always inherited in sub templates. This means the
assign does not affect mother templates but sub templates.

=head2 set_delimiter(LEFT, RIGHT)

This method changes the tag delimiter for parse.

    <% set_delimiter('[%', '%]') %>

=head2 extract($obj, $key)

Extracts element out of hash or object.
    
    <% extract($obj, 'name') %>

You also can say..

    <% $obj->{name} %>

=head2 default($var, $default)

If $var is null string, returns $default.

    <% default($var, 'empty') %>

=head2 with($dataset)<<BLOCK

Parses block with given variables.

    <% with([var => 'hoge'])<<EOF %>
        <% $var %>
    <% EOF %>

=head2 echo($var)

This function just returns given argument.

    <% echo($var) %>

This may risky but if necessary you can wrap perl code as follows.

    <% echo($var. 'foo') %>

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
