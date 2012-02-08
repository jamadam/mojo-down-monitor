package Text::PSTemplate::DateTime;
use strict;
use warnings;
use Time::Local;
use Carp;
use overload (
    fallback => 1,
    '<=>' => '_compare_overload',
    'cmp' => '_compare_overload',
    '""'  => '_stringify_overload',
    'eq'  => '_string_equals_overload',
    'ne'  => '_string_not_equals_overload',
);
    
    sub _stringify_overload {
        my $self = shift;
    
        return $self->iso8601 unless $self->{formatter};
        return $self->{formatter}->format_datetime($self);
    }
    
    sub _compare_overload {
        # note: $_[1]->compare( $_[0] ) is an error when $_[1] is not a
        # DateTime (such as the INFINITY value)
        return $_[2] ? - $_[0]->compare( $_[1] ) : $_[0]->compare( $_[1] );
    }
    
    sub _string_equals_overload {
        my ( $class, $dt1, $dt2 ) = ref $_[0] ? ( undef, @_ ) : @_;
    
        return unless(
            blessed $dt1 && $dt1->can('utc_rd_values') &&
            blessed $dt2 && $dt2->can('utc_rd_values')
        );
    
        $class ||= ref $dt1;
        return ! $class->compare( $dt1, $dt2 );
    }
    
    sub _string_not_equals_overload {
        return ! _string_equals_overload(@_);
    }

    my $months  =
        [qw(January February March April May June July August
        September October November December)];
    
    my $wdays   =
        [qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday)];
    
    my $etc_timezone;
    
    if (open(my $fh, '<', '/etc/timezone')) {
        $etc_timezone = <$fh>;
        $etc_timezone =~ s{\r|\s}{};
    }
    
    sub _tz_to_offset {
        my $name = shift;
        my $ret;
        if (defined $name) {
            $ret = Text::PSTemplate::DateTime::Catalog::get_offset($name);
        } elsif ($ENV{TZ}) {
            $ret = Text::PSTemplate::DateTime::Catalog::get_offset($ENV{TZ});
        } elsif ($etc_timezone) {
            $ret = Text::PSTemplate::DateTime::Catalog::get_offset($etc_timezone);
        }
        return $ret || 0;
    }
    
    my $MEM_EPOCH   = 1;
    my $MEM_PARTS   = 2;
    my $MEM_ASSET   = 3;
    my $MEM_OFFSET  = 4;
    
    sub today {
        my ($class) = @_;
        $class->new();
    }
    
    sub new {
        my ($class, %args) = @_;
        
        my $self = {
            $MEM_ASSET  => [$months, $wdays],
            $MEM_PARTS  => [],
            $MEM_OFFSET => _tz_to_offset($args{time_zone}),
        };
        if (scalar @_ == 1) {
            $self->{$MEM_EPOCH} = time;
        } else {
            my @parts = (
                $args{second}, $args{minute}, $args{hour},
                $args{day}, $args{month}, $args{year}
            );
            $self->{$MEM_EPOCH} = _timelocal(\@parts, $self->{$MEM_OFFSET});
        }
        return bless $self, $class;
    }
    
    sub now {
        $_[0]->new;
    }
    
    sub from_epoch {
        my ($class, %args) = @_;
        
        my $self = {
            $MEM_EPOCH  => $args{epoch},
            $MEM_PARTS  => [],
            $MEM_ASSET  => [$months, $wdays],
            $MEM_OFFSET => _tz_to_offset($args{time_zone}),
        };
        return bless $self, $class;
    }
    
    sub parse {
        my ($class, $str, $timezone) = @_;
        
        my @a;
        if ($str && $str =~ qr{^(\d{4})([\./-]?)(\d\d?)(?:\2(\d\d?)(?:( |T|\2)(\d\d?)([:-]?)(\d\d?)(?:\7(\d\d?)(\.\d+)?)?([\+\-]\d\d:?\d\d)?Z?)?)?$}) {
            @a = map {$_ + 0} (($9 or 0), ($8 or 0), ($6 or 0), ($4 or 1), ($3 or 1), $1);
        } else {
            croak "Invalid date format: $str";
        }
        my $offset = _tz_to_offset($timezone);
        my $epoch = _timelocal(\@a, $offset);
        my $self = {
            $MEM_EPOCH  => $epoch,
            $MEM_PARTS  => \@a,
            $MEM_ASSET  => [$months, $wdays],
            $MEM_OFFSET => $offset,
        };
        return bless $self, $class;
    }
    
    sub add {
        my ($self, %args) = @_;
        if (scalar @_ > 3) {
            croak 'You can set just one element to add at once';
        }
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        if ($args{weeks}) {
            $new_args{day} += $args{weeks} * 7;
        }
        if ($args{years}) {
            $new_args{year} += $args{years};
        }
        if ($args{months}) {
            $new_args{month} += $args{months};
        }
        if ($args{days}) {
            $new_args{day} += $args{days};
        }
        if ($args{hours}) {
            $new_args{hour} += $args{hours};
        }
        if ($args{minutes}) {
            $new_args{minute} += $args{minutes};
        }
        if ($args{seconds}) {
            $new_args{second} += $args{seconds};
        }
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_year {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $val,
            month       => $self->month,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_month {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $val,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_day {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $val,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_hour {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $self->day,
            hour        => $val,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_minute {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $val,
            second      => $self->second,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_second {
        my ($self, $val) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $val,
            time_zone   => $self->offset,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }

    sub set {
        my ($self, %args) = @_;
        my %new_args = (
            year        => $self->year,
            month       => $self->month,
            day         => $self->day,
            hour        => $self->hour,
            minute      => $self->minute,
            second      => $self->second,
            time_zone   => $self->offset,
            %args,
        );
        %$self = %{(ref $self)->new(%new_args)};
        return $self;
    }
    
    sub set_time_zone {
        my ($self, $tz_name) = @_;
        my $offset = _tz_to_offset($tz_name);
        $self->{$MEM_PARTS} = [];
        $self->{$MEM_OFFSET} = $offset;
        return $self;
    }
    
    sub set_month_asset {
        my ($self, $asset) = @_;
        $self->{$MEM_ASSET}->[0] = $asset;
    }
    
    sub set_weekday_asset {
        my ($self, $asset) = @_;
        $self->{$MEM_ASSET}->[1] = $asset;
    }
    
    sub offset {
        my ($self) = @_;
        return $self->{$MEM_OFFSET};
    }
    
    sub compare {
        my ($self, $obj) = @_;
        if ($self->{$MEM_EPOCH} == $obj->{$MEM_EPOCH}) {
            return 0;
        } elsif ($self->{$MEM_EPOCH} > $obj->{$MEM_EPOCH}) {
            return 1;
        } else {
            return -1;
        }
    }
    
    my $_strftime_tbl = {
        a => sub {$_[0]->day_abbr},
        A => sub {$_[0]->day_name},
        b => sub {$_[0]->month_abbr},
        B => sub {$_[0]->month_name},
        c => sub {croak 'not implemented yet'},
        C => sub {croak 'not implemented yet'},
        d => sub {sprintf('%02d', $_[0]->day)},
        D => sub {croak 'not implemented yet'},
        e => sub {croak 'not implemented yet'},
        f => sub {croak 'not implemented yet'},
        F => sub {croak 'not implemented yet'},
        g => sub {croak 'not implemented yet'},
        G => sub {croak 'not implemented yet'},
        h => sub {croak 'not implemented yet'},
        H => sub {sprintf('%02d', $_[0]->hour)},
        I => sub {sprintf('%02d', $_[0]->hour_12_0)},
        j => sub {sprintf('%03d', $_[0]->day_of_year)},
        k => sub {sprintf('%02d', $_[0]->hour)},
        l => sub {sprintf('%02d', $_[0]->hour_12_0)},
        m => sub {sprintf('%02d', $_[0]->month)},
        M => sub {sprintf('%02d', $_[0]->minute)},
        n => sub {croak 'not implemented yet'},
        N => sub {croak 'not implemented yet'},
        p => sub {$_[0]->am_or_pm},
        P => sub {lc $_[0]->am_or_pm},
        r => sub {croak 'not implemented yet'},
        R => sub {croak 'not implemented yet'},
        s => sub {$_[0]->epoch},
        S => sub {sprintf('%02d', $_[0]->second)},
        t => sub {croak 'not implemented yet'},
        T => sub {croak 'not implemented yet'},
        u => sub {$_[0]->day_of_week},
        U => sub {croak 'not implemented yet'},
        V => sub {croak 'not implemented yet'},
        w => sub {croak 'not implemented yet'},
        W => sub {croak 'not implemented yet'},
        x => sub {croak 'not implemented yet'},
        X => sub {croak 'not implemented yet'},
        y => sub {$_[0]->year_abbr},
        Y => sub {$_[0]->year},
        z => sub {croak 'not implemented yet'},
        Z => sub {croak 'not implemented yet'},
        '%' => sub {'%'},
    };
    
    sub strftime {
        my ($self, $format) = @_;
        $format =~ s{%(.)}{
            if (exists $_strftime_tbl->{$1}) {
                $_strftime_tbl->{$1}->($self);
            } else {
                '%'.$1;
            }
        }ge;
        return $format;
    }
    
    sub epoch {
        my $self = shift;
        return $self->{$MEM_EPOCH};
    }
    
    sub ymd {
        my ($self, $sepa) = @_;
        $sepa ||= '-';
        my (undef, undef, undef, $mday, $mon, $year) =
                        _localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET});
        return sprintf("%04d%s%02d%s%02d", $year, $sepa, $mon, $sepa, $mday);
    }
    
    sub year {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[5]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[5];
    }
    
    sub month {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[4]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[4];
    }
    
    sub day {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[3]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[3];
    }
    
    sub hour {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[2]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[2];
    }
    
    sub minute {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[1]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[1];
    }
    
    sub second {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[0]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[0];
    }
    
    sub day_of_week {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[6]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[6];
    }
    
    sub day_of_year {
        my ($self) = @_;
        if (! $self->{$MEM_PARTS}->[7]) {
            $self->{$MEM_PARTS} =
                    [_localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET})];
        }
        return $self->{$MEM_PARTS}->[7] + 1;
    }
    
    sub month_name {
        my $self = shift;
        return $self->{$MEM_ASSET}->[0]->[$self->month - 1];
    }
    
    sub month_abbr {
        my $self = shift;
        return substr($self->month_name, 0, 3)
    }
    
    sub day_name {
        my $self = shift;
        $self->{$MEM_ASSET}->[1]->[$self->day_of_week];
    }
    
    sub day_abbr {
        my $self = shift;
        return substr($self->day_name, 0, 3)
    }
    
    sub year_abbr {
        my $self = shift;
        return substr($self->year, 2, 2);
    }
    
    sub am_or_pm {
        my $self = shift;
        return $self->hour < 12 ? 'AM' : 'PM'
    }
    
    sub hour_12_0 {
        my $self = shift;
        my $hour = $self->hour;
        return $hour < 12 ? $hour : $hour - 12,    
    }
    
    sub quarter {
        my ($self) = @_;
        return
            ($self->month <= 3) ? 1 :
            ($self->month <= 6) ? 2 :
            ($self->month <= 9) ? 3 : 4;
    }
    
    sub month_0 {
        my ($self) = @_;
        return $self->month - 1;
    }
    
    sub day_of_month {
        my ($self) = @_;
        return $self->day;
    }
    
    sub day_of_month_0 {
        my ($self) = @_;
        return $self->day - 1;
    }
    
    sub day_0 {
        my ($self) = @_;
        return $self->day - 1;
    }
    
    sub mday_0 {
        my ($self) = @_;
        return $self->day - 1;
    }
    
    sub mday {
        my ($self) = @_;
        return $self->day;
    }
    
    sub hour_1 {
        my ($self) = @_;
        return $self->hour;
    }
    
    sub hour_12 {
        my ($self) = @_;
        return $self->hour_12_0;
    }
    
    sub min {
        my ($self) = @_;
        return $self->minute;
    }
    
    sub sec {
        my ($self) = @_;
        return $self->second;
    }
    
    sub day_of_year_0 {
        my ($self) = @_;
        return $self->day_of_year - 1;
    }
    
    sub day_of_week_0 {
        my ($self) = @_;
        return $self->day_of_week - 1;
    }
    
    sub wday {
        my ($self) = @_;
        return $self->day_of_week;
    }
    
    sub wday_0 {
        my ($self) = @_;
        return $self->day_of_week - 1;
    }
    
    sub date {
        my ($self) = @_;
        return $self->ymd;
    }
    
    sub mdy {
        my ($self, $sepa) = @_;
        $sepa ||= '-';
        my (undef, undef, undef, $mday, $mon, $year) =
                        _localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET});
        return sprintf("%02d%s%02d%s%04d", $mon, $sepa, $mday, $sepa, $year);
    }
    
    sub dmy {
        my ($self, $sepa) = @_;
        $sepa ||= '-';
        my (undef, undef, undef, $mday, $mon, $year) =
                        _localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET});
        return sprintf("%02d%s%02d%s%04d", $mday, $sepa, $mon, $sepa, $year);
    }
    
    sub hms {
        my ($self, $sepa) = @_;
        $sepa ||= ':';
        my ($sec, $min, $hour, undef,undef,undef) =
                        _localtime($self->{$MEM_EPOCH}, $self->{$MEM_OFFSET});
        return sprintf("%02d%s%02d%s%02d", $hour, $sepa, $min, $sepa, $sec);
    }
    
    sub time {
        my ($self) = @_;
        return $self->hms;
    }
    
    sub datetime {
        my ($self, $sepa) = @_;
        $sepa ||= 'T';
        return $self->ymd . $sepa. $self->hms;
    }
    
    sub iso8601 {
        my ($self, $sepa) = @_;
        $sepa ||= 'T';
        return $self->ymd . $sepa. $self->hms;
    }
    
    sub is_leap_year {
        my $self = shift;
        _is_leap_year($self->year);
    }
    
    ### ---
    ### custom localtime
    ### ---
    sub _localtime {
        my ($epoch, $offset) = @_;
        $epoch += ($offset || 0);
        my @t = gmtime($epoch);
        $t[5] += 1900;
        $t[4] += 1;
        $t[6] = $t[6] == 0 ? 7 : $t[6];
        return @t;
    }
    
    ### ---
    ### Flexible timelocal wrapper
    ### ---
    sub _timelocal {
        my ($args, $offset) = @_;
        my ($sec, $minute, $hour, $date, $month, $year) = @$args;
        $sec ||= 0;
        $minute ||= 0;
        $hour ||= 0;
        $date = ! defined $date ? 1 : $date; # $date must be 1..31
        $date--;
        $month = ! defined $month ? 1 : $month; # $month must be 1..12
        $month--;
        
        ($minute, $sec) = _carry($minute, $sec, 60);
        ($hour, $minute) = _carry($hour, $minute, 60);
        ($date, $hour) = _carry($date, $hour, 24);
        ($year, $month) = _carry($year, $month, 12);
        
        my $ret = eval {
            timegm($sec, $minute, $hour, 1, $month, $year - 1900);
        };
        if ($@) {
            if ($@ =~ 'Day too big') {
                warn $@;
                return '4458326400'; # I know this is bull shit
            } else {
                croak $@;
            }
        }
        $ret += $date * 86400;
        $ret -= ($offset || 0);
        return $ret;
    }
    
    sub _carry {
        my ($super, $sub, $limit) = @_;
        if ($sub >= 0) {
            $super += int($sub / $limit);
            $sub = $sub % $limit;
        } else {
            my $tmp = abs($sub) - 1;
            $super -= (int($tmp / $limit) + 1);
            $sub = $limit - (($tmp) % $limit + 1);
        }
        return ($super, $sub);
    }
    
    sub last_day_of_month {
        my ($class, %args) = @_;
        my $self = $class->new(year => $args{year}, month => $args{month} + 1);
        $self->add(days => -1);
    }
    
    my @_normal = (31,30,31,30,31,30,31,31,30,31,30,31);
    my @_leaped = (31,28,31,30,31,30,31,31,30,31,30,31);
    
    sub _day_count {
        my ($year, $month) = @_;
        return
            _is_leap_year($year)
                ? $_leaped[($month % 12) - 1] : $_normal[($month % 12) - 1];
    }
    
    sub _is_leap_year {
        return 0 if $_[0] % 4;
        return 1 if $_[0] % 100;
        return 0 if $_[0] % 400;
        return 1;
    }

