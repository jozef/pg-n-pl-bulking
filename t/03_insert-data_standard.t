#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::Most;
use testlib;

use DBI;
use DBD::Pg;
use Path::Class qw(file dir);
use Time::HiRes qw(time);

my $tsv = testlib->tsv;
my $dbh = testlib->dbh;

cmp_ok( testlib->truncate_all(), '==', 0, 'table truncate' );

testlib->insert_or_update_row(\&insert_or_update);

testlib->table_dump_file->spew(testlib->dump_pg_n_pl_bulking_table);

done_testing();

sub insert_or_update {
    my ($row_data)  = @_;
    return unless $row_data;
    my @bind_params = @$row_data{qw(title num meta ident)};
    my $updated     = $dbh->do( 'UPDATE pg_n_pl_bulking SET title=?,num=?,meta=? WHERE ident=?',
                            {}, @bind_params );
    $dbh->do( 'INSERT INTO pg_n_pl_bulking (title,num,meta,ident) VALUES (?,?,?,?)',
              {}, @bind_params )
        if $updated == 0;
}

__END__

=head1 NAME

03_insert-data_standard.t - do basic update and inserts statements

=head1 SYNOPSIS

    prove -l -v t/03_insert-data_standard.t

=cut
