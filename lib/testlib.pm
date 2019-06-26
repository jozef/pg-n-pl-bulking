#!/usr/bin/perl

package testlib;

use strict;
use warnings;
use 5.010;

use FindBin qw($Bin);
use Path::Class qw(file dir);
use Text::CSV_XS;
use List::MoreUtils qw(zip);
use Test::Most;
use Time::HiRes qw(time);

my $dbh;
my $tsv;
my $tsv_headers;
my $data_files;
my $tmp_dir = dir($Bin, '..', 'tmp');

sub check_pg_9_5 {
    my ($self) = @_;
    plan skip_all => 'needs PostgreSQL server >= 9.5.0 to run (this is '.$self->dbh->{pg_server_version}.')'
        if $self->dbh->{pg_server_version} < 90500;
}

sub dbh {
    return
        $dbh //= DBI->connect( 'dbi:Pg:service=pg_n_pl_bulking_db',
                               '', '', { AutoCommit => 1, RaiseError => 1, PrintError => 1 } );
}

sub vacuum_all {
    my ($self) = @_;
    $self->dbh->do(q{vacuum full analyze pg_n_pl_bulking;});
}

sub truncate_all {
    my ($self) = @_;
    $self->dbh->do(q{truncate pg_n_pl_bulking;});
    $self->vacuum_all();
    return $self->count_pg_n_pl_bulking();
}

sub count_pg_n_pl_bulking {
    my ($self) = @_;
    return $self->dbh->selectrow_hashref(q{select count(*) as count from pg_n_pl_bulking})->{count}
}

sub on_tsv_row {
    my ($self, $data_file, $callback) = @_;

    my $tsv_fh = $data_file->{file}->openr;
    my $tsv = $self->tsv;
    my $header_row = $tsv->getline($tsv_fh);
    die $data_file
        unless $header_row;
    my @headers = map { lc($_) } @{$header_row};
    my %feed_data_row;

    my $line_number = 0;
    while (my $line_data = $tsv->getline($tsv_fh)) {
        $line_number++;
        my %row_data = zip(@headers, @{$line_data});
        $callback->(\%row_data);
    }
    return $line_number;
}

sub insert_or_update_row {
    my ($self, $cb) = @_;

    my $t0 = time();
    my $total_count = 0;
    foreach my $dfile ( @{testlib->data_files()} ) {
        my $count = 0;
        my $t1 = time();
        testlib->on_tsv_row(
            $dfile,
            sub {
                my ($row_data) = @_;
                $cb->($row_data);
                $count++;
            }
        );
        $cb->(undef);    # send undef at the end to allow flushing of data chunks
        ok($count, $count.' rows from '.$dfile->{file}->basename.' processed');
        note 'speed '.sprintf('%0.3f', $count/1000/(time-$t1)).'k/s';
        $total_count += $count;
        #$self->vacuum_all;
    }
    ok($total_count, $total_count.' total rows processed');
    diag $total_count.' rows total, speed '.sprintf('%0.3f', $total_count/1000/(time-$t0)).'k/s';
}

sub data_files {
    return $data_files //= [
        {   file  => $tmp_dir->file('01_1k.tsv'),
            count => 1_000,
        },
        {   file  => $tmp_dir->file('02_2k.tsv'),
            count => 2_000,
        },
        {   file  => $tmp_dir->file('03_10k.tsv'),
            count => 10_000,
        },
        {   file  => $tmp_dir->file('04_10k.tsv'),
            count => 10_000,
        },
        #~ {   file  => $tmp_dir->file('05_10k.tsv'),
            #~ count => 10_000,
        #~ },
        #~ {   file  => $tmp_dir->file('06_10k.tsv'),
            #~ count => 10_000,
        #~ },
        #~ {   file  => $tmp_dir->file('07_10k.tsv'),
            #~ count => 10_000,
        #~ },
        #~ {   file  => $tmp_dir->file('04_100k.tsv'),
            #~ count => 100_000,
        #~ },
        #~ {   file  => $tmp_dir->file('05_1m.tsv'),
            #~ count => 1_000_000,
        #~ },
        #~ {   file  => $tmp_dir->file('06_1m.tsv'),
            #~ count => 1_000_000,
        #~ },
        #~ {   file  => $tmp_dir->file('07_1m.tsv'),
            #~ count => 1_000_000,
        #~ },
        #~ {
        #~ file => $tmp_dir->file('06_10m.tsv'),
        #~ count => 10_000_000,
        #~ },
    ];
}

sub tsv {
    return $tsv //= Text::CSV_XS->new(
        { sep_char => "\t", binary => 1, quote_char => '"', quote => '"', escape_char => "\\" } );
}

sub tsv_headers {
    return $tsv_headers //= [qw(ident title num meta)];
}

sub dump_pg_n_pl_bulking_table {
    my ($self) = @_;
    my $table_txt = '';
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare('select ident,title,num,meta from pg_n_pl_bulking order by ident,title,num');
    $sth->execute();
    while (my $row = $sth->fetchrow_arrayref) {
        $table_txt .= join("\t", @$row)."\n";
    }
    return $table_txt;
}

sub table_dump_file {
    return file($Bin, '..', 'tmp', 'test_dump-pg_n_pl_bulking.tsv')
}

sub test_table_dump {
    my ($self) = @_;
    my $dump_file_content = $self->table_dump_file->slurp;
    my $table_content = $self->dump_pg_n_pl_bulking_table;
    ok($dump_file_content eq $table_content, 'table data match '.$self->table_dump_file)
        || file($self->table_dump_file.'_from-last-test')->spew($table_content);
}

1;

__END__

=head1 NAME

testlib - shared functions and variables for pg-n-pl-bulking tests

=cut
