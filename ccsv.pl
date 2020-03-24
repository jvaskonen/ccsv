#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars ) ;

use Term::ReadKey;
use Getopt::Long;
use utf8;
use Encode;
use Encode::Locale;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
binmode STDIN, ':encoding(console_in)';
use open IN => ':encoding(console_in)';

# local is needed for counting to work properly through regex backtracking...
# so we need a global variable to localize
our $CNT;

my %options = parse_options();
parse_and_print_csv();

sub usage {
    print << "__USAGE__";
$0 [<OPTIONS>] <FILE 1> [<FILE 2> ... ]
echo <CSV DATA> | $0 [options] --

Options:
    --border -b           Draw a border around the table
                          Default: false
    --continue            If an error in encountered parsing a csv file,
                          continue with the next file rather than terminating.
                          Default: false
    --header -h           Treat the first line of each file as a header row
                          Default: False
    --csep -s             String used to separate columns
                          Default: ' | '
    --hsep                String to be repeated and used as a separator between
                          the header and data rows.
                          Default: Equal to vsep if defined, otherwise '-'
    --hsepx               String to be used between columns in the header
                          separator row.
                          Default: Equal to sepx
    --margin -m           Set the left and right column marigns
    --margin-left         Set the left column margin
                          Default: 1
    --margin-right        Set the right column margin
                          Default: 1
    --max-line-length -o  Abort parsing a csv if the line length exceeds the
                          specified value.
                          Default: 1,000,000
    --palette -p          Format is <item1>=<colour1>_<format>[,<item2>=...]
                          There is an *-fg and *-bg for each of the following:
                              border    column-separator     content-border
                              content-column-separator-bg    content-even-row
                              content-odd-row   file-label   header
                              header-border     header-column-separator
                              header-separator  header-separator-border
                              row-separator
                          border-* and column-separator-* are shortcuts to
                          setting all items of that type in one go.

                          Valid colours are:
                              * integers between 0 and 255,
                              * xterm256 colour names as defined at:
                                https://github.com/jonasjacek/colors
                              * semicolon separated RGB values, i.e. 200;42;37
                          Valid formats characters are: b (bold), i (italic),
                          l (blink), s (strikethrough) and u (underline). Not
                          all formats are implemented by all terminals.

                          Example: -p'header-fg=blue_b' sets the header text to
                          be bold blue
    --prefetch -t         The number of rows to fetch before starting to dispay
                          output. Column widths will be allocated based on the
                          data in those rows. If the column count subsequently
                          changes, this number of rows will again be fetched
                          to recalculate column widths.
                          Default: 100
    -print-file-names -f  Print a header row before each file with the filename
                          Default: True if more than one file specified
    --quiet -q            Supress error messages
                          Default: false
    --rsep -v             String to be repeated and used as a separator between
                          rows.
                          Default: row separation off
    --sepx -x             String used between columns on a separator row
                          Default: '-+-'
    --width -w            Width to wrap the output to
                          Default: terminal width
__USAGE__
    exit 0;
}

