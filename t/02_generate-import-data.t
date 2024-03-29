#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::Most;
use testlib;

use DBI;
use DBD::Pg;
use Text::CSV_XS;
use JSON::XS qw(encode_json);
use Time::HiRes qw(time);

our $VERSION = '0.01';

my $tsv         = testlib->tsv;
my $tsv_headers = testlib->tsv_headers;

foreach my $dfile (@{testlib->data_files()}) {
    generate_file( $dfile->{file}, $dfile->{count} );
}

done_testing();

sub generate_file {
    my ( $file, $count ) = @_;

    unless ( -e $file ) {
        note( 'generating ' . $file );
        my $fh = $file->openw();
        $tsv->say( $fh, $tsv_headers );
        foreach ( 1 .. $count ) {
            $tsv->say(
                       $fh, [
                          sprintf( '%06d', int( rand(999_999) ) ),
                          'title ' . time(),
                          int( rand(999) ),
                          encode_json( {
                                        timestamp => int( time() ),
                                        garbage =>
                                            join( '.',
                                             ( map { chr( 1 + rand(254) ) } ( 1 .. rand(100) ) ) )
                                      }
                          ),
                       ],
            );
        }
        $fh->close;
    }
    else {
        note( $file . ' already exists' );
    }

    my @lines = $file->slurp;
    is( scalar(@lines), $count + 1, $file . ' with ' . $count . ' lines present' );
    return;
}

__END__

=head1 NAME

02_generate-import-data.t - generate data to be imported to test database

=head1 SYNOPSIS

    prove -l -v t/02_generate-import-data.t

=cut
