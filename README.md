# NAME

gfonts - Google Web Fonts from your terminal

# VERSION

version 0.01

# SYNOPSIS

    gfonts --scan /font/dir1 /font/dir2

    or

    gfonts [options] --popular 15

    or

    gfonts [options] regex1 regex2 ... regexN

# DESCRIPTION

This program requires a Google API key for Web Fonts. See 
[this page](https://developers.google.com/fonts/docs/developer\_api)
for more details.  Once you have an API key, you must export it
into your shell environment.

    $ export GOOGLE_FONTS_API_KEY='sekrit'

The program uses the key to get a JSON list of available fonts
and font metadata, parses it into a Perl data structure and then
caches the data to disk. If the cache on disk is older than 24 hours, 
it will get new data, overwriting the old files.

## MINIMUM PERL VERSION

This program __requires__ Perl 5.14 or later. It makes use several
features and modules added to the perl core as of 5.14.

## IMPLEMENTATION QUIRKS

This implementation focuses fairly exclusively on Mac OS X, but
I would welcome patches to generalize this code to Linux and/or Windows.

# OPTIONS

- output

    This option modifies what output is shown. By default, the only thing shown is the
    font family name. The option may be repeated multiple times. Other available fields are:

    - files

        Show the download urls by weight/variant.

    - variants

        Show the available weights/variant type faces.

    - version

        Show the current font version.

    - lastModified

        Show the last date the font was modified.

    - subsets

        Show the available character sets 

    - all

        Show everything above.

- variant

    Filter downloads or css output by adding variants. By default the only variant is
    'regular' which is not always available for every font family. This option
    may be given multiple times.

- verbose

    Show verbose output when downloading font(s).

- download

    Download matching fonts/variants into the current working directory.

- css

    Output HTML stylesheet links to STDOUT for matching font families and 
    variants.

- scan

    Scan (optional given) font folders for web font names and compare the
    on disk time to the lastModified attribute. If the lastModified attribute
    is newer, output a message. By default this scans ~/Library/Fonts.

- popular 

    Instead of scanning for a specific regex, display the N (default is 10) most 
    popular fonts.

# EXAMPLES

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

# AUTHOR

Mark Allen <mrallen1@yahoo.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Mark Allen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
