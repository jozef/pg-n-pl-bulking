#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::Most;
use testlib;

use DBI;
use DBD::Pg;
use Path::Class qw(file dir);

my $tsv = testlib->tsv;
my $dbh = testlib->dbh;

cmp_ok(testlib->truncate_all(), '==', 0, 'table truncate');

my $chunk_size = 100;
testlib->insert_or_update_row(\&insert_or_update);
testlib->test_table_dump;

done_testing();

sub insert_or_update {
    my ($row_data) = @_;
    state $data_chunk = 0;
    state $idents     = {};
    $idents->{$row_data->{'ident'}} = $row_data
        if $row_data;

    # process chunk
    if ((!$row_data || (++$data_chunk >= $chunk_size)) && %$idents) {
        my @list_of_idents = keys(%$idents);
        my %existing = map {$_ => 1} @{
            $dbh->selectcol_arrayref(
                'select ident from pg_n_pl_bulking where ident in ('
                    . join(',', map {'?'} (1 .. scalar(@list_of_idents))) . ')',
                {}, @list_of_idents
            )
        };

        my $update = {
            ident => [],
            title => [],
            num   => [],
            meta  => [],
        };
        my @inserts;
        foreach my $row (values %$idents) {
            if ($existing{$row->{'ident'}}) {
                foreach my $key (qw(title num meta ident)) {
                    push(@{$update->{$key}}, $row->{$key});
                }
            }
            else {
                push(@inserts, @{$row}{qw(title num meta ident)});
            }
        }

        if (scalar(@{$update->{ident}})) {
            $dbh->do(
                q{
                UPDATE pg_n_pl_bulking SET
                    title   = data_table.title,
                    num     = data_table.num,
                    meta    = data_table.meta
                FROM
                    unnest(?::text[],?::text[],?::integer[],?::jsonb[])
                        AS data_table(ident,title,num,meta)
                WHERE
                    pg_n_pl_bulking.ident = data_table.ident
                },
                {},
                $update->{ident}, $update->{title}, $update->{num}, $update->{meta},
            );
        }
        if (@inserts) {
            $dbh->do(
                'INSERT INTO pg_n_pl_bulking (title,num,meta,ident) VALUES '
                    . join(',', map {'(?,?,?,?)'} (1 .. scalar(@inserts) / 4)),
                {}, @inserts
            );
        }

        $data_chunk = 0;
        %$idents    = ();
    }
}

__END__

=head1 NAME

04.3_insert-data_standard_pre_select_chunks_multi.t - insert/update using chunk updates and multi value insert

=head1 SYNOPSIS

    prove -v -l t/04.3_insert-data_standard_pre_select_chunks_multi.t

=cut