sub parse_options {
    my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
    my %opt = ( 'colours' => {} );
    my %defs = ( 'border'                 => 0,
                 'border-ul'              => '',
                 'border-top'             => '',
                 'border-top-x'           => '',
                 'border-ur'              => '',
                 'border-right'           => '',
                 'border-right-hx'        => '',
                 'border-right-sx'        => '',
                 'border-lr'              => '',
                 'border-bottom'          => '',
                 'border-bottom-x'        => '',
                 'border-ll'              => '',
                 'border-left'            => '',
                 'border-left-hx'         => '',
                 'border-left-sx'         => '',
                 'colours'                => {},
                 'column-separator'       => '|',
                 'continue-on-error'      => 0,
                 'draw-header-separator'  => 0,
                 'draw-row-separator'     => 0,
                 'header'                 => 0,
                 'header-separator-x'     => '+',
                 'margin-left'            => 1,
                 'margin-right'           => 1,
                 'max-line-length'        => 1_000_000,
                 'palette'                => '',
                 'prefetch-lines'         => 100,
                 'quiet'                  => 0,
                 'row-separator'          => '-',
                 'separator-x'            => '+',
                 'header-separator'       => '-',
                 'width'                  => $wchar,
              );
    my %border_defs = ( 'border-ul'              => '┌',
                        'border-top'             => '─',
                        'border-top-x'           => '┬',
                        'border-ur'              => '┒',
                        'border-right'           => '┃',
                        'border-right-hx'        => '┫',
                        'border-right-sx'        => '┨',
                        'border-lr'              => '┛',
                        'border-bottom'          => '━',
                        'border-bottom-x'        => '┷',
                        'border-ll'              => '┕',
                        'border-left'            => '│',
                        'border-left-hx'         => '┝',
                        'border-left-sx'         => '├',
                        'column-separator'       => '│',
                        'header-separator-x'     => '┿',
                        'header-separator'       => '━',
                        'row-separator'          => '─',
                        'separator-x'            => '┼',
                      );
    my %color_defs = ( 'border-bg'                   => 300,
                       'border-fg'                   => 300,
                       'column-separator-bg'         => 300,
                       'column-separator-fg'         => 300,
                       'content-border-bg'           => 0,
                       'content-border-fg'           => 7,
                       'content-column-separator-bg' => 0,
                       'content-column-separator-fg' => 7,
                       'content-even-row-bg'         => 0,
                       'content-even-row-fg'         => 6,
                       'content-odd-row-bg'          => 0,
                       'content-odd-row-fg'          => 7,
                       'file-label-bg'               => 4,
                       'file-label-fg'               => 15,
                       'header-bg'                   => 7,
                       'header-fg'                   => 0,
                       'header-border-bg'            => 0,
                       'header-border-fg'            => 7,
                       'header-column-separator-bg'  => 7,
                       'header-column-separator-fg'  => 0,
                       'header-separator-bg'         => 0,
                       'header-separator-fg'         => 7,
                       'header-separator-border-bg'  => 0,
                       'header-separator-border-fg'  => 7,
                       'row-separator-bg'            => 0,
                       'row-separator-fg'            => 7,
                     );
    my %fancy_defs = ( %color_defs,
                       'content-even-row-bg'         => 236,
                       'content-even-row-fg'         => 7,
                       'header-bg'                   => 70,
                       'header-fg'                   => '16_b',
                       'file-label-fg'               => '255_b',
                       'header-column-separator-bg'  => 0,
                       'header-column-separator-fg'  => 7,
                     );

    my @string_opts = ( qw/column-separator      header-separator-x
                           header-separator      left-justify-columns
                           palette               separator-x
                           right-justify-columns row-separator
                          /
                      );

    Getopt::Long::Configure ("bundling");
    GetOptions( 'border|b'            => \$opt{'border'},
                'colour|color|c!'     => \$opt{'use-colour'},
                'csep|s=s'            => \$opt{'column-separator'},
                'continue|t'          => \$opt{'continue-on-error'},
                'grid|g!'             => \$opt{'draw-row-separator' },
                'header|h!'           => \$opt{'header'},
                'hsepx=s'             => \$opt{'header-separator-x'},
                'hsep=s'              => \$opt{'header-separator'},
                'left|l=s'            => \$opt{'left-justify-columns'},
                'margin|m=i'          => \$opt{'margin'},
                'margin-left=i'       => \$opt{'margin-left'},
                'margin-right=i'      => \$opt{'margin-right'},
                'max-line-length|o=i' => \$opt{'max-line-length'},
                'print-file-names|f!' => \$opt{'print-file-names'},
                'palette|p=s'         => \$opt{'palette'},
                'prefetch|t=i'        => \$opt{'prefetch-lines'},
                'rsep|v=s'            => \$opt{'row-separator'},
                'sepx|x=s'            => \$opt{'separator-x'},
                'quiet|q'             => \$opt{'quiet'},
                'right|r=s'           => \$opt{'right-justify-columns'},
                'width|w=i'           => \$opt{'width'},
              ) || usage();

    # Getopts doesn't play nice with fancy locales so we need to cycle through
    # the string options and encode them in whatever the console encoding is
    foreach my $string_option ( @string_opts ) {
        if ( defined $opt{$string_option} ) {
            $opt{$string_option} = decode(locale => $opt{$string_option} );
        }
    }

    # Deal with colours
    $opt{'colours'}{'colour-reset'}
        = ( !defined $opt{'use-colour'} || $opt{'use-colour'} )
          ? "\x1b\x5b0m"
          : '';

    my %default_palette = $opt{'border'} ? %fancy_defs : %color_defs;
    # Parse and apply user settings. Ignore if we have colour turned off.
    # No defaults applied yet, so use-colour is only defined if it showed up in
    # the options list.
    if ( defined $opt{'palette'}
         && ( !defined $opt{'use-colour'}
              || $opt{'use-colour'}
            )
       ) {
        # Palette format is Thing_to_color1=Color1,Thing_to_color2=Color2
        # do an initial sanity check
        unless ( $opt{'palette'} =~ m/\A[\w\d-]+=[\w\d;]+
                                      (,[\w\d-]+=[\w\d;]+)*\z
                                     /mxs
               ) {
            print STDERR "Could not parse --palette option\n\n";
            usage();
        }

        # Hashify the palette option
        my %attempted_palette = map { split '=' }
                                      split ',', $opt{'palette'};

        # Border-* is shorthand for header-border-* + content-border-*
        # Same goes for column-separator-*
        for my $alias_stem ( qw/column-separator border/ ) {
            foreach my $fgbg ( qw/fg bg/ ) {
                my $alias_opt = "$alias_stem-$fgbg";
                if ( defined $attempted_palette{$alias_opt} ) {
                    my $setting = delete $attempted_palette{$alias_opt};
                    foreach my $mapto ( qw/header content header-separator/ ) {
                        # don't try to set non-existent options
                        my $realname = "$mapto-$alias_opt";
                        if ( defined $default_palette{$realname} ) {
                            print "$realname => $setting\n";
                            $attempted_palette{"$realname"} = $setting;
                        }
                    }
                }
            }
        }

        # Cycle through the stuff we're trying to set colours for
        foreach my $col_prop ( keys %attempted_palette ) {
            # See if we're setting a known colour property
            if ( !defined $default_palette{$col_prop} ) {
                print STDERR "'$col_prop' is not something I can colour\n\n";
                usage();
            }

            # We need to know if we're setting a background or foreground
            # colour to generate the right vt100 magic
            my $is_bg = $col_prop =~ m/-bg$/mxs;
            my $vt100_colour = make_colour( $attempted_palette{$col_prop},
                                            $is_bg
                                          );
            # make_colour returns negative numbers on error
            if ( $vt100_colour eq '-1' ) {
                my $n = $attempted_palette{$col_prop};
                print STDERR "$n is outside of valid range 0-255)\n\n";
                usage();
            }
            elsif ( $vt100_colour eq '-2' ) {
                my $n = $attempted_palette{$col_prop};
                print STDERR "'$n' is not a valid xterm256 colour name\n\n";
                usage();
            }
            elsif ( $vt100_colour eq '-3' ) {
                my $n = $attempted_palette{$col_prop};
                print STDERR "'$n' contains an invalid format character. "
                             . "Valid characters are: b i l s u\n\n";
                usage();
            }
            $opt{'colours'}{$col_prop} = $vt100_colour;
        }
    }
    # Apply defaults and assemble final palette
    foreach my $col_prop ( keys %default_palette ) {
        my ( $thing_to_color, $fg_or_bg )
            = $col_prop =~ m/\A(.*?)-((?:f|b)g)\z/mxs;

        # If we're not in colour mode, then the appropriate vt100 code for this
        # thing is an empty string and we're done
        unless( !defined $opt{'use-colour'}
                || $opt{'use-colour'}
              ) {
            $opt{'colours'}{$thing_to_color} = '';
            next;
        }

        # If we have a user specified value, use that. Otherwise roll one using
        # the defaults
        my $is_bg = ( $fg_or_bg eq 'bg' ) ? 1 : 0;
        my $vt = ( defined $opt{'colours'}{$col_prop} )
                 ? $opt{'colours'}{$col_prop}
                 : make_colour( $default_palette{$col_prop}, $is_bg );
        $opt{'colours'}{$thing_to_color} .= $vt;
    }

    # If we're using borders, fancy up the separators
    if ( $opt{'border'} ) {
        %defs = ( %defs,
                  %border_defs
                );
    }

    # Set margin-left/right if they are unset and margin is
    if ( defined $opt{'margin'} ) {
        for my $side ( qw/left right/ ) {
            $opt{"margin-$side"} = $opt{'margin'}
                if ( !defined $opt{"margin-$side"} );
        }
    }

    # Print file names by default if more than one file has been specified
    if ( !defined $opt{'print-file-names'} ) {
        $opt{'print-file-names'} = ( scalar @ARGV > 1 ) ? 1 : 0;
    }

    # setting the vertical separator sets it for both the row content and the
    # header unless the header separator is set explicitly.
    if ( !defined $opt{'header-separator'}
         && defined $opt{'row-separator'}
       ) {
        $opt{'header-separator'} = $opt{'row-separator'};
    }

    # setting the separator intersection sets it for both the row content and
    # the header unless the header separator intersection is set explicitly.
    if ( !defined $opt{'header-separator-x'}
         && defined $opt{'separator-x'}
       ) {
        $opt{'header-separator-x'} = $opt{'separator-x'};
    }

    # Draw a header separator row if we: have grid mode on, are not using
    # colour, or we've explicitly been given a string to use for the separator
    if ( $opt{'draw-row-separator'}
         || ( defined $opt{'use-colour'} && !$opt{'use-colour'} )
         || defined $opt{'header-separator'}
       ) {
        $opt{'draw-header-separator'} = 1;
    }

    # If row separators are on and colour is not, if both use the header and
    # row dividers are '-', the header stops looking different from the content.
    # Change it to = in that case unless we've been explicitly given a different
    # separator
    if ( $opt{'draw-row-separator'}
         && ( defined $opt{'use-colour'} && !$opt{'use-colour'} )
         && !defined $opt{'header-separator'}
       ) {
        $opt{'header-separator'} = '=';
    }

    # Apply defaults to any unset setting. Have to do this after the initial
    # parsing because of utf8 encoding issues (need to encode stuff that comes
    # in from getopt, but the defaults set in the file are already encoded)
    foreach my $setting ( keys %defs ) {
        $opt{$setting} = $defs{$setting}
            unless ( defined $opt{$setting} );
    }

    # Have to prefetch at least one row to determine column widths
    if ( $opt{'prefetch-lines'} < 1 ) {
        $opt{'prefetch-lines'} = 1;
    }

    return %opt;
}