package Text::PSTemplate::DateTime::Catalog;
use strict;
use warnings;

    my %timezone_tbl = (
        'AKST9AKDT' => -32400,
        'Africa/Abidjan' => 0,
        'Africa/Accra' => 0,
        'Africa/Addis_Ababa' => 10800,
        'Africa/Algiers' => 3600,
        'Africa/Asmara' => 10800,
        'Africa/Asmera' => 10800,
        'Africa/Bamako' => 0,
        'Africa/Bangui' => 3600,
        'Africa/Banjul' => 0,
        'Africa/Bissau' => 0,
        'Africa/Blantyre' => 7200,
        'Africa/Brazzaville' => 3600,
        'Africa/Bujumbura' => 7200,
        'Africa/Cairo' => 7200,
        'Africa/Casablanca' => 0,
        'Africa/Ceuta' => 3600,
        'Africa/Conakry' => 0,
        'Africa/Dakar' => 0,
        'Africa/Dar_es_Salaam' => 10800,
        'Africa/Djibouti' => 10800,
        'Africa/Douala' => 3600,
        'Africa/El_Aaiun' => 0,
        'Africa/Freetown' => 0,
        'Africa/Gaborone' => 7200,
        'Africa/Harare' => 7200,
        'Africa/Johannesburg' => 7200,
        'Africa/Kampala' => 10800,
        'Africa/Khartoum' => 10800,
        'Africa/Kigali' => 7200,
        'Africa/Kinshasa' => 3600,
        'Africa/Lagos' => 3600,
        'Africa/Libreville' => 3600,
        'Africa/Lome' => 0,
        'Africa/Luanda' => 3600,
        'Africa/Lubumbashi' => 7200,
        'Africa/Lusaka' => 7200,
        'Africa/Malabo' => 3600,
        'Africa/Maputo' => 7200,
        'Africa/Maseru' => 7200,
        'Africa/Mbabane' => 7200,
        'Africa/Mogadishu' => 10800,
        'Africa/Monrovia' => 0,
        'Africa/Nairobi' => 10800,
        'Africa/Ndjamena' => 3600,
        'Africa/Niamey' => 3600,
        'Africa/Nouakchott' => 0,
        'Africa/Ouagadougou' => 0,
        'Africa/Porto-Novo' => 3600,
        'Africa/Sao_Tome' => 0,
        'Africa/Timbuktu' => 0,
        'Africa/Tripoli' => 7200,
        'Africa/Tunis' => 3600,
        'Africa/Windhoek' => 3600,
        'America/Adak' => -36000,
        'America/Anchorage' => -32400,
        'America/Anguilla' => -14400,
        'America/Antigua' => -14400,
        'America/Araguaina' => -10800,
        'America/Argentina/Buenos_Aires' => -10800,
        'America/Argentina/Catamarca' => -10800,
        'America/Argentina/ComodRivadavia' => -10800,
        'America/Argentina/Cordoba' => -10800,
        'America/Argentina/Jujuy' => -10800,
        'America/Argentina/La_Rioja' => -10800,
        'America/Argentina/Mendoza' => -10800,
        'America/Argentina/Rio_Gallegos' => -10800,
        'America/Argentina/Salta' => -10800,
        'America/Argentina/San_Juan' => -10800,
        'America/Argentina/San_Luis' => -14400,
        'America/Argentina/Tucuman' => -10800,
        'America/Argentina/Ushuaia' => -10800,
        'America/Aruba' => -14400,
        'America/Asuncion' => -14400,
        'America/Atikokan' => -18000,
        'America/Atka' => -36000,
        'America/Bahia' => -10800,
        'America/Barbados' => -14400,
        'America/Belem' => -10800,
        'America/Belize' => -21600,
        'America/Blanc-Sablon' => -14400,
        'America/Boa_Vista' => -14400,
        'America/Bogota' => -18000,
        'America/Boise' => -25200,
        'America/Buenos_Aires' => -10800,
        'America/Cambridge_Bay' => -25200,
        'America/Campo_Grande' => -14400,
        'America/Cancun' => -21600,
        'America/Caracas' => -12600,
        'America/Catamarca' => -10800,
        'America/Cayenne' => -10800,
        'America/Cayman' => -18000,
        'America/Chicago' => -21600,
        'America/Chihuahua' => -25200,
        'America/Coral_Harbour' => -18000,
        'America/Cordoba' => -10800,
        'America/Costa_Rica' => -21600,
        'America/Cuiaba' => -14400,
        'America/Curacao' => -14400,
        'America/Danmarkshavn' => 0,
        'America/Dawson' => -28800,
        'America/Dawson_Creek' => -25200,
        'America/Denver' => -25200,
        'America/Detroit' => -18000,
        'America/Dominica' => -14400,
        'America/Edmonton' => -25200,
        'America/Eirunepe' => -14400,
        'America/El_Salvador' => -21600,
        'America/Ensenada' => -28800,
        'America/Fort_Wayne' => -18000,
        'America/Fortaleza' => -10800,
        'America/Glace_Bay' => -14400,
        'America/Godthab' => -10800,
        'America/Goose_Bay' => -14400,
        'America/Grand_Turk' => -18000,
        'America/Grenada' => -14400,
        'America/Guadeloupe' => -14400,
        'America/Guatemala' => -21600,
        'America/Guayaquil' => -18000,
        'America/Guyana' => -14400,
        'America/Halifax' => -14400,
        'America/Havana' => -18000,
        'America/Hermosillo' => -25200,
        'America/Indiana/Indianapolis' => -18000,
        'America/Indiana/Knox' => -21600,
        'America/Indiana/Marengo' => -18000,
        'America/Indiana/Petersburg' => -18000,
        'America/Indiana/Tell_City' => -21600,
        'America/Indiana/Vevay' => -18000,
        'America/Indiana/Vincennes' => -18000,
        'America/Indiana/Winamac' => -18000,
        'America/Indianapolis' => -18000,
        'America/Inuvik' => -25200,
        'America/Iqaluit' => -18000,
        'America/Jamaica' => -18000,
        'America/Jujuy' => -10800,
        'America/Juneau' => -32400,
        'America/Kentucky/Louisville' => -18000,
        'America/Kentucky/Monticello' => -18000,
        'America/Knox_IN' => -21600,
        'America/La_Paz' => -14400,
        'America/Lima' => -18000,
        'America/Los_Angeles' => -28800,
        'America/Louisville' => -18000,
        'America/Maceio' => -10800,
        'America/Managua' => -21600,
        'America/Manaus' => -14400,
        'America/Marigot' => -14400,
        'America/Martinique' => -14400,
        'America/Matamoros' => -21600,
        'America/Mazatlan' => -25200,
        'America/Mendoza' => -10800,
        'America/Menominee' => -21600,
        'America/Merida' => -21600,
        'America/Mexico_City' => -21600,
        'America/Miquelon' => -10800,
        'America/Moncton' => -14400,
        'America/Monterrey' => -21600,
        'America/Montevideo' => -10800,
        'America/Montreal' => -18000,
        'America/Montserrat' => -14400,
        'America/Nassau' => -18000,
        'America/New_York' => -18000,
        'America/Nipigon' => -18000,
        'America/Nome' => -32400,
        'America/Noronha' => -7200,
        'America/North_Dakota/Center' => -21600,
        'America/North_Dakota/New_Salem' => -21600,
        'America/Ojinaga' => -25200,
        'America/Panama' => -18000,
        'America/Pangnirtung' => -18000,
        'America/Paramaribo' => -10800,
        'America/Phoenix' => -25200,
        'America/Port-au-Prince' => -18000,
        'America/Port_of_Spain' => -14400,
        'America/Porto_Acre' => -14400,
        'America/Porto_Velho' => -14400,
        'America/Puerto_Rico' => -14400,
        'America/Rainy_River' => -21600,
        'America/Rankin_Inlet' => -21600,
        'America/Recife' => -10800,
        'America/Regina' => -21600,
        'America/Resolute' => -18000,
        'America/Rio_Branco' => -14400,
        'America/Rosario' => -10800,
        'America/Santa_Isabel' => -28800,
        'America/Santarem' => -10800,
        'America/Santiago' => -14400,
        'America/Santo_Domingo' => -14400,
        'America/Sao_Paulo' => -10800,
        'America/Scoresbysund' => -3600,
        'America/Shiprock' => -25200,
        'America/St_Barthelemy' => -14400,
        'America/St_Johns' => -9000,
        'America/St_Kitts' => -14400,
        'America/St_Lucia' => -14400,
        'America/St_Thomas' => -14400,
        'America/St_Vincent' => -14400,
        'America/Swift_Current' => -21600,
        'America/Tegucigalpa' => -21600,
        'America/Thule' => -14400,
        'America/Thunder_Bay' => -18000,
        'America/Tijuana' => -28800,
        'America/Toronto' => -18000,
        'America/Tortola' => -14400,
        'America/Vancouver' => -28800,
        'America/Virgin' => -14400,
        'America/Whitehorse' => -28800,
        'America/Winnipeg' => -21600,
        'America/Yakutat' => -32400,
        'America/Yellowknife' => -25200,
        'Antarctica/Casey' => 28800,
        'Antarctica/Davis' => 25200,
        'Antarctica/DumontDUrville' => 36000,
        'Antarctica/Mawson' => 21600,
        'Antarctica/McMurdo' => 43200,
        'Antarctica/Palmer' => -14400,
        'Antarctica/Rothera' => -10800,
        'Antarctica/South_Pole' => 43200,
        'Antarctica/Syowa' => 10800,
        'Antarctica/Vostok' => 0,
        'Arctic/Longyearbyen' => 3600,
        'Asia/Aden' => 10800,
        'Asia/Almaty' => 21600,
        'Asia/Amman' => 7200,
        'Asia/Anadyr' => 43200,
        'Asia/Aqtau' => 18000,
        'Asia/Aqtobe' => 18000,
        'Asia/Ashgabat' => 18000,
        'Asia/Ashkhabad' => 18000,
        'Asia/Baghdad' => 10800,
        'Asia/Bahrain' => 10800,
        'Asia/Baku' => 14400,
        'Asia/Bangkok' => 25200,
        'Asia/Beirut' => 7200,
        'Asia/Bishkek' => 21600,
        'Asia/Brunei' => 28800,
        'Asia/Calcutta' => 19800,
        'Asia/Choibalsan' => 28800,
        'Asia/Chongqing' => 28800,
        'Asia/Chungking' => 28800,
        'Asia/Colombo' => 19800,
        'Asia/Dacca' => 21600,
        'Asia/Damascus' => 7200,
        'Asia/Dhaka' => 21600,
        'Asia/Dili' => 32400,
        'Asia/Dubai' => 14400,
        'Asia/Dushanbe' => 18000,
        'Asia/Gaza' => 7200,
        'Asia/Harbin' => 28800,
        'Asia/Ho_Chi_Minh' => 25200,
        'Asia/Hong_Kong' => 28800,
        'Asia/Hovd' => 25200,
        'Asia/Irkutsk' => 32400,
        'Asia/Istanbul' => 7200,
        'Asia/Jakarta' => 25200,
        'Asia/Jayapura' => 32400,
        'Asia/Jerusalem' => 7200,
        'Asia/Kabul' => 16200,
        'Asia/Kamchatka' => 43200,
        'Asia/Karachi' => 21600,
        'Asia/Kashgar' => 28800,
        'Asia/Kathmandu' => 20700,
        'Asia/Katmandu' => 20700,
        'Asia/Kolkata' => 19800,
        'Asia/Krasnoyarsk' => 28800,
        'Asia/Kuala_Lumpur' => 28800,
        'Asia/Kuching' => 28800,
        'Asia/Kuwait' => 10800,
        'Asia/Macao' => 28800,
        'Asia/Macau' => 28800,
        'Asia/Magadan' => 43200,
        'Asia/Makassar' => 28800,
        'Asia/Manila' => 28800,
        'Asia/Muscat' => 14400,
        'Asia/Nicosia' => 7200,
        'Asia/Novokuznetsk' => 25200,
        'Asia/Novosibirsk' => 25200,
        'Asia/Omsk' => 25200,
        'Asia/Oral' => 18000,
        'Asia/Phnom_Penh' => 25200,
        'Asia/Pontianak' => 25200,
        'Asia/Pyongyang' => 32400,
        'Asia/Qatar' => 10800,
        'Asia/Qyzylorda' => 21600,
        'Asia/Rangoon' => 23400,
        'Asia/Riyadh' => 10800,
        'Asia/Saigon' => 25200,
        'Asia/Sakhalin' => 39600,
        'Asia/Samarkand' => 18000,
        'Asia/Seoul' => 32400,
        'Asia/Shanghai' => 28800,
        'Asia/Singapore' => 28800,
        'Asia/Taipei' => 28800,
        'Asia/Tashkent' => 18000,
        'Asia/Tbilisi' => 14400,
        'Asia/Tehran' => 12600,
        'Asia/Tel_Aviv' => 7200,
        'Asia/Thimbu' => 21600,
        'Asia/Thimphu' => 21600,
        'Asia/Tokyo' => 32400,
        'Asia/Ujung_Pandang' => 28800,
        'Asia/Ulaanbaatar' => 28800,
        'Asia/Ulan_Bator' => 28800,
        'Asia/Urumqi' => 28800,
        'Asia/Vientiane' => 25200,
        'Asia/Vladivostok' => 39600,
        'Asia/Yakutsk' => 36000,
        'Asia/Yekaterinburg' => 21600,
        'Asia/Yerevan' => 14400,
        'Atlantic/Azores' => -3600,
        'Atlantic/Bermuda' => -14400,
        'Atlantic/Canary' => 0,
        'Atlantic/Cape_Verde' => -3600,
        'Atlantic/Faeroe' => 0,
        'Atlantic/Faroe' => 0,
        'Atlantic/Jan_Mayen' => 3600,
        'Atlantic/Madeira' => 0,
        'Atlantic/Reykjavik' => 0,
        'Atlantic/South_Georgia' => -7200,
        'Atlantic/St_Helena' => 0,
        'Atlantic/Stanley' => -14400,
        'Australia/ACT' => 36000,
        'Australia/Adelaide' => 34200,
        'Australia/Brisbane' => 36000,
        'Australia/Broken_Hill' => 34200,
        'Australia/Canberra' => 36000,
        'Australia/Currie' => 36000,
        'Australia/Darwin' => 34200,
        'Australia/Eucla' => 31500,
        'Australia/Hobart' => 36000,
        'Australia/LHI' => 37800,
        'Australia/Lindeman' => 36000,
        'Australia/Lord_Howe' => 37800,
        'Australia/Melbourne' => 36000,
        'Australia/NSW' => 36000,
        'Australia/North' => 34200,
        'Australia/Perth' => 28800,
        'Australia/Queensland' => 36000,
        'Australia/South' => 34200,
        'Australia/Sydney' => 36000,
        'Australia/Tasmania' => 36000,
        'Australia/Victoria' => 36000,
        'Australia/West' => 28800,
        'Australia/Yancowinna' => 34200,
        'Brazil/Acre' => -14400,
        'Brazil/DeNoronha' => -7200,
        'Brazil/East' => -10800,
        'Brazil/West' => -14400,
        'Canada/Atlantic' => -14400,
        'Canada/Central' => -21600,
        'Canada/East-Saskatchewan' => -21600,
        'Canada/Eastern' => -18000,
        'Canada/Mountain' => -25200,
        'Canada/Newfoundland' => -9000,
        'Canada/Pacific' => -28800,
        'Canada/Saskatchewan' => -21600,
        'Canada/Yukon' => -28800,
        'Chile/Continental' => -14400,
        'Chile/EasterIsland' => -21600,
        'Cuba' => -18000,
        'Egypt' => 7200,
        'Eire' => 0,
        'Etc/GMT' => 0,
        'Etc/GMT+0' => 0,
        'Etc/UCT' => 0,
        'Etc/UTC' => 0,
        'Etc/Universal' => 0,
        'Etc/Zulu' => 0,
        'Europe/Amsterdam' => 3600,
        'Europe/Andorra' => 3600,
        'Europe/Athens' => 7200,
        'Europe/Belfast' => 0,
        'Europe/Belgrade' => 3600,
        'Europe/Berlin' => 3600,
        'Europe/Bratislava' => 3600,
        'Europe/Brussels' => 3600,
        'Europe/Bucharest' => 7200,
        'Europe/Budapest' => 3600,
        'Europe/Chisinau' => 7200,
        'Europe/Copenhagen' => 3600,
        'Europe/Dublin' => 0,
        'Europe/Gibraltar' => 3600,
        'Europe/Guernsey' => 0,
        'Europe/Helsinki' => 7200,
        'Europe/Isle_of_Man' => 0,
        'Europe/Istanbul' => 7200,
        'Europe/Jersey' => 0,
        'Europe/Kaliningrad' => 10800,
        'Europe/Kiev' => 7200,
        'Europe/Lisbon' => 0,
        'Europe/Ljubljana' => 3600,
        'Europe/London' => 0,
        'Europe/Luxembourg' => 3600,
        'Europe/Madrid' => 3600,
        'Europe/Malta' => 3600,
        'Europe/Mariehamn' => 7200,
        'Europe/Minsk' => 7200,
        'Europe/Monaco' => 3600,
        'Europe/Moscow' => 14400,
        'Europe/Nicosia' => 7200,
        'Europe/Oslo' => 3600,
        'Europe/Paris' => 3600,
        'Europe/Podgorica' => 3600,
        'Europe/Prague' => 3600,
        'Europe/Riga' => 7200,
        'Europe/Rome' => 3600,
        'Europe/Samara' => 14400,
        'Europe/San_Marino' => 3600,
        'Europe/Sarajevo' => 3600,
        'Europe/Simferopol' => 7200,
        'Europe/Skopje' => 3600,
        'Europe/Sofia' => 7200,
        'Europe/Stockholm' => 3600,
        'Europe/Tallinn' => 7200,
        'Europe/Tirane' => 3600,
        'Europe/Tiraspol' => 7200,
        'Europe/Uzhgorod' => 7200,
        'Europe/Vaduz' => 3600,
        'Europe/Vatican' => 3600,
        'Europe/Vienna' => 3600,
        'Europe/Vilnius' => 7200,
        'Europe/Volgograd' => 14400,
        'Europe/Warsaw' => 3600,
        'Europe/Zagreb' => 3600,
        'Europe/Zaporozhye' => 7200,
        'Europe/Zurich' => 3600,
        'GB' => 0,
        'GB-Eire' => 0,
        'GMT' => 0,
        'GMT+0' => 0,
        'GMT-0' => 0,
        'GMT0' => 0,
        'Greenwich' => 0,
        'Hongkong' => 28800,
        'Iceland' => 0,
        'Indian/Antananarivo' => 10800,
        'Indian/Chagos' => 21600,
        'Indian/Christmas' => 25200,
        'Indian/Cocos' => 23400,
        'Indian/Comoro' => 10800,
        'Indian/Kerguelen' => 18000,
        'Indian/Mahe' => 14400,
        'Indian/Maldives' => 18000,
        'Indian/Mauritius' => 14400,
        'Indian/Mayotte' => 10800,
        'Indian/Reunion' => 14400,
        'Iran' => 12600,
        'Israel' => 7200,
        'JST-9' => 32400,
        'Jamaica' => -18000,
        'Japan' => 32400,
        'Kwajalein' => 43200,
        'Libya' => 7200,
        'Mexico/BajaNorte' => -28800,
        'Mexico/BajaSur' => -25200,
        'Mexico/General' => -21600,
        'NZ' => 43200,
        'NZ-CHAT' => 45900,
        'Navajo' => -25200,
        'PRC' => 28800,
        'Pacific/Apia' => -39600,
        'Pacific/Auckland' => 43200,
        'Pacific/Chatham' => 45900,
        'Pacific/Easter' => -21600,
        'Pacific/Efate' => 39600,
        'Pacific/Enderbury' => 46800,
        'Pacific/Fakaofo' => -36000,
        'Pacific/Fiji' => 43200,
        'Pacific/Funafuti' => 43200,
        'Pacific/Galapagos' => -21600,
        'Pacific/Gambier' => -32400,
        'Pacific/Guadalcanal' => 39600,
        'Pacific/Guam' => 36000,
        'Pacific/Honolulu' => -36000,
        'Pacific/Johnston' => -36000,
        'Pacific/Kiritimati' => 50400,
        'Pacific/Kosrae' => 39600,
        'Pacific/Kwajalein' => 43200,
        'Pacific/Majuro' => 43200,
        'Pacific/Marquesas' => -30600,
        'Pacific/Midway' => -39600,
        'Pacific/Nauru' => 43200,
        'Pacific/Niue' => -39600,
        'Pacific/Norfolk' => 41400,
        'Pacific/Noumea' => 39600,
        'Pacific/Pago_Pago' => -39600,
        'Pacific/Palau' => 32400,
        'Pacific/Pitcairn' => -28800,
        'Pacific/Ponape' => 39600,
        'Pacific/Port_Moresby' => 36000,
        'Pacific/Rarotonga' => -36000,
        'Pacific/Saipan' => 36000,
        'Pacific/Samoa' => -39600,
        'Pacific/Tahiti' => -36000,
        'Pacific/Tarawa' => 43200,
        'Pacific/Tongatapu' => 46800,
        'Pacific/Truk' => 36000,
        'Pacific/Wake' => 43200,
        'Pacific/Wallis' => 43200,
        'Pacific/Yap' => 36000,
        'Poland' => 3600,
        'Portugal' => 0,
        'ROC' => 28800,
        'ROK' => 32400,
        'Singapore' => 28800,
        'Turkey' => 7200,
        'UCT' => 0,
        'US/Alaska' => -32400,
        'US/Aleutian' => -36000,
        'US/Arizona' => -25200,
        'US/Central' => -21600,
        'US/East-Indiana' => -18000,
        'US/Eastern' => -18000,
        'US/Hawaii' => -36000,
        'US/Indiana-Starke' => -21600,
        'US/Michigan' => -18000,
        'US/Mountain' => -25200,
        'US/Pacific' => -28800,
        'US/Pacific-New' => -28800,
        'US/Samoa' => -39600,
        'Universal' => 0,
        'W-SU' => 14400,
        'Zulu' => 0,
        'GMT' => 0,
        'UTC' => 0,
    );
    
    sub get_offset {
        my $name = shift;
        my $offset = $timezone_tbl{$name};
        if (defined $offset) {
            return $offset;
        }
        if ($name =~ /^([\-\+])?(\d\d?)(\d\d)?(\d\d)?$/) {
            return
            ($1 && $1 eq '-' ? '-' : ''). ($2 * 3600 + ($3||0) * 60 + ($4||0));
        }
        die 'Invalid Timezone';
    }

