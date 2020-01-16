#!/usr/bin/perl

use strict;
use warnings;
use Term::ReadKey;
use Getopt::Long;

my %options = parse_options();

my $csv_data = join q{}, <>;
write_table(parse_csv_data($csv_data));

sub parse_options {
    my %opt;
    Getopt::Long::Configure ("bundling");
    GetOptions( 'header|h'       => \$opt{'header'},
                'colour|color|c' => \$opt{'use_color'},
                'palette|p=s'   => \$opt{'palette'},
                'left|l=s'      => \$opt{'left-justify-columns'},
                'right|r=s'     => \$opt{'right-justify-columns'},
              );
    return %opt;
}

sub parse_csv_data {
    my $data = shift;
    chomp $data;

    my $quoted_cell = qr/(?:(?<=,)|(?<=^))"(?:[^"]|"")*?"(?=,|$)/mxs;
    my $unquoted_cell = qr/(?:(?<=,)|(?<=^))[^,\n]*(?=,|$)/mxs;
    my $cell = qr/$quoted_cell|$unquoted_cell/mxs;

    my $empty_row = qr/^$/mxs;
    my $row = qr/^$cell(?:,$cell)*$/mxs;

    my @raw_rows = $data =~ m/($row)/g;
    my @rows = map { [ map { s/\A"(.*)"\z/$1/mxs;
                             s/""/"/mxsg;
                             $_
                           }
                           m/($cell)/mxsg
                     ]
                   }
                   @raw_rows;
    return \@rows;
}

sub write_table {
    my $rows = shift @_;

    my $term_width = get_term_width();
    my @column_widths = get_column_widths($rows);
    # Need 3 spaces between columns for padding
    my $writeable_space = $term_width - ( scalar @column_widths - 1 ) * 3;
    my @allocated_widths = allocate_column_widths( $writeable_space,
                                                   @column_widths
                                                 );
    if ( $options{'header'} ) {
        my $header_row = shift @{ $rows };
        write_row( $header_row, ' | ', \@allocated_widths, {} );
        write_row( [ map { '-'x$_ } @allocated_widths ], '-|-', \@allocated_widths, {} );
    }
    foreach my $row ( @{ $rows } ) {
        write_row( $row, ' | ', \@allocated_widths, {} );
    }
    return;
}

sub write_row {
    my ( $row_data, $separator, $column_widths, $palette ) = @_;

    my @wrapped_cell_data;
    for my $col_no ( 0 .. $#{ $column_widths } ) {
        my $content = $row_data->[ $col_no ] || '';
        push @wrapped_cell_data,
            [ wrap_content( $content, $column_widths->[ $col_no ] ) ];
    }

    my $has_unprinted_content = 1;
    while( $has_unprinted_content ) {
        my @column_slices;
        $has_unprinted_content = 0;
        for my $col_no ( 0 .. $#{ $column_widths } ) {
            my $width = $column_widths->[$col_no];
            my $slice;
            $slice = shift @{ $wrapped_cell_data[$col_no] } || '';
            $has_unprinted_content = 1
                if ( scalar @{ $wrapped_cell_data[$col_no] } );
            push @column_slices, sprintf( "%-${width}s", $slice );
        }
        print join( $separator, @column_slices ) . "\n";
    }
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

sub get_term_width {
    my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
    return $wchar;
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
