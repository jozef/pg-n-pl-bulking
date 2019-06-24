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

cmp_ok( testlib->truncate_all(), '==', 0, 'table truncate' );

my $chunk_size = 100;
testlib->insert_or_update_row(\&insert_or_update);
testlib->test_table_dump;

done_testing();

sub insert_or_update {
    my ($row_data)  = @_;
    state $data_chunk = [];
    state $idents = {};
    if ($row_data) {
        my @bind_params = @$row_data{qw(title num meta ident)};
        push(@$data_chunk, \@bind_params);
        $idents->{$row_data->{'ident'}} = ();
    }

    # process chunk
    if ((!$row_data || @$data_chunk >= $chunk_size) && @$data_chunk) {
        my @list_of_idents = keys(%$idents);
        my %existing = map {$_ => 1} @{
            $dbh->selectcol_arrayref(
                'select ident from pg_n_pl_bulking where ident in ('
                    . join(',', map {'?'} (1 .. scalar(@list_of_idents))) . ')',
                {Columns=>[1]}, @list_of_idents
            )
        };

        while (my $bind_params = shift(@$data_chunk)) {
            my $ident = $bind_params->[-1];
            if ($existing{$ident}) {
                $dbh->do('UPDATE pg_n_pl_bulking SET title=?,num=?,meta=? WHERE ident=?',
                    {}, @$bind_params);
            }
            else {
                $dbh->do('INSERT INTO pg_n_pl_bulking (title,num,meta,ident) VALUES (?,?,?,?)',
                    {}, @$bind_params);
                $existing{$ident} = 1;
            }
        }

        @$data_chunk = ();
        %$idents = ();
    }
}

__END__

=head1 NAME

04_insert-data_standard_pre_select_chunks.t - insert/update using single commands

=head1 SYNOPSIS

    prove -v -l t/04_insert-data_standard_pre_select_chunks.t

=cut
