package Text::PSTemplate::Plugin::Time;
use strict;
use warnings;
use base qw(Text::PSTemplate::PluginBase);
use Text::PSTemplate;
use Time::Local;
    
    my @months  =
        qw(January February March April May June July August
        September October November December);
    
    my @wdays   =
        qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday);
    
    sub before : TplExport {
        
        my ($self, $date1, $date2, $include_equal) = @_;
        my $ep1 = $self->date_to_epoch($date1);
        my $ep2 = $self->date_to_epoch($date2);
        if (($ep1 < $ep2) || ($include_equal && $ep1 == $ep2)) {
            return 1;
        } else {
            return 0;
        }
    }
    
    sub after : TplExport {
        
        my ($self, $date1, $date2, $include_equal) = @_;
        my $ep1 = $self->date_to_epoch($date1);
        my $ep2 = $self->date_to_epoch($date2);
        if (($ep1 > $ep2) || ($include_equal && $ep1 == $ep2)) {
            return 1;
        } else {
            return 0;
        }
    }
    
    ### ---
    ### Reformat time string
    ### ---
    sub reformat : TplExport {
        
        my ($self, $ts, $format, $data, $asset) = @_;
        $ts     ||= $self->now();
        $format ||= '%04s/%02s/%02s %02s:%02s:%02s';
        $data   ||= [5,4,3,2,1,0,10];
        $asset ||= {};
        $asset = {
            months => \@months,
            wdays  => \@wdays,
            %$asset,
        };
        
        my $epoch = $self->date_to_epoch($ts);
        
        my @localtime = _localtime($epoch);
        @localtime = (
        $localtime[0],                                  ### 0.  sec
        $localtime[1],                                  ### 1.  min
        $localtime[2],                                  ### 2.  hour
        $localtime[3],                                  ### 3.  mday
        $localtime[4],                                  ### 4.  mon
        $localtime[5],                                  ### 5.  year
        $localtime[6],                                  ### 6.  wday
        $localtime[7],                                  ### 7.  yday
        $localtime[8],                                  ### 8.  isdst
        $epoch,                                         ### 9.  epoch
        $asset->{wdays}->[$localtime[6]],               ### 10. wday in 'Sunday' format
        substr($asset->{wdays}->[$localtime[6]], 0, 3), ### 11. wday in 'Sun' format
        $asset->{months}->[$localtime[4]],              ### 12. month in 'January' format
        substr($asset->{months}->[$localtime[4]], 0, 3),### 13. month in 'Jan' format
        substr($localtime[5] + 1900, 2, 2),             ### 14. year in format like '01' stands for '2001'
        $localtime[2] < 12 ? 'AM' : 'PM',               ### 15. AM/PM
        $localtime[2] < 12 
            ? $localtime[2] 
            : $localtime[2] - 12,                       ### 16. AM/PM style hour
        );
        
        return sprintf($format, map {$localtime[$_]} @$data);
    }
    
    sub epoch : TplExport {
        
        return time;
    }
    
    sub now : TplExport {
        
        my ($self) = @_;
        return $self->epoch_to_iso8601();
    }
    
    ### ---
    ### extract date part from datetime
    ### ---
    sub date : TplExport {
        
        my ($self, $date) = @_;
        
        if (!$date) {
            return;
        }
        my @time_array = $self->split_date($date);
        
        return 
            sprintf("%04d-%02d-%02d", $time_array[5], $time_array[4], $time_array[3]);
    }
    
    ### ---
    ### custom localtime
    ### ---
    sub _localtime {
        my ($epoch) = @_;
        my @t = localtime($epoch || time);
        $t[5] += 1900;
        $t[4] += 1;
        return @t[0..5];
    }
    
    ### ---
    ### iso8601
    ### ---
    sub iso8601 : TplExport {
        
        my ($self, $date) = @_;
        my @time_array = $self->split_date($date) or _localtime();
        
        return 
            sprintf("%04d-%02d-%02d %02d:%02d:%02d", 
                $time_array[5], $time_array[4], $time_array[3], 
                $time_array[2], $time_array[1], $time_array[0]);
    }

    ### ---
    ### 2000-01-01 23:23:23
    ### ---
    sub epoch_to_iso8601 : TplExport {
        
        my ($self, $epoch) = @_;
        my ($sec, $min, $hour, $mday, $mon, $year) = _localtime($epoch);
        
        return
            sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    }
    
    ### ---
    ### Convert any date string to epoch
    ### ---
    sub date_to_epoch : TplExport {
        
        my ($self, $date) = @_;
        
        my @time_array = $self->split_date($date) or _localtime();
        
        $time_array[4]--;
        $time_array[5] -= 1900;
        
        return _fixed_timelocal(@time_array);
    }
    
    ### ---
    ### Split any date string to array
    ### ---
    sub split_date : TplExport {
        
        my ($self, $date) = @_;
        if (! $date) {
            return;
        }
        if ($date =~ qr{^(\d{4})([\./-]?)(\d\d?)(?:\2(\d\d?)(?:( |T|\2)(\d\d?)([:-]?)(\d\d?)(?:\7(\d\d?)(\.\d+)?)?([\+\-]\d\d:?\d\d)?Z?)?)?$}) {
            return ($9 or 0), ($8 or 0), ($6 or 0), ($4 or 1), ($3 or 1), $1;
        }
        die "Invalid date format: $date";
    }
    
    ### ---
    ### Flexible timelocal wrapper
    ### ---
    sub _fixed_timelocal {
        
        my ($sec, $minute, $hour, $date, $month, $year) = @_;
        $minute += int($sec / 60);
        $sec     = $sec % 60;
        $hour   += int($minute / 60);
        $minute  = $minute % 60;
        $date   += int($hour / 24);
        $hour    = $hour % 24;
        
        my $lastday = _day_count($year, $month);
        
        $month = ($date > $lastday) ? $month + 1 : $month;
        $date  = ($date > $lastday) ? $date - $lastday : $date;
        
        $year += int($month / 12);
        $month = $month % 12;
        
        my $ret = eval{
            timelocal($sec, $minute, $hour, $date, $month, $year);
        };
        if ($@ && $@ =~ 'Day too big') {
            return '4458326400';
        }
        return $ret;
    }
    
    my @_normal = (31,30,31,30,31,30,31,31,30,31,30,31);
    my @_leaped = (31,28,31,30,31,30,31,31,30,31,30,31);
    
    sub _day_count {
        
        my ($year, $month) = @_;
        return _is_leap($year) ? $_leaped[$month] : $_normal[$month];
    }
    
    sub _is_leap {
    
        return(
            ($_[0]% 400 == 0 )
            or
            (
                ($_[0] % 100 != 0)
                and
                ($_[0] % 4 == 0)
            )
        );
    }

1;

__END__

=head1 NAME

Text::PSTemplate::Plugin::Time - Time Utility

=head1 SYNOPSIS

    <% date() %>
    <% date_to_epoch() %>
    <% epoch_to_iso8601() %>
    <% iso8601() %>
    <% now() %>
    <% reformat() %>
    <% split_date() %>
    
=head1 DESCRIPTION

This is a Plugin for Text::PSTemplate. This adds Time Utility functions into
your template engine.

To activate this plugin, your template have to load it as follows

    use Text::PSTemplate;
    
    my $tpl = Text::PSTemplate->new;
    $tpl->plug('Text::PSTemplate::Plugin::Time', '');

=head1 TEMPLATE FUNCTIONS

=head2 date([$date_string])

=head2 date_to_epoch([$date_string])

=head2 epoch_to_iso8601($serial)

=head2 iso8601([$date_string])

=head2 now()

=head2 reformat($ts, $format, $data, $asset)

=head2 split_date([$date_string])

=head2 before($date1, $date2)

=head2 after($date1, $date2)

=head2 epoch()

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