sub make_colour {
    my ( $colour_to_parse, $is_bg ) = @_;

    # xterm256 colour name numeric value mappings
    my %col_map = ( 'black'             => 0,
                    'maroon'            => 1,
                    'green'             => 2,
                    'olive'             => 3,
                    'navy'              => 4,
                    'purple'            => 5,
                    'teal'              => 6,
                    'silver'            => 7,
                    'grey'              => 8,
                    'red'               => 9,
                    'lime'              => 10,
                    'yellow'            => 11,
                    'blue'              => 12,
                    'fuchsia'           => 13,
                    'aqua'              => 14,
                    'white'             => 15,
                    'grey0'             => 16,
                    'navyblue'          => 17,
                    'darkblue'          => 18,
                    'blue3'             => 19,
                    'blue3'             => 20,
                    'blue1'             => 21,
                    'darkgreen'         => 22,
                    'deepskyblue4'      => 23,
                    'deepskyblue4'      => 24,
                    'deepskyblue4'      => 25,
                    'dodgerblue3'       => 26,
                    'dodgerblue2'       => 27,
                    'green4'            => 28,
                    'springgreen4'      => 29,
                    'turquoise4'        => 30,
                    'deepskyblue3'      => 31,
                    'deepskyblue3'      => 32,
                    'dodgerblue1'       => 33,
                    'green3'            => 34,
                    'springgreen3'      => 35,
                    'darkcyan'          => 36,
                    'lightseagreen'     => 37,
                    'deepskyblue2'      => 38,
                    'deepskyblue1'      => 39,
                    'green3'            => 40,
                    'springgreen3'      => 41,
                    'springgreen2'      => 42,
                    'cyan3'             => 43,
                    'darkturquoise'     => 44,
                    'turquoise2'        => 45,
                    'green1'            => 46,
                    'springgreen2'      => 47,
                    'springgreen1'      => 48,
                    'mediumspringgreen' => 49,
                    'cyan2'             => 50,
                    'cyan1'             => 51,
                    'darkred'           => 52,
                    'deeppink4'         => 53,
                    'purple4'           => 54,
                    'purple4'           => 55,
                    'purple3'           => 56,
                    'blueviolet'        => 57,
                    'orange4'           => 58,
                    'grey37'            => 59,
                    'mediumpurple4'     => 60,
                    'slateblue3'        => 61,
                    'slateblue3'        => 62,
                    'royalblue1'        => 63,
                    'chartreuse4'       => 64,
                    'darkseagreen4'     => 65,
                    'paleturquoise4'    => 66,
                    'steelblue'         => 67,
                    'steelblue3'        => 68,
                    'cornflowerblue'    => 69,
                    'chartreuse3'       => 70,
                    'darkseagreen4'     => 71,
                    'cadetblue'         => 72,
                    'cadetblue'         => 73,
                    'skyblue3'          => 74,
                    'steelblue1'        => 75,
                    'chartreuse3'       => 76,
                    'palegreen3'        => 77,
                    'seagreen3'         => 78,
                    'aquamarine3'       => 79,
                    'mediumturquoise'   => 80,
                    'steelblue1'        => 81,
                    'chartreuse2'       => 82,
                    'seagreen2'         => 83,
                    'seagreen1'         => 84,
                    'seagreen1'         => 85,
                    'aquamarine1'       => 86,
                    'darkslategray2'    => 87,
                    'darkred'           => 88,
                    'deeppink4'         => 89,
                    'darkmagenta'       => 90,
                    'darkmagenta'       => 91,
                    'darkviolet'        => 92,
                    'purple'            => 93,
                    'orange4'           => 94,
                    'lightpink4'        => 95,
                    'plum4'             => 96,
                    'mediumpurple3'     => 97,
                    'mediumpurple3'     => 98,
                    'slateblue1'        => 99,
                    'yellow4'           => 100,
                    'wheat4'            => 101,
                    'grey53'            => 102,
                    'lightslategrey'    => 103,
                    'mediumpurple'      => 104,
                    'lightslateblue'    => 105,
                    'yellow4'           => 106,
                    'darkolivegreen3'   => 107,
                    'darkseagreen'      => 108,
                    'lightskyblue3'     => 109,
                    'lightskyblue3'     => 110,
                    'skyblue2'          => 111,
                    'chartreuse2'       => 112,
                    'darkolivegreen3'   => 113,
                    'palegreen3'        => 114,
                    'darkseagreen3'     => 115,
                    'darkslategray3'    => 116,
                    'skyblue1'          => 117,
                    'chartreuse1'       => 118,
                    'lightgreen'        => 119,
                    'lightgreen'        => 120,
                    'palegreen1'        => 121,
                    'aquamarine1'       => 122,
                    'darkslategray1'    => 123,
                    'red3'              => 124,
                    'deeppink4'         => 125,
                    'mediumvioletred'   => 126,
                    'magenta3'          => 127,
                    'darkviolet'        => 128,
                    'purple'            => 129,
                    'darkorange3'       => 130,
                    'indianred'         => 131,
                    'hotpink3'          => 132,
                    'mediumorchid3'     => 133,
                    'mediumorchid'      => 134,
                    'mediumpurple2'     => 135,
                    'darkgoldenrod'     => 136,
                    'lightsalmon3'      => 137,
                    'rosybrown'         => 138,
                    'grey63'            => 139,
                    'mediumpurple2'     => 140,
                    'mediumpurple1'     => 141,
                    'gold3'             => 142,
                    'darkkhaki'         => 143,
                    'navajowhite3'      => 144,
                    'grey69'            => 145,
                    'lightsteelblue3'   => 146,
                    'lightsteelblue'    => 147,
                    'yellow3'           => 148,
                    'darkolivegreen3'   => 149,
                    'darkseagreen3'     => 150,
                    'darkseagreen2'     => 151,
                    'lightcyan3'        => 152,
                    'lightskyblue1'     => 153,
                    'greenyellow'       => 154,
                    'darkolivegreen2'   => 155,
                    'palegreen1'        => 156,
                    'darkseagreen2'     => 157,
                    'darkseagreen1'     => 158,
                    'paleturquoise1'    => 159,
                    'red3'              => 160,
                    'deeppink3'         => 161,
                    'deeppink3'         => 162,
                    'magenta3'          => 163,
                    'magenta3'          => 164,
                    'magenta2'          => 165,
                    'darkorange3'       => 166,
                    'indianred'         => 167,
                    'hotpink3'          => 168,
                    'hotpink2'          => 169,
                    'orchid'            => 170,
                    'mediumorchid1'     => 171,
                    'orange3'           => 172,
                    'lightsalmon3'      => 173,
                    'lightpink3'        => 174,
                    'pink3'             => 175,
                    'plum3'             => 176,
                    'violet'            => 177,
                    'gold3'             => 178,
                    'lightgoldenrod3'   => 179,
                    'tan'               => 180,
                    'mistyrose3'        => 181,
                    'thistle3'          => 182,
                    'plum2'             => 183,
                    'yellow3'           => 184,
                    'khaki3'            => 185,
                    'lightgoldenrod2'   => 186,
                    'lightyellow3'      => 187,
                    'grey84'            => 188,
                    'lightsteelblue1'   => 189,
                    'yellow2'           => 190,
                    'darkolivegreen1'   => 191,
                    'darkolivegreen1'   => 192,
                    'darkseagreen1'     => 193,
                    'honeydew2'         => 194,
                    'lightcyan1'        => 195,
                    'red1'              => 196,
                    'deeppink2'         => 197,
                    'deeppink1'         => 198,
                    'deeppink1'         => 199,
                    'magenta2'          => 200,
                    'magenta1'          => 201,
                    'orangered1'        => 202,
                    'indianred1'        => 203,
                    'indianred1'        => 204,
                    'hotpink'           => 205,
                    'hotpink'           => 206,
                    'mediumorchid1'     => 207,
                    'darkorange'        => 208,
                    'salmon1'           => 209,
                    'lightcoral'        => 210,
                    'palevioletred1'    => 211,
                    'orchid2'           => 212,
                    'orchid1'           => 213,
                    'orange1'           => 214,
                    'sandybrown'        => 215,
                    'lightsalmon1'      => 216,
                    'lightpink1'        => 217,
                    'pink1'             => 218,
                    'plum1'             => 219,
                    'gold1'             => 220,
                    'lightgoldenrod2'   => 221,
                    'lightgoldenrod2'   => 222,
                    'navajowhite1'      => 223,
                    'mistyrose1'        => 224,
                    'thistle1'          => 225,
                    'yellow1'           => 226,
                    'lightgoldenrod1'   => 227,
                    'khaki1'            => 228,
                    'wheat1'            => 229,
                    'cornsilk1'         => 230,
                    'grey100'           => 231,
                    'grey3'             => 232,
                    'grey7'             => 233,
                    'grey11'            => 234,
                    'grey15'            => 235,
                    'grey19'            => 236,
                    'grey23'            => 237,
                    'grey27'            => 238,
                    'grey30'            => 239,
                    'grey35'            => 240,
                    'grey39'            => 241,
                    'grey42'            => 242,
                    'grey46'            => 243,
                    'grey50'            => 244,
                    'grey54'            => 245,
                    'grey58'            => 246,
                    'grey62'            => 247,
                    'grey66'            => 248,
                    'grey70'            => 249,
                    'grey74'            => 250,
                    'grey78'            => 251,
                    'grey82'            => 252,
                    'grey85'            => 253,
                    'grey89'            => 254,
                    'grey93'            => 255,
                  );

    # If we've been passed a format string
    my $vtfmt = $is_bg ? ''
                       : "\x1b[29;25;24;23;22m";  # Reset formatting
    if ( $colour_to_parse =~ m/_/mxs ) {
        my $format_string;
        my %format_mapping = ( 'b' => '1', # bold
                               'i' => '3', # italic
                               'u' => '4', # underline
                               'l' => '5', # blink
                               's' => '9', # strikethrough
                             );
        ( $colour_to_parse, $format_string ) = split '_', $colour_to_parse;
        next if ( $is_bg );  # no text formatting for backgrounds
        my @formats = split q{}, $format_string;
        foreach my $format ( @formats ) {
            return '-3' unless ( defined $format_mapping{$format} );
            $vtfmt .= "\x1b[$format_mapping{$format}m";
        }
    }

    # If we've been passed an RGB value
    if ( $colour_to_parse =~ m/\A\d{1,3};\d{1,3};\d{1,3}/mxs ) {
        # Split the string into its red, green and blue components and make
        # sure they're in range
        my ( $r, $g, $b ) = map { return -1
                                      if ( $_ < 0 || $_ > 255 );
                                  int $_;
                                }
                                split ';', $colour_to_parse;
        return $is_bg ? "$vtfmt\x1b[48;2;$r;$g;${b}m"
                      : "$vtfmt\x1b[38;2;$r;$g;${b}m";
    }

    # If we've been passed an integer...
    if ( $colour_to_parse =~ m/\A\d+\z/mxs) {
        # ... make sure it's in range
        return -1
            if ( $colour_to_parse < 0
                 || $colour_to_parse > 255
               );
    }
    else {
        # Otherwise, try to turn the name we've been given into an integer
        return -2
            unless ( defined $col_map{lc $colour_to_parse} );
        $colour_to_parse = $col_map{lc $colour_to_parse};
    }

    # For the sorry folks whose terms only know about 16 colours
    if ( $colour_to_parse < 16 ) {
        my $base_colour = $is_bg ? 40 : 30;
        if ( $colour_to_parse > 7 ) {
            $base_colour += 52;
        }
        my $bold = ''; #'1;';
        $colour_to_parse += $base_colour;
        return "$vtfmt\x1b[${colour_to_parse}m";
    }
    # The colours beyond 15 have different vtXXX magic. This form supports
    # colours 0-15 too, but I'm doing those the other way for maximum
    # compatibility
    return ( $is_bg ) ? "$vtfmt\x1b[48;5;${colour_to_parse}m"
                      : "$vtfmt\x1b[38;5;${colour_to_parse}m";
}

