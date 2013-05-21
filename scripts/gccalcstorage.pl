#!/usr/bin/perl
#################################################################
#
# Name: gccalcstorage.pl process dir indexfile
#
# Description:
#   Use this to make an estimate of the storage requirements
#   for a GotCloud program.
#
# ChangeLog:
#   21 May 2013 tpg   Initial coding
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; See http://www.gnu.org/copyleft/gpl.html
################################################################
use strict;
use warnings;
use Getopt::Long;
use File::Basename;

my($me, $mepath, $mesuffix) = fileparse($0, '\.pl');

my %opts = (
);

Getopt::Long::GetOptions( \%opts,qw(
    help
    verbose
)) || die "Failed to parse options\n";

#   Simple help if requested, sanity check input options
if ($opts{help} || $#ARGV < 1) {
    warn "$me$mesuffix [options] align fastqdir indexfile\n" .
        "  or\n" .
        "$me$mesuffix [options] snpcall|umake indexfile\n" .
        "Use this to make an estimate of the storage requirements for GotCloud.\n" .
        "More details available by entering: perldoc $0\n\n";
    if ($opts{help}) { system("perldoc $0"); }
    exit 1;
}
my $fcn = shift(@ARGV);
if ($fcn =~ /(\S+)\./) { $fcn = $1; }

#-----------------------------------------------------------------
#   Show calculations for the choice
#-----------------------------------------------------------------
if ($fcn eq 'align') {
    print AlignStorage($ARGV[0], $ARGV[1]);
    exit;
}
if ($fcn eq 'snpcall' || $fcn eq 'umake') {
    warn UmakeStorage($ARGV[0]);
    exit;
}

die "Unknown function '$fcn'\n";
exit(1);

#--------------------------------------------------------------
#   AsGB (number)
#
#   Returns a string expressing number as GBs
#--------------------------------------------------------------
sub AsGB {
    return sprintf('%4.2f GB', $_[0]/(1024*1024*1024));
}

#--------------------------------------------------------------
#   AlignStorage (dir, file)
#
#   Returns a string showing the storage requirements for the aligner
#       output of align = 110% * size of FASTQ (bams)
#       temp files of umake = 120% of size of BAMs  (glf)
#       output of umake = 4% of BAMs  (vcf)
#--------------------------------------------------------------
sub AlignStorage {
    my ($dir, $file) = @_;
    my $totsize = 0;
    open(IN,$file) ||
        die "Unable to open file '$file': $!\n";
    $_ = <IN>;                    # Remove header, check it
    if (! /MERGE_NAME/) { die "Index file '$file' did not look correct\n  Line=$_"; }
    my $k = 0;
    while (<IN>) {
        my @c = split(' ',$_);
        my $f = "$dir/$c[1]";
        my @stats = stat($f);
        if (! @stats) { die "Unable to find details on '$f': $!\n"; }
        $totsize += $stats[7];
        $k++;
        $f = "$dir/$c[2]";
        if ($f ne '.') {
            @stats = stat($f);
            if (! @stats) { die "Unable to find details on '$f': $!\n"; }
            $totsize += $stats[7];
            $k++;
        }
    }
    close(IN);
    if (! $k) { die "No FASTQ files were found. This cannot be correct\n"; }

    my $gb = 1.1*$totsize;
    my $s = "File sizes of $k FASTQ input files referenced in '$file' = " . AsGB($gb) . "\n";

    #   Add a bit extra for temp files for the aligner. Use the average size of a FASTQ
    my $bamsize = (1.2*$totsize);
    $s .= "Size of BAMs from aligner will be about " . AsGB($bamsize) . "\n";

    $s .= "Intermediate files from snpcaller will be about " . AsGB($bamsize) . "\n";

    my $vcfsize = .04*$bamsize;
    $s .= "Final VCF output from snpcaller will be about " . AsGB($vcfsize) . "\n";

    $s .= "Be sure you have enough space to hold all this data\n";
    return $s;
}

#--------------------------------------------------------------
#   UmakeStorage (file)
#
#   Returns a string showing the storage requirements for the snpcaller
#       temp files of umake = 120% of size of BAMs  (glf)
#       output of umake = 4% of BAMs  (vcf)
#--------------------------------------------------------------
sub UmakeStorage {
    my ($file) = @_;
    my $bamsize = 0;
    open(IN,$file) ||
        die "Unable to open file '$file': $!\n";
    my $k = 0;
    while (<IN>) {
        #   Input line ~:  HG01055 ALL     /home/tpg/out/e/bams/HG01055.recal.bam
        my @c = split(' ',$_);
        my $f = $c[2];
        my @stats = stat($f);
        if (! @stats) { die "Unable to find details on '$f': $!\n"; }
        $bamsize += $stats[7];
        $k++;
    }
    close(IN);
    if (! $k) { die "No BAM files were found. This cannot be correct\n"; }

    my $s = "File sizes of $k BAM input files referenced in '$file' = " . AsGB($bamsize) . "\n";

    #   Add a bit extra for temp files for the aligner. Use the average size of a FASTQ
    my $tmpsize = (1.2*$bamsize);
    $s .= "Intermediate files from snpcaller will be about " . AsGB($tmpsize) . "\n";

    my $vcfsize = .05*$bamsize;
    $s .= "Final VCF output from snpcaller will be about " . AsGB($vcfsize) . "\n";

    $s .= "Be sure you have enough space to hold all this data\n";
    return $s;
}

#==================================================================
#   Perldoc Documentation
#==================================================================
__END__

=head1 NAME

gccalcstorage.pl - Estimate of the storage requirements for GotCloud

=head1 SYNOPSIS

  gccalcstorage.pl align  /mnt/1000g ePUR1.index

=head1 DESCRIPTION

Use this program as part of the GotCloud applications to calculate
the approximate storage needed for the aligner or snpcaller steps.
This calculates the storage needed and generates messages to that effect.

=head1 OPTIONS

=over 4

=item B<-help>

Generates this output.

=back

=head1 PARAMETERS

=over 4

=item B<process>

Specifies the name of the program for which we calculate storage.
This should be B<align> or B<snpcall>.

=item B<dir>

Specifies the path to a directory which contains either the
B<fastq> or B<bam> files which serve as input to the process above.

=item B<indexfile>

Specifies the path to the index file of inputs to this process.
The fully qualified path to the file will be B<dir>/B<indexfile>.

=back

=head1 EXIT

If no fatal errors are detected, the program exits with a
return code of 0. Any error will set a non-zero return code.

=head1 AUTHOR

Written by Mary Kate Trost I<E<lt>mktrost@umich.eduE<gt>>.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; See http://www.gnu.org/copyleft/gpl.html

=cut

