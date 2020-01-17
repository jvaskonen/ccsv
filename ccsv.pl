#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars ) ;

use Term::ReadKey;
use Getopt::Long;
use utf8;

my %options = parse_options();
parse_and_print_csv();
my $csv_data = join q{}, <>;

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
    --hvsep               String to be repeated and used as a separator between
                          the header and data rows.
                          Default: Equal to vsep if defined, otherwise '-'
    --hsepx               String to be used between columns in the header
                          separator row.
                          Default: Equal to sepx
    --max-line-length -m  Abort parsing a csv if the line length exceeds the
                          specified value.
                          Default: 1,000,000
    --prefetch -p         The number of rows to fetch before starting to dispay
                          output. Column widths will be allocated based on the
                          data in those rows. If the column count subsequently
                          changes, this number of rows will again be fetched
                          to recalculate column widths.
                          Default: 100
    -print-file-names -n  Print a header row before each file with the filename
                          Default: True if more than one file specified
    --quiet -q            Supress error messages
                          Default: false
    --sepx -x             String used between columns on a separator row
                          Default: '-+-'
    --vsep -v             String to be repeated and used as a separator between
                          rows.
                          Default: row separation off
    --width -w            Width to wrap the output to
                          Default: terminal width
__USAGE__
    exit 0;
}

sub parse_options {
    my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
    my %opt = ( 'border'                 => 0,
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
                'column-separator'       => ' | ',
                'continue-on-error'      => 0,
                'header'                 => 0,
                'max-line-length'        => 1_000_000,
                'prefetch-lines'         => 100,
                'quiet'                  => 0,
                'separator-intersection' => '-+-',
                'use-color'              => 1,
                'vertical-separator'     => '',
                'width'                  => $wchar,
              );
    Getopt::Long::Configure ("bundling");
    GetOptions( 'border|b'            => \$opt{'border'},
                'colour|color|c'      => \$opt{'use-color'},
                'csep|s=s'            => \$opt{'column-separator'},
                'continue|t'          => \$opt{'continue-on-error'},
                'header|h'            => \$opt{'header'},
                'hsepx=s'             => \$opt{'header-sep-intersect'},
                'hvsep=s'             => \$opt{'header-vert-sep'},
                'left|l=s'            => \$opt{'left-justify-columns'},
                'max-line-length|m=i' => \$opt{'max-line-length'},
                'print-file-names|n'  => \$opt{'print-file-names'},
                'palette|p=s'         => \$opt{'palette'},
                'prefetch=i'          => \$opt{'prefetch-lines'},
                'sepx|x=s'            => \$opt{'separator-intersection'},
                'quiet|q'             => \$opt{'quiet'},
                'right|r=s'           => \$opt{'right-justify-columns'},
                'vsep|v=s'            => \$opt{'vertical-separator'},
                'width|w=i'           => \$opt{'width'},
              ) || usage();

    # Print file names by default if more than one file has been specified
    if ( !defined $opt{'print-file-names'} ) {
        $opt{'print-file-names'} = ( scalar @ARGV > 1 ) ? 1 : 0;
    }

    # If we're using borders, use fancy column separators
    if ( $opt{'border'} ) {
        binmode STDOUT, ':utf8';
        if ( !length $opt{'border-ul'} )    { $opt{'border-ul'}    = '┌─'   }
        if ( !length $opt{'border-top'} )   { $opt{'border-top'}   = '─'    }
        if ( !length $opt{'border-top-x'} ) { $opt{'border-top-x'} = '─┬─'  }
        if ( !length $opt{'border-ur'} )    { $opt{'border-ur'}    = '─┒'   }
        if ( !length $opt{'border-right'} ) { $opt{'border-right'} = ' ┃'   }
        if ( !length $opt{'border-right-hx'} ) {
            $opt{'border-right-hx'} = '━┫';
        }
        if ( !length $opt{'border-right-sx'} ) {
            $opt{'border-right-sx'} = '─┨';
        }
        if ( !length $opt{'border-lr'} )     { $opt{'border-lr'} = '━┛'    }
        if ( !length $opt{'border-bottom'} ) { $opt{'border-bottom'} = '━' }
        if ( !length $opt{'border-bottom-x'} ) {
            $opt{'border-bottom-x'} = '━┷━';
        }
        if ( !length $opt{'border-ll' } )     { $opt{'border-ll'} = '┕━'      }
        if ( !length $opt{'border-left'} )    { $opt{'border-left'} = '│ '     }
        if ( !length $opt{'border-left-hx'} ) { $opt{'border-left-hx'} = '┝━' }
        if ( !length $opt{'border-left-sx'} ) { $opt{'border-left-sx'} = '├─' }
        if ( !length $opt{'column-separator'} ) {
            $opt{'column-separator'} = ' | ';
        }
        if ( $opt{'vertical-separator'} eq '-' ) {
            $opt{'vertical-separator'} = '─';
        }
        if ( $opt{'column-separator'} eq ' | ' ) {
            $opt{'column-separator'} = ' │ ';
        }
        if ( $opt{'separator-intersection'} eq '-+-' ) {
            $opt{'separator-intersection'} = '─┼─';
        }
    }

    # The separator between the header and content defaults to the row
    # separator if defined and '-' otherwise
    if ( !defined $opt{'header-vert-sep'} ) {
        if ( $opt{'border'} ) {
            $opt{'header-vert-sep'} = ( length $opt{'vertical-separator'}
                                        && $opt{'vertical-separator'} ne '─'
                                      ) ? ( $opt{'vertical-separator'} ) : '━';
        }
        else {
            $opt{'header-vert-sep'} = ( length $opt{'vertical-separator'} )
                                      ? $opt{'vertical-separator'}
                                      : '-';
        }
    }

    # By default, the header separator uses the same intersection string as the
    # row separator
    if ( !defined $opt{'header-sep-intersect'} ) {
        $opt{'header-sep-intersect'} = ( $opt{'border'} )
                                       ? '━┿━'
                                       : $opt{'separator-intersection'};
    }

    # Have to prefetch at least one row to determine column widths
    if ( $opt{'prefetch-lines'} < 1 ) {
        $opt{'prefetch-lines'} = 1;
    }

    return %opt;
}

