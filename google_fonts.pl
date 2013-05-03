#!/usr/bin/env perl

use 5.014;

# ABSTRACT: Google Web Fonts from your terminal

# VERSION

# core modules (in 5.14)
use HTTP::Tiny;
use Storable;
use File::stat;
use Getopt::Long;
use Time::Piece;
use JSON::PP;
use Pod::Usage;

# defaults
my $gfonts_api_key = $ENV{GOOGLE_FONTS_API_KEY}; 
my $cache = "$ENV{HOME}/.gfonts.cache";
my $name_cache = "$ENV{HOME}/.gfonts.names";
my $font_dir = "$ENV{HOME}/Library/Fonts";
my $one_day = 60 * 60 * 24;

# option variables
my @output_filter = ();
my $download_files = 0;
my @variant_filter = (qw(regular));
my $output_css = 0;
my $verbose = 0;
my $scan = 0;

GetOptions (
    "output=s"  => \@output_filter,
    "download"  => \$download_files,
    "variant=s" => \@variant_filter,
    "css"       => \$output_css,
    "verbose"   => \$verbose,
    "scan"      => \$scan,
    "help|h|?"  => pod2usage( -verbose => 1 ),
);

if ( not $gfonts_api_key ) {
    die "A Google Fonts API key is required as the environment variable GOOGLE_FONTS_API_KEY.\n";
}

sub fetch_font_list {
    my $base_url = 'https://www.googleapis.com/webfonts/v1/webfonts?sort=popularity';

    my $response = HTTP::Tiny->new->get($base_url . "&key=$gfonts_api_key");

    if ( $response->{success} ) {
        return JSON::PP->new->decode($response->{content});
    }

    die "Couldn't retrieve font list from $base_url: $response->{status} $response->{reason}: $response->{content}\n";
}

sub css_family_name {
    my $name = $_[0]->{family} =~ s/ /+/gr;

    my @weights = grep { $_ ne "regular" } @variant_filter;

    return $name . (scalar @weights ? ":" . (join ",", @weights) : "");
}
    
sub css_output {
    my $url = q|<link rel="stylesheet" type="text/css" href="http://fonts.googleapis.com/css?family="|;

    $url . (join "|", map {; css_family_name($_) } @_) . q|">|;
}

sub output {
    my $s = $_[0]->{family};

    if ( $output_filter[0] eq "all" ) {
        @output_filter = (qw(
            version
            lastModified
            variants
            subsets
            files
            )
        );
    }

    for my $k ( @output_filter ) {
        my $r = ref $_[0]->{$k};
        if ( $r eq "HASH" ) {
            $s .= "\n  $k:";
            $s .= join "", map { "\n    $_:\n\t    $_[0]->{$k}->{$_}" } keys %{ $_[0]->{$k} };
        }
        elsif ( $r eq "ARRAY" ) {
            $s .= "\n  $k: ";
            $s .= join ", ", @{ $_[0]->{$k} };
        }
        else {
            $s .= "\n  $k: $_[0]->{$k}";
        }
    }

    $s .= "\n";
}

sub download_font_files {
    foreach my $variant ( @variant_filter ) {
        my $url = $_[0]->{files}->{$variant};
        unless ( defined $url ) {
            warn "Could not download $_[0]->{family} because type '$variant' is not an available download.\n";
            next;
        }
        my $fname = "$_[0]->{family}-$variant.ttf";

        my $response = HTTP::Tiny->new->get($url);

        if ( $response->{success} ) {
            say "Downloading $fname..." if $verbose;
            open my $fh, ">", $fname or die "Couldn't open $fname for writing: $!\n";
            binmode $fh;
            print $fh $response->{content};
            close $fh;
            say "\tdone." if $verbose;
        }
        else {
            die "Couldn't retrieve font from $url: $response->{status} $response->{reason}\n";
        }
    }
}

sub build_name_index {
    my $i = 0;
    my %h = map {; $_->{family} => $i++ } @{ $_[0]->{items} };
    return \%h;
}

sub cache {
    store $_[0], "$_[1]" or die "Couldn't store cache: $_[1]: $!\n";
}

sub load_cache {
    retrieve("$_[0]") or die "Couldn't load cache: $_[0]: $!\n"; 
}

sub convert_to_epoch {
    my $t = Time::Piece->strptime(shift, "%Y-%m-%d");
    $t->epoch;
}

my $gfonts;
my $name_index;
my $st = stat($cache);