sub parse_and_print_csv {
    ###########################################################################
    #
    # Main loop to process the data
    #
    ###########################################################################
    while ( !eof() ) {
        # Each iteration through this loop parses and prints one file
        my $row_num = 1;

        # First, fetch --prefetch lines to calculate column widths
        my ( $rows, $end_reached ) = read_rows($options{'prefetch-lines'});

        # Get the unwrapped widths of the columns we've fetched
        my @column_widths = get_column_widths($rows);

        # Allocate widths to the columns leaving room for the field separators
        my $sep_length = screen_length( $options{'column-separator'} );
        my $writeable_space = $options{'width'}
                              - ( scalar @column_widths - 1 ) * $sep_length
                              - ( scalar @column_widths )
                                * ( $options{'margin-left'}
                                    + $options{'margin-right'}
                                  )
                              - screen_length( $options{'border-left'} )
                              - screen_length( $options{'border-right'} );
        if ( $writeable_space < scalar @column_widths ) {
            error("Width too narrow to display data\n");
            error("Adjusting to minimum of 1 character per column\n", 0);
            $writeable_space = scalar @column_widths ;
        }
        my @allocated_widths = allocate_column_widths( $writeable_space,
                                                       @column_widths
                                                     );
        # Add a filename label if enabled
        if ( $options{'print-file-names'} ) {
            my $total_width = 0;
            foreach my $width ( @allocated_widths ) {
                $total_width += $width;
            }
            $total_width += ( $sep_length * ( scalar @allocated_widths - 1 )
                              + ( scalar @column_widths )
                                * ( $options{'margin-left'}
                                    + $options{'margin-right'}
                                  )
                              + screen_length( $options{'border-left'} )
                              + screen_length( $options{'border-right'} )
                            );
            my $fn_length = length $ARGV;
            my $pad_length = ( $total_width / 2 - $fn_length / 2 );
            if ( $pad_length < 0 ) {
                $pad_length = 0;
            }
            my $padding = ' ' x $pad_length;

            my $col = $options{'colours'}{'file-label'};
            my $clear = $options{'colours'}{'colour-reset'};
            printf( "$col%${total_width}s$clear\n", "$ARGV$padding" );
        }

        # Print the top of the border if we're doing borders
        if ( $options{'border'} ) {
            my $border_type = $options{'header'}
                              ? $options{'colours'}{'header-border'}
                              : $options{'colours'}{'content-border'};
            my $pal = { 'border'    => $border_type,
                        'separator' => $border_type,
                        'reset'     => $options{'colours'}{'colour-reset'},
                      };
            print_separator( $options{'border-ul'},
                             $options{'border-top'},
                             $options{'border-top-x'},
                             $options{'border-ur'},
                             \@allocated_widths,
                             $pal
                           );
        }

        # Print a header row if we're doing that sort of thing
        if ( $options{'header'} ) {
            my $header_row = shift @{ $rows };
            my ( $bl, $br, $blx, $brx, $vs ) = ( '', '', '', '', '' );
            if ( $options{'border'} ) {
                $bl  = $options{'border-left'};
                $br  = $options{'border-right'};
                $blx = $options{'border-left-hx'};
                $brx = $options{'border-right-hx'};
            }
            my $pal = { 'border'   => $options{'colours'}{'header-border'},
                        'border-x' => $options{'colours'}{'header-separator-border'},
                        'col-sep'  => $options{'colours'}{'header-column-separator'},
                        'even-row' => $options{'colours'}{'header'},
                        'odd-row'  => $options{'colours'}{'header'},
                        'reset'    => $options{'colours'}{'colour-reset'},
                        'row-sep'  => $options{'colours'}{'header-separator'}
                      };
            if ( $options{'draw-header-separator'} ) {
                $vs = $options{'header-separator'};
            }
            print_rows( [ $header_row ],
                        0,
                        $options{'column-separator'},
                        $vs,
                        $options{'header-separator-x'},
                        $bl,
                        $br,
                        $blx,
                        $brx,
                        \@allocated_widths,
                        $pal,
                        0
                      );
        }

        # Cycle through the remaining rows in this file and print them
        while ( scalar @{ $rows } ) {
            # Print the rows we already have
            my ( $vs, $bl, $br, $blx, $brx ) = ( '', '', '', '', '' );
            if ( $options{'border'} ) {
                $bl  = $options{'border-left'};
                $br  = $options{'border-right'};
                $blx = $options{'border-left-sx'};
                $brx = $options{'border-right-sx'};
            }
            if ( $options{'draw-row-separator'} ) {
                $vs = $options{'row-separator'};
            }
            my $pal = { 'border'   => $options{'colours'}{'content-border'},
                        'border-x' => $options{'colours'}{'content-border'},
                        'col-sep'  => $options{'colours'}{'content-column-separator'},
                        'even-row' => $options{'colours'}{'content-even-row'},
                        'odd-row'  => $options{'colours'}{'content-odd-row'},
                        'reset'    => $options{'colours'}{'colour-reset'},
                        'row-sep'  => $options{'colours'}{'row-separator'}
                      };
            $row_num = print_rows( $rows,
                                   $row_num,
                                   $options{'column-separator'},
                                   $vs,
                                   $options{'separator-x'},
                                   $bl,
                                   $br,
                                   $blx,
                                   $brx,
                                   \@allocated_widths,
                                   $pal,
                                   $end_reached
                                 );
            $rows = [];

            # if we're not at the end of the file, read the next line
            if ( !$end_reached ) {
                ( $rows, $end_reached ) = read_rows( 1 );

                # If there are more columns in this section than we've seen
                # before, we'll need to re-allocate column widths to make space
                if ( scalar @{ $rows->[0] } > scalar @allocated_widths ) {
                    my $msg = "Row count changed, adjusting column widths.\n"
                            . "Consider increasing --prefetch.\n";
                    error( $msg, 0 );

                    # if there's still more data in the file, do another
                    # prefetch round so we can do better column sizing
                    my $more_rows;
                    ( $more_rows, $end_reached )
                        = read_rows($options{'prefetch-lines'})
                        if ( !$end_reached);
                    push @{ $rows }, @{ $more_rows };

                    # Reallocate column widths
                    @column_widths = get_column_widths($rows);
                    $writeable_space
                        = $options{'width'}
                          - ( scalar @column_widths - 1 ) * $sep_length
                          - ( scalar @column_widths )
                            * ( $options{'margin-left'}
                                + $options{'margin-right'}
                              )
                          - screen_length( $options{'border-left'} )
                          - screen_length( $options{'border-right'} );
                    @allocated_widths
                        = allocate_column_widths( $writeable_space,
                                                  @column_widths
                                                );
                }
            }
        }

        # Print the bottom border if we're doing borders
        if ( $options{'border'} ) {
            my $pal = { 'border'    => $options{'colours'}{'content-border'},
                        'separator' => $options{'colours'}{'content-border'},
                        'reset'     => $options{'colours'}{'colour-reset'},
                      };
            print_separator( $options{'border-ll'},
                             $options{'border-bottom'},
                             $options{'border-bottom-x'},
                             $options{'border-lr'},
                             \@allocated_widths,
                             $pal,
                           );
        }
    }
    return;
}

