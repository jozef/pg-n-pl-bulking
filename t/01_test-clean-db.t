#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::Most;
use testlib;

use DBI;
use DBD::Pg;
use FindBin qw($Bin);
use Path::Class qw(file dir);
use Time::HiRes qw(sleep);

our $VERSION = '0.01';

my $dbh = testlib->dbh;
ok($dbh, 'connected to Pg:service=pg_n_pl_bulking_db') or die;

subtest 'create_setup_db' => sub {
    my $ddl_file = file($Bin, '..', 'sql', 'ddl.sql');
    $dbh->do($ddl_file->slurp.'');
    ok(1, $ddl_file.' executed');
};


subtest 'insert_update_delete' => sub {
    $dbh->do(q{insert into pg_n_pl_bulking (ident,title,num,meta) values ('i','t',123,'{}');});
    my $row = $dbh->selectrow_hashref(q{select created,updated from pg_n_pl_bulking where ident = 'i'});
    cmp_ok($row->{created}, 'eq', $row->{updated}, 'created eq updated -> on insert');
    sleep(0.01);
    $dbh->do(q{update pg_n_pl_bulking set title = 't2' where ident = 'i';});
    ok(1, 'insert && update');
    $row = $dbh->selectrow_hashref(q{select created,updated from pg_n_pl_bulking where ident = 'i'});
    cmp_ok($row->{created}, 'ne', $row->{updated}, 'created ne updated -> update trigger works');

    cmp_ok(testlib->truncate_all(), '==', 0, 'table truncate');
};

done_testing();


__END__

=head1 NAME

01_test-clean-db.t - test-clean-create database

=head1 DESCRIPTION

Will try to connect to Postgres database pg_n_pl_bulking_db on localhost and (re)create all tables
needed.

=cut
