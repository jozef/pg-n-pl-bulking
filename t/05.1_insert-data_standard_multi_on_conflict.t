#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::Most;
use testlib;

use DBI;
use DBD::Pg;
use Path::Class qw(file dir);

testlib->check_pg_9_5;

my $tsv = testlib->tsv;
my $dbh = testlib->dbh;

cmp_ok(testlib->truncate_all(), '==', 0, 'table truncate');

my $chunk_size = 100;
testlib->insert_or_update_row(\&insert_or_update);
testlib->test_table_dump;

done_testing();

sub insert_or_update {
    my ($row_data) = @_;
    state $inserts      = {};
    state $insert_count = 0;
    if ($row_data) {
        my $ident = $row_data->{ident};
        $insert_count++
            if !exists($inserts->{$ident});
        $inserts->{$ident} = [@{$row_data}{qw(title num meta ident)}];
    }

    # process chunk
    if ((!$row_data || ($insert_count >= $chunk_size)) && $insert_count) {
        $dbh->do(
            'INSERT INTO pg_n_pl_bulking (title,num,meta,ident) VALUES '
                . join(',', map {'(?,?,?,?)'} (1 .. $insert_count))
                . ' ON CONFLICT (ident) DO'
                . ' UPDATE SET title=EXCLUDED.title, num=EXCLUDED.num, meta=EXCLUDED.meta',
            {},
            (map {@{$_}} values(%$inserts)),
        );

        %$inserts     = ();
        $insert_count = 0;
    }
}

__END__

=head1 NAME

05.1_insert-data_standard_multi_on_conflict.t - insert/update using chunk updates and multi value insert

=head1 SYNOPSIS

    prove -v -l t/05.1_insert-data_standard_multi_on_conflict.t

=cut