sub read_rows {
    my $row_count = shift;
    my @rows;
    my $parse_line = '';
    my $eof_reached = 0;

    # define some csv parsing regular expressions
    my $cs = qr/(?:(?<=,)|(?<=^))/mxs;
    my $ce = qr/(?=,|$)/mxs;
    my $quoted_cell = qr/$cs"(?:[^"]|"")*?"$ce/mxs;
    my $unquoted_cell = qr/$cs(?!")(?:(?!$)[^,])*$ce/mxs;
    my $cell = qr/$quoted_cell|$unquoted_cell/mxs;

    my $empty_row = qr/^$/mxs;
    my $row = qr/\A(?:$cell(?:,$cell)*)$/mxs;

    # This is for use in error messaging
    my $start_of_row = $NR;

    # Read lines from the input until one of the following:
    #   A) Reach the target number of rows
    #   B) Reach the end of file
    #   C) The line we are trying to parse exceeds the maximum line length
    while( scalar @rows < $row_count
           && !eof
         ) {
        my $input_line = <>;
        $parse_line .= $input_line;

        # Abort if we've hit the line length limit
        last if ( length $parse_line > $options{'max-line-length'} );

        # If we have a valid row at this point
        if ( $parse_line =~ m/$row/mxs ) {
            my @cells = map { s/\A"(.*)"\z/$1/mxs;
                              s/""/"/mxsg;
                              $_
                            }
                            $parse_line =~ m/($cell)/mxsg;
            push @rows, \@cells;
            $parse_line = '';
            $start_of_row = $NR;
        }
    }

    # If we didn't end off with nothing to parse, then we died uncleanly
    if ( $parse_line ne '' ) {
        my $abort_line = $NR;
        $eof_reached = 1;
        close $ARGV
            if ( $ARGV ne '-' );
        error( "End of file or maximum parse length reached without finding a "
               . "valid row starting at line $start_of_row and aborted at "
               . "line $abort_line.\n"
             );
    }
    elsif ( eof ) {
        # If we've reached the end of the file, close the current file to reset
        # line numbers. Pass back that info so new headers can be drawn, etc.
        close $ARGV
            if ( $ARGV ne '-' );
        $eof_reached = 1;
    }
    return (\@rows, $eof_reached);
}

