#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars );
use IPC::Open3;
use POSIX ":sys_wait_h";
use Symbol 'gensym';
use Getopt::Long;

my $verbose = 0;
my $escape_output = 0;
GetOptions( 'verbose|v'       => \$verbose,
            'escape-output|e' => \$escape_output,
          );
do_testing();

sub run_test {
    my %params = @_;

    my $test_name = exists $params{name} ? $params{name} : 'unknown_test';
    my @args = exists $params{args} && ref $params{args} eq 'ARRAY' ? @{$params{args}} : ();
    my @command = ( $params{command}, @args );
    my $expected_return = $params{expected_return} ? $params{expected_return} : 0;
    my $expected_stdout = $params{expected_stdout} ? $params{expected_stdout} : '';
    my $expected_stderr = $params{expected_stderr} ? $params{expected_stderr} : '';

    # Open a pipe to the command being tested
    my $pid = open3( my $in_fh, my $out_fh, my $err_fh = gensym, @command );

    # If we've been given input, feed it to the command
    print $in_fh $params{'input'}
        if ( exists $params{'input'} );

    # Slurp the output
    my @error_output = <$err_fh>;
    my @command_output = <$out_fh>;

    # Wait for the program to exit and get the return value
    my $getpid = waitpid($pid, WNOHANG);
    my $retval = $? / 256;

    my $stdout = join '', @command_output;
    my $stderr = join '', @error_output;

    # Did we get the expected return value?
    if ( $retval != $expected_return ) {
        my $args_list = join "\n", map { "        $_" } @command;

        die << "__INCORRECT_RETURN__";
$test_name FAILED: Unexpected return value
    Expected: $expected_return
    Got: $retval
    Command and parameters:
$args_list
__INCORRECT_RETURN__
    }

    # Did we get the expected stdout?
    if ( $stdout ne $expected_stdout ) {
        my $args_list = join "\n", map { "        $_" } @command;

        if ( $escape_output ) {
            $expected_stdout =~ s/\\/\\\\/g; #escape backslashes
            $expected_stdout =~ s/\$/\\\$/g; #escape dollar
            $expected_stdout =~ s/\x1b/\\x1b/g; #escape ESC
            $stdout =~ s/\\/\\\\/g; #escape backslashes
            $stdout =~ s/\$/\\\$/g; #escape dollar
            $stdout =~ s/\x1b/\\x1b/g; #escape ESC
        }

        die << "__INCORRECT_OUTPUT__";
$test_name FAILED: Unexpected output
    Expected:
$expected_stdout
    Got:
$stdout
    Command and parameters:
$args_list
__INCORRECT_OUTPUT__
    }

    # Did we get the expected stderr?
    if ( $stderr ne $expected_stderr ) {
        my $args_list = join "\n", map { "        $_" } @command;

        die << "__INCORRECT_ERRORS__";
$test_name FAILED: Unexpected errors
    Expected:
$expected_stderr
    Got:
$stderr
    Command and parameters:
$args_list
__INCORRECT_ERRORS__
    }

    return;
}

sub do_testing {
    my $DIR_ROOT = shift @ARGV;
    my $CCSV = "$DIR_ROOT/ccsv.pl";
    my $TEST_ROOT = "$DIR_ROOT/test";

    my @tests_to_run = @ARGV;

    # If specific tests were not given, run everything
    if ( scalar @tests_to_run == 0 ) {
        @tests_to_run = ( 'all' );
    }

    my %test_macros = ( 'all' => ['sanity','errors'],
                        'sanity' => ['sanity-single_file',
                                     'sanity-single_file_header',
                                    ],
                        'errors' => ['errors-invalid_csv'],
                      );

    my %tests = ( 'sanity-single_file' => { command => $CCSV,
                                            args    => ["$TEST_ROOT/basic.csv"],
                                            expected_stdout => <<"__STDOUT__",
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[37m a \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m b \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m c \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 1 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 2 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 3 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 4 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 5 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 6 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 7 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 8 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 9 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
__STDOUT__
                                          },
                  'sanity-single_file_header' => { command => $CCSV,
                                                   args    => ["$TEST_ROOT/basic.csv",'-h'],
                                                   expected_stdout => <<"__STDOUT__",
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[47m\x1b[29;25;24;23;22m\x1b[30m a \x1b[47m\x1b[29;25;24;23;22m\x1b[30m|\x1b[47m\x1b[29;25;24;23;22m\x1b[30m b \x1b[47m\x1b[29;25;24;23;22m\x1b[30m|\x1b[47m\x1b[29;25;24;23;22m\x1b[30m c \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 1 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 2 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 3 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 4 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 5 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[36m 6 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
\x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 7 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 8 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m|\x1b[40m\x1b[29;25;24;23;22m\x1b[37m 9 \x1b[40m\x1b[29;25;24;23;22m\x1b[37m\x1b[0m
__STDOUT__
                                          },
                  'errors-invalid_csv' => { command         => $CCSV,
                                            args            => ["$TEST_ROOT/invalid.csv"],
                                            expected_return => 1,
                                            expected_stderr => "End of file or maximum parse length reached without finding a valid row starting at line 2 and aborted at line 4.\n",

                                          },
                );

    while ( @tests_to_run ) {
        # Fetch the next test to run
        my $test_name = shift @tests_to_run;

        # If it's a macro, expand it and push those tests into the queue
        if ( exists $test_macros{$test_name} ) {
            print "expanded macro '$test_name'\n"
                if ( $verbose );
            unshift @tests_to_run, @{ $test_macros{$test_name} };
            next;
        }

        # Otherwise run the test
        print "Running $test_name: "
            if ( $verbose );
        run_test( name => $test_name,
                  %{ $tests{$test_name} }
                );
        print "OK\n"
            if ( $verbose );
    }
}

