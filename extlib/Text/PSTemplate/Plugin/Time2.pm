package Text::PSTemplate::Plugin::Time2;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
use Text::PSTemplate::DateTime;
use Time::Local;
    
    sub before : TplExport {
        
        my ($self, $date1, $date2, $include_equal) = @_;
        my $ep1 = Text::PSTemplate::DateTime->parse($date1)->epoch;
        my $ep2 = Text::PSTemplate::DateTime->parse($date2)->epoch;
        if (($ep1 < $ep2) || ($include_equal && $ep1 == $ep2)) {
            return 1;
        }
    }
    
    sub after : TplExport {
        
        my ($self, $date1, $date2, $include_equal) = @_;
        my $ep1 = Text::PSTemplate::DateTime->parse($date1)->epoch;
        my $ep2 = Text::PSTemplate::DateTime->parse($date2)->epoch;
        if (($ep1 > $ep2) || ($include_equal && $ep1 == $ep2)) {
            return 1;
        }
    }
    
    sub new_datetime : TplExport {
        
        my ($self, $date) = @_;
        return Text::PSTemplate::DateTime->parse($date);
    }
    
    ### ---
    ### Reformat time string
    ### ---
    sub strftime : TplExport {
        
        my ($self, $ts, $format, $asset) = @_;
        if (! $ts) {
            return;
        }
        my $dt = Text::PSTemplate::DateTime->parse($ts);
        if ($asset->{months}) {
            $dt->set_month_asset($asset->{months});
        }
        if ($asset->{wdays}) {
            $dt->set_weekday_asset($asset->{wdays});
        }
        return $dt->strftime($format);
    }
    
    sub now : TplExport {
        
        my ($self) = @_;
        return Text::PSTemplate::DateTime->new->iso8601(' ');
    }
    
    ### ---
    ### extract date part from datetime
    ### ---
    sub date : TplExport {
        
        my ($self, $date, $delim) = @_;
        return Text::PSTemplate::DateTime->parse($date)->ymd($delim);
    }
    
    ### ---
    ### 2000-01-01 23:23:23
    ### ---
    sub iso8601 : TplExport {
        
        my ($self, $date) = @_;
        return Text::PSTemplate::DateTime->parse($date)->iso8601(' ');
    }
    
    ### ---
    ### Convert any date string to epoch
    ### ---
    sub epoch : TplExport {
        
        my ($self, $date) = @_;
        return Text::PSTemplate::DateTime->parse($date)->epoch;
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Time2 - Time Utility [Experimental]

=head1 SYNOPSIS

    <% date() %>
    <% epoch() %>
    <% iso8601() %>
    <% now() %>
    <% strftime() %>
    
=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds Time Utility functions into
your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Time', '');

=head1 TEMPLATE FUNCTIONS

=head2 new_datetime([$date_string]);

=head2 date([$date_string])

=head2 epoch([$date_string])

=head2 iso8601([$date_string])

=head2 now()

=head2 strftime($ts, $format, $asset)

=head2 before($date1, $date2)

=head2 after($date1, $date2)

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