sub error {
    my ( $error_message, $fatal ) = @_;

    # assume errors are fatal
    $fatal = 1 unless ( defined $fatal );

    unless ( $options{'quiet'} ) {
        print STDERR $error_message;
    }

    if ( $fatal && !$options{'continue-on-error'} ) {
        exit 1;
    }

    return;
}

sub print_rows {
    my ( $rows, $row_num, $h_sep, $v_sep, $sep_x, $bl, $br, $blx, $brx,
         $column_widths, $palette, $fin
       ) = @_;

    # Cycle through each row
    while ( scalar @{ $rows } ) {
        my $row_data = shift @{ $rows };

        # Wrap the content of each field to the allocated width
        my @wrapped_cell_data;
        for my $col_no ( 0 .. $#{ $column_widths } ) {
            my $content = $row_data->[ $col_no ] || '';
            push @wrapped_cell_data,
                [ wrap_content( $content, $column_widths->[ $col_no ] ) ];
        }

        # Cycle through the wraped content until no field has unprinted data
        # remaining
        my $has_unprinted_content = 1;
        while( $has_unprinted_content ) {
            my @column_slices;

            # Assume we will have no more unprinted content until we see some
            # we'll need to print
            $has_unprinted_content = 0;

            # Cycle through the columns
            for my $col_no ( 0 .. $#{ $column_widths } ) {
                my $width = $column_widths->[$col_no];
                my $slice;
                my $is_right_just = get_justification( $col_no, $slice );
                # Make a copy of the margins because in some circumstances we need
                # to step on them
                my %m = ( 'left'  => $options{'margin-left'},
                          'right' => $options{'margin-right'},
                        );

                # Get the next line of content for this column
                $slice = shift @{ $wrapped_cell_data[$col_no] } || '';

                # If there's still more data in this column, then we'll need
                # another loop
                $has_unprinted_content = 1
                    if ( scalar @{ $wrapped_cell_data[$col_no] } );

                # Pad the data with enough whitespace to make it the proper
                # length
                my $pad_len = $width - screen_length( $slice );

                if ( $pad_len < 0 ) {
                    # This happen if we're trying to dump a double-wide
                    # character into a cell that is one wide
                    error( 'Double-width character found in a column that is '
                           . "a single character wide\n",
                           0
                         );
                    # spill over into the margin if there is margin. Eat the
                    # margin opposite the justification first, then start
                    # eating from the other side. If there's not enough margin
                    # then people will just have to deal with broken grid lines
                    my ( $same, $opp ) = ( ($is_right_just ? 'right' : 'left'),
                                           $is_right_just ? 'left' : 'right'
                                         );
                    if ( $pad_len + $m{$opp} >= 0 ) {
                        $m{$opp} = $pad_len + $m{$opp};
                    }
                    elsif ( $pad_len + $m{$opp} + $m{$same} >= 0) {
                        $m{$same} = $pad_len + $m{$opp} + $m{$same};
                        $m{$opp} = 0;
                    }
                    else {
                        $m{$opp} = 0;
                        $m{$same} = 0;
                    }
                    $pad_len = 0;
                }

                # Add data for this column to the line we'll be outputting
                push @column_slices, ' ' x $m{'left'}
                                     . ( $is_right_just
                                         ? ' ' x $pad_len . $slice
                                         : $slice . ' ' x $pad_len
                                       )
                                     . ' ' x $m{'right'};
            }
            # print the row
            my $content_color = $row_num % 2 ? $palette->{'odd-row'}
                : $palette->{'even-row'};

            my $colsep = $palette->{'col-sep'} . "$h_sep$content_color";

            print $palette->{'border'} . $bl . $content_color
                  . join( $colsep, @column_slices )
                  . $palette->{'border'} . $br . $palette->{'reset'} . "\n";
        }

        $row_num++;

        # If we have a vertical separator row, print it too unless we're at the
        # last line of a file
        if ( length $v_sep
             && ( !$fin
                  || scalar @{ $rows }
                )
           ) {
            my $pal = { 'border'    => $palette->{'border-x'},
                        'separator' => $palette->{'row-sep'},
                        'reset'     => $palette->{'reset'},
                      };
            print_separator( $blx, $v_sep, $sep_x, $brx,
                             $column_widths, $pal
                           );
        }
    }
    return $row_num;
}

