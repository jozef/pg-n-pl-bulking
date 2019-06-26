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
testlib->test_table_dump;

done_testing();

sub insert_or_update {
    my ($row_data) = @_;
    return unless $row_data;
    my @bind_params = @$row_data{qw(title num meta ident)};

    state $sth_d = $dbh->prepare('DELETE FROM pg_n_pl_bulking WHERE ident=?');
    state $sth_i = $dbh->prepare('INSERT INTO pg_n_pl_bulking (title,num,meta,ident) VALUES (?,?,?,?)');

    $sth_d->execute($row_data->{ident});
    $sth_i->execute(@bind_params);
}

__END__

=head1 NAME

03_insert-data_standard.t - do basic update and inserts statements

=head1 SYNOPSIS

    prove -l -v t/03_insert-data_standard.t

=cut