sub make_color {
    # Allow users to define colours by name
    my %colors = ( 'black'             => 0,
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
}

sub parse_and_print_csv {
    # Main loop to process the data
    while ( !eof() ) {
        # Each iteration through this loop parses and prints one file

        # First, fetch --prefetch lines to calculate column widths
        my ( $rows, $end_reached ) = read_rows($options{'prefetch-lines'});

        # Get the unwrapped widths of the columns we've fetched
        my @column_widths = get_column_widths($rows);

        # Allocate widths to the columns leaving room for the field separators
        my $sep_length = length $options{'column-separator'};
        my $writeable_space = $options{'width'}
                              - ( scalar @column_widths - 1 ) * $sep_length
                              - length( $options{'border-left'} )
                              - length( $options{'border-right'} );
        if ( $writeable_space < scalar @column_widths ) {
            error("Width too narrow to display data\n");
            error("Adjusting to minimum of 1 character per column\n", 0);
            $writeable_space = scalar @column_widths ;
        }
        my @allocated_widths = allocate_column_widths( $writeable_space,
                                                       @column_widths
                                                     );
        # Add a filename header now if enabled
        if ( $options{'print-file-names'} ) {
            my $total_width = 0;
            foreach my $width ( @allocated_widths ) {
                $total_width += $width;
            }
            $total_width += ( $sep_length * ( scalar @allocated_widths - 1 )
                              + length( $options{'border-left'} )
                              + length( $options{'border-right'} )
                            );
            my $fn_length = length $ARGV;
            my $pad_length = ( $total_width / 2 - $fn_length / 2 );
            if ( $pad_length < 0 ) {
                $pad_length = 0;
            }
            my $padding = ' ' x $pad_length;
            printf( "%${total_width}s\n", "$ARGV$padding" );
        }

        # Print the top of the border if we're doing borders
        if ( $options{'border'} ) {
            print_separator( $options{'border-ul'},
                             $options{'border-top'},
                             $options{'border-top-x'},
                             $options{'border-ur'},
                             \@allocated_widths,
                             {}
                           );
        }

        # Print a header row if we're doing that sort of thing
        if ( $options{'header'} ) {
            my $header_row = shift @{ $rows };
            print_rows( [ $header_row ],
                        $options{'column-separator'},
                        $options{'header-vert-sep'},
                        $options{'header-sep-intersect'},
                        $options{'border-left'},
                        $options{'border-right'},
                        $options{'border-left-hx'},
                        $options{'border-right-hx'},
                        \@allocated_widths,
                        {},
                        0
                      );
        }

        # Cycle through the remaining rows in this file and print them
        while ( scalar @{ $rows } ) {
            # Print the rows we already have
            print_rows( $rows,
                        $options{'column-separator'},
                        $options{'vertical-separator'},
                        $options{'separator-intersection'},
                        $options{'border-left'},
                        $options{'border-right'},
                        $options{'border-left-sx'},
                        $options{'border-right-sx'},
                        \@allocated_widths,
                        {},
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
                    @allocated_widths
                        = allocate_column_widths( $writeable_space,
                                                  @column_widths
                                                );
                }
            }
        }

        # Print the bottom border if we're doing borders
        if ( $options{'border'} ) {
            print_separator( $options{'border-ll'},
                             $options{'border-bottom'},
                             $options{'border-bottom-x'},
                             $options{'border-lr'},
                             \@allocated_widths,
                             {}
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
    my $unquoted_cell = qr/$cs(?!")[^,\n]*$ce/mxs;
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
        close $ARGV;
        error( "End of file or maximum parse length reached without finding a "
               . "valid row starting at line $start_of_row and aborted at "
               . "line $abort_line.\n"
             );
    }
    elsif ( eof ) {
        # If we've reached the end of the file, close the current file to reset
        # line numbers. Pass back that info so new headers can be drawn, etc.
        close $ARGV;
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
    my ( $rows, $h_sep, $v_sep, $sep_x, $bl, $br, $blx, $brx,
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

                # Get the next line of content for this column
                $slice = shift @{ $wrapped_cell_data[$col_no] } || '';

                # If there's still more data in this column, then we'll need
                # another loop
                $has_unprinted_content = 1
                    if ( scalar @{ $wrapped_cell_data[$col_no] } );

                # Add data for this column to the line we'll be outputting
                push @column_slices, sprintf( "%-${width}s", $slice );
            }
            # print the line
            print $bl . join( $h_sep, @column_slices ) . "$br\n";
        }
        # If we have a vertical separator row, print it too unless we're at the
        # last line of a file
        if ( length $v_sep
             && ( !$fin
                  || scalar @{ $rows }
                )
           ) {
            print_separator( $blx, $v_sep, $sep_x, $brx, $column_widths, {} );
        }
    }
    return;
}

sub print_separator {
    my ( $l, $sep, $sep_x, $r, $col_widths, $palette ) = @_;

    my $sep_length = length $sep;
    print $l .
          join( $sep_x,
                map { # Repeat $sep enough to fill the column then trim it to
                      # the column width
                      my $col_width = $_;
                      my $repeats = int($col_width / $sep_length)+1;
                      my ( $sep_field )
                          = ($sep x $repeats) =~ m/(.{$col_width})/mxs;
                      $sep_field;
                    } @{ $col_widths }
              )
          . "$r\n";
    return;
}

sub get_cell_width {
    my $cell = shift;
    return ( sort {$a <=> $b}           # numerical sort the ...
                  map { length }        # ... length of each line ...
                  split "\n", $cell     # ... we split the cell into
           )[-1] || 0;                  # final item is length of longest line
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
    my ( $total_width, @column_sizes ) = @_;
    use YAML;
    my $remaining_columns = scalar @column_sizes || 1;

    my @allocated_widths = map { undef } @column_sizes;

    # first pass, find the cells that need less than 1/Nth the space
    # where N is the number of columns.
    # On subsequent passes, give the space not used by a column back
    # and see if that's enough. If so, remove that one.
    # lather rinse repeat. Anything that's still too big gets its cut
    # of the remaining space
    my $fair_width = $total_width / $remaining_columns;
    my $last_fair = -1;
    my $total_allocated = 0;
    while ( $fair_width != $last_fair && $remaining_columns > 0) {
        my $col_no = 0;
        foreach my $colsize ( @column_sizes ) {
            if ( !defined $allocated_widths[$col_no]
                 && $colsize <= $fair_width
               ) {
                $allocated_widths[$col_no] = $colsize;
                $total_allocated += $colsize;
                $remaining_columns--;
            }
            $col_no++;
        }
        if ( $remaining_columns > 0 ) {
            $last_fair = $fair_width;
            $fair_width = ($total_width - $total_allocated)
                          / $remaining_columns;
        }
    }

    return map { defined $_ ? $_ : int $fair_width } @allocated_widths;
}

sub wrap_content {
    my ( $line, $wrap_length ) = @_;
    my @wrapped_lines;
    while ( length $line ) {
        # If there's a newline within the wrap length, wrap there
        if ( $line =~ m/\A.{0,$wrap_length}\n/mxs ) {
            my $extracted;
            ( $extracted, $line ) = $line =~ m/\A(.*?)\n(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
        # If our line is less than the wrap length, we're done
        elsif ( length $line <= $wrap_length ) {
            chomp $line;
            push @wrapped_lines, $line;
            $line = '';
        }
        # If there's whitespace within the wrap length, wrap at the last
        elsif ( $line =~ m/\A.{0,$wrap_length}\s/mxs ) {
            my $extracted;
            ( $extracted, $line ) = $line =~ m/\A(.{0,$wrap_length})\s(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
        # Otherwise just chomp off the first wrap length characters
        else {
            my $extracted;
            ( $extracted, $line ) = $line =~ m/\A(.{$wrap_length})(.*)\z/mxs;
            push @wrapped_lines, $extracted;
        }
    }
    return @wrapped_lines;
}