sub get_justification {
    my ( $column, $content ) = @_;
    return 0;
}

sub print_separator {
    my ( $l, $sep, $sep_x, $r, $col_widths, $palette ) = @_;

    my $sep_length = screen_length( $sep );

    print $palette->{'border'} . $l . $palette->{'separator'} .
          join( $sep_x,
                map { # Repeat $sep enough to fill the column then trim it to
                      # the column width
                      my $col_width
                          = $_
                          + $options{'margin-left'}
                          + $options{'margin-right'};
                      my $repeats = int($col_width / $sep_length)+1;
                      my ( $sep_field )
                          = ($sep x $repeats) =~ m/(.{$col_width})/mxs;
                      $sep_field;
                    } @{ $col_widths }
              )
          . $palette->{'border'} . $r . $palette->{'reset'} ."\n";
    return;
}

sub get_cell_width {
    my $cell = shift;
    my $nl = qr/\r\n|\r|\n/mxs;
    return ( sort {$a <=> $b}               # numerical sort the ...
                  map { screen_length($_) } # ... length of each line ...
                  split $nl, $cell          # ... we split the cell into
           )[-1] || 0;                      # final item is length of longest line
}

sub get_column_widths {
    my $rows = shift @_;
    my @max_col_widths;
    foreach my $row ( @{ $rows } ) {
        my $cell_no = 0;
        foreach my $cell ( @{ $row } ) {
            my $cell_width = get_cell_width( $cell );
            if ( !defined $max_col_widths[$cell_no]
                 || $cell_width > $max_col_widths[$cell_no]
               ) {
                $max_col_widths[$cell_no] = $cell_width;
            }
            $cell_no++;
        }
    }
    return @max_col_widths;
}