if ( ! -e $st || time > ( $st->atime + $one_day ) ) {
    $gfonts = fetch_font_list();
    cache($gfonts, $cache);
    $name_index = build_name_index($gfonts);
    cache($name_index, $name_cache);
}
else {
    # cache is newer than one day
    $gfonts = load_cache($cache);
    $name_index = load_cache($name_cache);
}

die "usage: $0 regex1 [regex2 ... regexN]\n" if @ARGV < 1 && not $scan;

if ( ! $scan ) {
    my @fonts;
    foreach my $r ( @ARGV ) {
        my $re = qr/$r/;

        # build a list of fonts matching provided regex(es)
        push @fonts, map { $gfonts->{items}->[$name_index->{$_}] } 
                                    grep { /$re/ } keys %{ $name_index };
    }

    say map {; output($_) } @fonts;

    if ( $output_css ) {
        say "===";
        say css_output(@fonts);
    }

    if ( $download_files ) {
        map {; download_font_files($_) } @fonts;
    }
}
else {
    my @updates;
    push @ARGV, $font_dir;
    for my $dirname ( @ARGV ) { 
        opendir my $dh, $dirname or die "Couldn't opendir $dirname: $!\n";
        while ( my $f = readdir $dh ) {
            next unless $f =~ /\.ttf$/;
            next unless -f "$font_dir/$f";
            my $st = stat("$font_dir/$f");

            $f =~ s/(.+?)(-.+)?\.ttf$/$1/;

            @updates = grep { convert_to_epoch($_->{lastModified}) > $st->atime }
                map { $gfonts->{items}->[$name_index->{$_}] }
                grep { /$f/ } keys %{ $name_index };

        }
        closedir $dh;

        if ( scalar @updates ) {
            say ( ( scalar @updates == 1 ) ? "This font is" : "These fonts are" 
                                            . " newer than what's in $dirname:");
            say map {; output($_) } @updates;
        }
        else {
            say "No updates found in $dirname.";
        }
    }
}

exit 0;
__END__

=head1 SYNOPSIS

    google_fonts.pl --scan /font/dir1 /font/dir2

    or

    google_fonts.pl [options] regex1 regex2 ... regexN

=head1 OPTIONS

=over

=item * output

This option modifies what output is shown. By default, the only thing shown is the
font family name. The option may be repeated multiple times. Other available fields are:

=over 

=item * files

Show the download urls by weight/variant.

=item * variants

Show the available weights/variant type faces.

=item * version

Show the current font version.

=item * lastModified

Show the last date the font was modified.

=item * subsets

Show the available character sets 

=item * all

Show everything above.

=back

=item * variant

Filter downloads or css output by adding variants. By default the only variant is
'regular' which is not always available for every font family. This option
may be given multiple times.

=item * verbose

Show verbose output when downloading font(s).

=item * download

Download matching fonts/variants into the current working directory.

=item * css

Output HTML stylesheet links to STDOUT for matching font families and 
variants.

=item * scan

Scan (optional given) font folders for web font names and compare the
on disk time to the lastModified attribute. If the lastModified attribute
is newer, output a message. By default this scans ~/Library/Fonts.

=back

=head1 DESCRIPTION

This program requires a Google API key for Web Fonts. See 
L<this page|https://developers.google.com/fonts/docs/developer_api>
for more details.  Once you have an API key, you must export it
into your shell environment.

    $ export GOOGLE_FONTS_API_KEY='sekrit'

The program uses the key to get a JSON list of available fonts
and font metadata, parses it into a Perl data structure and then
caches the data to disk. If the cache on disk is older than 24 hours, 
it will get new data, overwriting the old files.

=head2 MINIMUM PERL VERSION

This program B<requires> Perl 5.14 or later. It makes use several
features and modules added to the perl core as of 5.14.

=head2 IMPLEMENTATION QUIRKS

This implementation focuses fairly exclusively on Mac OS X, but
I would welcome patches to generalize this code to Linux and/or Windows.

=head1 EXAMPLES

    google_fonts.pl "^Open Sans"

Show all font names that start with the pattern 'Open Sans'

    google_fonts.pl --output all "^Open Sans$"

Find the font that exactly matches 'Open Sans' and
display all of its metadata.

    google_fonts.pl "^A"

Show all font names that begin with the letter 'A'

    google_fonts.pl --download "^A"

Show all the font names that being with 'A' and download them
into the current directory.

=cut