1;

__END__

=head1 NAME

Text::PSTemplate::DateTime - Pure Perl implementation of DateTime

=head1 SYNOPSIS
    
=head1 DESCRIPTION

This is a Pure Perl implementation of DateTime. Very limited functionality is
available.

=head1 Method

=head2 DateTime->new

=head2 DateTime->parse

=head2 DateTime->from_epoch

=head2 $instance->strftime

=head2 $instance->set_month_asset

=head2 $instance->set_weekday_asset

=head2 $instance->add

=head2 $instance->epoch

=head2 $instance->ymd

=head2 $instance->iso8601

=head2 $instance->year

=head2 $instance->month

=head2 $instance->day

=head2 $instance->hour

=head2 $instance->minute

=head2 $instance->second

=head2 $instance->day_of_week

=head2 $instance->day_of_year

=head2 $instance->month_name

=head2 $instance->month_abbr

=head2 $instance->day_name

=head2 $instance->day_abbr

=head2 $instance->year_abbr

=head2 $instance->am_or_pm

=head2 $instance->hour_12_0

=head2 $instance->is_leap_year

=head2 $instance->compare

=head2 $instance->date

=head2 $instance->datetime

=head2 $instance->day_0

=head2 $instance->day_of_month

=head2 $instance->day_of_month_0

=head2 $instance->day_of_week_0

=head2 $instance->day_of_year_0

=head2 $instance->dmy

=head2 $instance->hms

=head2 $instance->hour_1

=head2 $instance->hour_12

=head2 $instance->last_day_of_month

=head2 $instance->mday

=head2 $instance->mday_0

=head2 $instance->mdy

=head2 $instance->min

=head2 $instance->month_0

=head2 $instance->now

=head2 $instance->offset

=head2 $instance->quarter

=head2 $instance->sec

=head2 $instance->set

=head2 $instance->set_day

=head2 $instance->set_hour

=head2 $instance->set_minute

=head2 $instance->set_month

=head2 $instance->set_second

=head2 $instance->set_time_zone

=head2 $instance->set_year

=head2 $instance->time

=head2 $instance->wday

=head2 $instance->wday_0

=head2 $instance->today

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