sub allocate_column_widths {
    my ( $total_scr_width, @column_sizes ) = @_;
    my $remaining_columns = scalar @column_sizes || 1;
    my @allocated_widths = map { 0 } @column_sizes;

    # Dish out the available width one cell at a time until all the available
    # space is used up. Stop distributing space to columns if we reach the
    # length of their longest data. Distribute space in order of desired column
    # length, longest first. That way if there's not an even split, the longest
    # columns will get the space.
    my $total_allocated = 0;
    my @column_order = sort { $column_sizes[$b] <=> $column_sizes[$a] }
                            ( 0 .. $#column_sizes );
    while ( $total_allocated < $total_scr_width ) {
        my $made_adjustments = 0;
        foreach my $col_no ( @column_order ) {
            if ( $total_allocated < $total_scr_width
                 && $allocated_widths[$col_no] < $column_sizes[$col_no]
               ) {
                $allocated_widths[$col_no]++;
                $total_allocated++;
                $made_adjustments++;
            }
            # If we didn't make any changes, nothing is looking for room, so
            # break outta here
        }
        last if ( !$made_adjustments );
    }

    return @allocated_widths;
}

sub screen_length {
    my $string = shift @_;
    my $length = 0;

    # We need to count how wide this string will be on screen
    $string =~
        m/^(?{ local $CNT = 0; })
          (?(?=\p{East_Asian_Width: W})     # If we have a wide asian character
            .(?{ local $CNT = $CNT + 2; })  # Increase the length by 2
            |.(?{ local $CNT = $CNT + 1; }) # Otherwise by 1
          )*\z                              # repeat for entire string
          (?{ $length = $CNT; })  # save the final value to our length
         /mxs;
    return $length;
}

sub wrap_content {
    my ( $line, $wrap_length ) = @_;
    my @wrapped_lines;

    # So, we need a regular expression that matches text capped at the column
    # width. This is complicated due to double-width characters which prevent
    # us from just grapping up to $wrap_length characters. We actually need it
    # in both greedy and non-greedy form.
    my $up_to_max_greedy
        = qr/\A(?{ local $CNT = 0; })  # $CNT keeps track of the printed length
             (?(?=\p{East_Asian_Width: W})       # Wide asian character?
                 .(?{ local $CNT = $CNT + 2; })| # Yes? Bump $CNT by 2
                 .(?{ local $CNT = $CNT + 1; })  # Otherwise by 1
             )+   # Match as much as we can, but at least one
             (?(?{ $CNT <= $wrap_length; }) # Length less than the wrap length?
                 (?=.)|    # If so, any character is ok.
                 (?=A)B    # If not, we'll only be satisfied with an impossible
                           # next character. This will force a backtrack of one
                           # which will decrement the $CNT appropriately due to
                           # the 'local' magic.
             )
            /mxs;
    my $up_to_max_sparse
        = qr/\A(?{ local $CNT = 0; })  # $CNT keeps track of the printed length
             (?(?=\p{East_Asian_Width: W})       # Wide asian character?
                 .(?{ local $CNT = $CNT + 2; })| # Yes? Bump $CNT by 2
                 .(?{ local $CNT = $CNT + 1; })  # Otherwise by 1
             )+?   # Match as little as we can, but at least one
             (?(?{ $CNT <= $wrap_length; }) # Length less than the wrap length?
                 (?=.)|    # If so, any character is ok.
                 (?=A)B    # If not, nothing is ok. Same as in the greedy land.
             )
            /mxs;

    while ( length $line ) {
        my $nl = qr/\r\n|\r|\n/mxs;
        my $extracted;

        # If there's a newline within the wrap length, wrap there
        if ( $line =~ m/$up_to_max_sparse$nl/mxs ) {
            ( $extracted, $line )
                = $line =~ m/($up_to_max_sparse)$nl(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
        # If our line is less than the wrap length, we're done
        elsif ( screen_length( $line ) <= $wrap_length ) {
            chomp $line;
            push @wrapped_lines, $line;
            $line = '';
        }
        # If there's whitespace within the wrap length, wrap at the last
        elsif ( $line =~ m/$up_to_max_greedy\s/mxs ) {
            ( $extracted, $line ) = $line =~ m/($up_to_max_greedy)\s(.*)\z/mxs;
            push @wrapped_lines, $extracted;

            # If we have a single width column, we don't want to eat that last
            # space, otherwise words bleed together in the output.
            push @wrapped_lines, ' '
                if ( $wrap_length == 1 );
        }
        # Otherwise try to just chomp stuff off up to the wrap length
        elsif ( $line =~ m/$up_to_max_greedy/mxs ) {
            ( $extracted, $line ) = $line =~ m/($up_to_max_greedy)(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
        # We only get here if the column is too narrow to fix the next
        # character. In this case, just grab and return a single character and
        # deal with it in error handling of the parent function
        else {
            ( $extracted, $line ) = $line =~ m/(.)(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
    }
    return @wrapped_lines;
}
