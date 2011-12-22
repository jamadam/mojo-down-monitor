package Text::PSTemplate::PluginBase;
use strict;
use warnings;
use Text::PSTemplate;
use Attribute::Handlers;
use 5.005;
use Scalar::Util qw{blessed};
use Carp;
use Scalar::Util qw(weaken);
use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Path;
use Fcntl qw(:flock);

    my %_attr_tpl_export_cache;
    my %_findsym2_tbl;
    
    my $MEM_AS  = 1;
    my $MEM_TPL = 2;
    
    ### ---
    ### Constructor
    ### ---
    sub new {
        
        my ($class, $tpl, $as) = @_;
        
        no strict 'refs';
        foreach my $pkg (@{$class. '::ISA'}) {
            if ($pkg ne __PACKAGE__) {
                $tpl->plug($pkg);
            }
        }
        my $self = bless {
            $MEM_TPL    => $tpl,
            $MEM_AS     => $as,
        }, $class;
        
        if (! $_findsym2_tbl{$class}) {
            _findsym2($class);
            _init_tpl_exports($class);
        }
        $self->_set_tpl_funcs($tpl);
        
        weaken $self->{$MEM_TPL};
        return $self;
    }
    
    sub _init_tpl_exports {
        
        my $class = shift;
        for my $entry (@{$_attr_tpl_export_cache{$class}}) {
            $entry->[2] = $_findsym2_tbl{$class}->{$entry->[0]};
        }
    }
    
    sub _findsym2 {
        
        my $pkg = shift;
        if (! exists $_findsym2_tbl{$pkg}) {
            no strict 'refs';
            my $out = {};
            my $sym_tbl = \%{$pkg."::"};
            for my $key (keys %$sym_tbl) {
                my $val = $sym_tbl->{$key};
                if (ref \$val eq 'GLOB' && *{$val}{'CODE'}) {
                    $out->{\&{$val}} = $key;
                }
            }
            $_findsym2_tbl{$pkg} = $out;
        }
        return $_findsym2_tbl{$pkg};
    }
    
    ### ---
    ### Get template function entries
    ### ---
    sub _get_tpl_exports {
        
        my $pkg = shift;
        my @out = ();
        no strict 'refs';
        foreach my $super (@{$pkg. '::ISA'}) {
            if ($super ne __PACKAGE__) {
                push(@out, @{_get_tpl_exports($super)});
            }
        }
        if (my $a = $_attr_tpl_export_cache{$pkg}) {
            push(@out, @$a);
        }
        return \@out;
    }
    
    ### ---
    ### Template function Attribute
    ### ---
    sub TplExport : ATTR(BEGIN) {
        
        my($pkg, undef, $ref, undef, $data, undef) = @_;
        push(@{$_attr_tpl_export_cache{$pkg}}, [$ref, $data ? {@$data} : {}]);
    }
    
    ### ---
    ### Register template functions
    ### ---
    sub _set_tpl_funcs {
        
        my ($self, $tpl) = (@_);
        my $org = ref $self;
        my $namespace = defined $self->{$MEM_AS} ? $self->{$MEM_AS} : $org;
        $namespace .= $namespace ? '::' : '';
        
        my $_tpl_exports = _get_tpl_exports($org);
        foreach my $func (@$_tpl_exports) {
            my $ref = $func->[0];
            my $rapper = sub {
                Text::PSTemplate::set_chop($func->[1]->{chop});
                my $ret = $self->$ref(@_);
                return (defined $ret ? $ret : '');
            };
            $tpl->set_func($namespace. $func->[2] => $rapper);
        }
        
        return $self;
    }
    
    ### ---
    ### get template parser instance which $self belongs to
    ### ---
    sub get_engine {
        my ($self) = shift;
        return $self->{$MEM_TPL};
    }

1;

__END__

=head1 NAME

Text::PSTemplate::PluginBase - Plugin Abstract Class

=head1 SYNOPSIS

    package MyApp;
    
    my $tpl = Text::PSTemplate->new;
    
    my $plugin = $tpl->plug('MyPlug1');
    # ..or..
    my $plugin = $tpl->plug('MyPlug1', 'Your::Namespace');
    
    package MyPlug1;
    
    use base qw(Text::PSTemplate::PluginBase);
    
    sub say_hello_to : TplExport {
    
        my ($plugin, $name) = (@_);
        
        return "Hello $name";
    }
    
    # in templates ..
    # <% Your::Namespace::say_hello_to('Jamadam') %>
    
    use LWP::Simple;
    sub insert_remote_data : TplExport {
        my ($plugin, $url) = (@_);
        return LWP::Simple::get($url);
    }
    
    # in templates ..
    # <% insert_remote_data('http://example.com/') %>
    
=head1 DESCRIPTION

This is an Abstract Class which represents plugins for
Text::PSTemplate.

The plugin classes can contain subroutines with TplExport attribute.
These subroutines are targeted as template function.

The Plugins can inherit other plugins. The new constructor automatically
instantiates all depended plugins and template functions are inherited even in
templates.

=head1 METHODS

=head2 Text::PSTemplate::PluginBase->new($template)

Constructor. This takes template instance as argument.

    my $tpl = Text::PSTemplate->new;
    my $myplug = My::Plug->new($tpl);

Note that in list context, this always returns an array with 1 element.
If the key doesn't exists, this returns (undef).

=head2 $self->get_engine()

This method returns the template parser instance which is the one the plugin
belongs to.

    my $engine = $get_engine()

=head1 ATTRIBUTE

=head2 TplExport [(chop => 1)]

This attribute makes the subroutine available in templates.

    sub your_func : TplExport {
        
    }

chop => 1 causes the following line breaks to be omitted.

    sub your_func : TplExport(chop => 1) {
        
    }

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
