#!/usr/bin/perl

#******************************************************************************************
#
# NRPE DISK USAGE PLUGIN
#
# Program: Disk Usage plugin written to be used with Netsaint and NRPE
# License: GPL
# Copyright (c) 2000 Jeremy Hanmer (jeremy@newdream.net)
#
# Last Modified: 10/23/00
# 
# Information:  Basically, I wrote this because I had to deal with large numbers of 
# machines with a wide range of disk configurations, and with dynamically mounted 
# partitions.  The basic check_disk plugin relied on a static configuration file which
# doesn't lend itself to being used in a heterogeneous environnment (especially when
# you can't guarantee that the devices listed in the configuration file will be mounted).
#
# Bugs:  Currently, this plugin only works on EXT2 partitions (although it's easy to change).
#
# Command Line: diskusage.pl <warning percentage> <critical percentage>
#
# Tested Systems:  Mandrake 7.1/Intel, Debian 2.2/Intel, Debian 2.1/Intel
#
# License Information:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#*******************************************************************************************


use strict;

my $wrn = shift @ARGV;
my $crt = shift @ARGV;
my $output;
my $count;
my %type;
my $result = 0;
my $warn = 0;
my $crit = 0;
my @parts;
my $hostname = `hostname`;
chomp $hostname;
@parts = `mount | grep -vi fuse`;

#if ( $hostname eq 'zartan' ) {
#	@parts = `mount`;
#}
#else {
#	@parts = `mount -t ext2,reiserfs`;
#}
for (@parts) {
	my ($dev,$on,$mount,$tp,$type,$options) = split(/\s+/,$_);
		next if ($type eq 'nfs' && !($hostname eq 'zartan'));
		next if ($type eq 'proc' || $type eq 'devpts');
		my @df= `df -k $mount`;
		my @df_inode = `df -i $mount`;
#		print "$dev $mount $type\n";
		shift @df;
		shift @df_inode;
		for(@df) {
			my ($dev1,$blocks,$used,$free,$pc,$mount) = split(/\s+/,$_);
			my ($percent,$blah) = split(/\%/,$pc);
			if ( ($percent >= $wrn ) && (!($percent >= $crt) || ($mount =~ m/\/mnt\//)) ) {
				$output .= "$mount is at $pc    ";
				$warn = 1;
			}
			if ( ($percent >= $crt ) && !($mount =~ m/\/mnt\//) ){
				$output = "" unless $crit eq '1';
				$output .= "$mount is at $pc    ";
				$crit = 1;
			}
		}
		for(@df_inode) {
			my ($dev1,$inodes,$used,$free,$pc,$mount) = split(/\s+/,$_);
			my ($percent,$blah) = split(/\%/,$pc);
			if ( ($percent >= $wrn ) && (!($percent >= $crt) ) ) {
				$output .= "$mount is at $pc inode usage    ";
				$warn = 1;
			}
			if ( ($percent >= $crt ) && !($mount =~ m/\/mnt\//) ){
				$output = "" unless $crit eq '1';
				$output .= "$mount is at $pc inode usage    ";
				$crit = 1;
			}
		}
	}


#if ( ($warn eq '1') && !($crit eq '1') )  {
#	print "$output\n";
#	$result = 1;
#	}
if ( $crit eq '1' ) {
	print "$output\n";
	$result = 2;
}

else {
	print "Disks are OK now\n";
}


#if ( !( $crit eq '1' ) && !( $warn eq '1' ) ) {
#	print "Disks are ok now\n";
#}
#print "$result\n";
exit $result; 
