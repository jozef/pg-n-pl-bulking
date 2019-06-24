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
    my ($self, $data_file_key, $callback) = @_;

    my $tsv_fh = file($self->data_files->{$data_file_key}->{file})->openr;
    my $tsv = $self->tsv;
    my $header_row = $tsv->getline($tsv_fh);
    die $data_file_key
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
    my $data_files = testlib->data_files();
    foreach my $dfile ( sort { $data_files->{$a}->{count} <=> $data_files->{$b}->{count} } keys %$data_files ) {
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
        ok($count, $count.' rows from '.$dfile.' processed');
        note 'speed '.sprintf('%0.3f', $count/1000/(time-$t1)).'k/s';
        $total_count += $count;
    }
    ok($total_count, $total_count.' total rows processed');
    diag 'total speed '.sprintf('%0.3f', $total_count/1000/(time-$t0)).'k/s';
}

sub data_files {
    return $data_files //= {
        '1k.tsv' => {
            file => $tmp_dir->file('1k.tsv'),
            count => 1_000,
        },
        '2k.tsv' => {
            file => $tmp_dir->file('2k.tsv'),
            count => 2_000,
        },
        '10k.tsv' => {
            file => $tmp_dir->file('10k.tsv'),
            count => 10_000,
        },
        '100k.tsv' => {
            file => $tmp_dir->file('100k.tsv'),
            count => 100_000,
        },
        #~ '1m.tsv' => {
            #~ file => $tmp_dir->file('1m.tsv'),
            #~ count => 1_000_000,
        #~ },
        #~ '10m.tsv' => {
            #~ file => $tmp_dir->file('10m.tsv'),
            #~ count => 10_000_000,
        #~ },
        #~ '10m_2.tsv' => {
            #~ file => $tmp_dir->file('10m_2.tsv'),
            #~ count => 10_000_000,
        #~ },
    };
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
    ok($self->table_dump_file->slurp eq $self->dump_pg_n_pl_bulking_table, 'table data match '.$self->table_dump_file);
}

1;

__END__

=head1 NAME

testlib - shared functions and variables for pg-n-pl-bulking tests

=cut
