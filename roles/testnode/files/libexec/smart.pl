#!/usr/bin/perl

# {{ ansible_managed }}

use strict;

my $warn;
my $crit;
my $out;

my @out; # array of output messages
my @failedout; # array of failed drive numbers
my $drives;
my $pci;
my $type;
my $mdadm;
my $fullcommand;
my $message;
my $multiline;

my $hostname = `uname -n`;
chomp $hostname;
my $pci = `lspci | /bin/grep -i raid | /bin/grep -v PATA | /usr/bin/head -1`;

my $smartctl = "/usr/sbin/smartctl";

our $realloc = '50';
our $pend = '1';
our $uncorrect = '1';

# output in human readable and nagios multiline format
if ($ARGV[0] =~ /-m/) {
    $multiline = 1;
}

if ( $hostname =~ /mira/i )
{
	$realloc = '200';
	$pend = '1';
        $uncorrect = '1';
}

unless ( -x $smartctl )
{
	$crit = 1;
	push(@out,"smartmontools package missing or broken");
}


sub smartctl
{
	my $command=$_[0];
	my $raidtype=$_[1];
	my $drive=$_[2];
	my $scsidev=$_[3];

	if ( $raidtype =~ /areca/i )
	{
		$fullcommand = "sudo $command -a -d areca,$drive $scsidev |";
	}
        if ( $raidtype =~ /mdadm/i )
        {
                $fullcommand = "sudo $command -a -d ata /dev/$drive|";
        }
	if ( $raidtype =~ /none/i )
	{
		$fullcommand = "sudo $command -a -d sat /dev/$drive|";
	}

	open(SMART,$fullcommand);
	while (<SMART>)
	{
		if ( $_ =~ /FAILING_NOW/ )
		{
			my @fail = split;
			$message = "Drive $drive is S.M.A.R.T. failing for $fail[1]";
			$crit = 1;
			push(@out,$message);
			push(@failedout,$drive);
		}
	        if (( $_ =~ /_sector/i ) || ( $_ =~ /d_uncorrect/i ))
	        {
	                my @sector = split;
	                if ( $sector[1] =~ /reallocated/i  )
	                {
	                        $type = "reallocated";
	                }
	                if ( $sector[1] =~ /pending/i  )
	                {
	                        $type = "pending";
	                }
                        if ( $sector[1] =~ /d_uncorrect/i  )
                        {
                                $type = "uncorrect";
                        }
	                foreach ( $sector[9] )
	                {
	                        my $count = $_;
				my $l = chr(ord('a') + $drive - 1);
	                        $message = "Drive $drive (sd$l) has $count $type sectors";

	                        if ( ( $type =~ /reallocated/i && $count > $realloc ) && ( $type =~ /pending/i && $count > $pend ) && ( $type =~ /uncorrect/i && $count > $uncorrect  ) )
	                        {
					$crit = 1;
					push(@out,$message);
					push(@failedout,$drive);
	                        }
	                        else
	                        {
					if ( $type =~ /reallocated/i && $count > $realloc )
					{
	        				$crit = 1;
	        				push(@out,$message);
						push(@failedout,$drive);
					}
					if ( $type =~ /pending/i && $count > $pend )
					{
	        				$crit = 1;
	        				push(@out,$message);
						push(@failedout,$drive);
					}
					if ( $type =~ /uncorrect/i && $count > $uncorrect )
					{
						$crit = 1;
						push(@out,$message);
						push(@failedout,$drive);
					}
	                	}
			}
		}
	}
}

# software raid!
if (-e "/proc/mdstat") 
{
	open(R,"/proc/mdstat");
	while (<R>)
	{
		if (/^(md\d+) : (\w+)/)
		{
			$mdadm = $mdadm + 1;
		}
	}
	if ( $mdadm gt 0 )
	{
	 open(BLOCK,"cat /proc/partitions | grep -w sd[a-z] |");
		while (<BLOCK>)
		{
			my @output = split;
			my $blockdevice = $output[3];
			foreach ( $blockdevice )
			{
				$drives++;
				smartctl("$smartctl","mdadm",$blockdevice,"none");
			}
		}
	}
}

#areca hardware raid
if ( $pci =~ /areca/i)
{
	my $firmware = `sudo /usr/sbin/cli64 sys info | grep -i firm | awk '{print \$5}' | cut -d'-' -f1`;
	chomp $firmware;

	if ( $firmware < 2011 )
	{
		$crit = 1;
		$message = "Controller needs newer firmware for S.M.A.R.T. support";
		push(@out,$message);
	}

        open (SG, '/proc/scsi/sg/devices');
	my $sgindex = 0;
	while (<SG>) {
		my ($host, $chan, $id, $lun, $type, $opens, $depth, $busy, $online) = split();
		if ($type == 3) {
			last;
		}
		$sgindex++;
	}
	my $scsidev = "/dev/sg$sgindex";
    if ($multiline) {
        # don't filter out Failed/N.A drives
        open(CLI,"sudo /usr/sbin/cli64 disk info | grep -vi Modelname | grep -v ====== | grep -vi GuiErr |");
    } else {
        open(CLI,"sudo /usr/sbin/cli64 disk info | grep -vi Modelname | grep -v ====== | grep -vi GuiErr | grep -vi Free | grep -vi Failed | grep -vi 'N.A.' |");
    }
	while (<CLI>)
	{
		$drives++;
		if ( $_ =~ /^\ \ [0-9]+/ )
		{
			my @info = split(/\s+/,$_);
			foreach ($info[1])
			{
				my $drive = $_;
				my $status = $info[$#info];
                if ($multiline && ($status =~ /Failed/ || $status =~ /N\.A\./)) {
                    push(@out, "Drive $drive $status");
		    push(@failedout,$drive);
                } else {
                    smartctl("$smartctl","areca",$drive,$scsidev);
                }
			}
		}
	}
}

# assume JBOD/direct access if not areca or hw raid
if ( $mdadm == 0 && $pci !~ /areca/i )
{
	open(BLOCK,"cat /proc/partitions | grep -w sd[a-z] |");
	while (<BLOCK>)
	{
		my @output = split;
		my $blockdevice = $output[3];
		foreach ( $blockdevice )
		{
			$drives++;
			smartctl("$smartctl","none",$blockdevice,"none");
		}
	}
}

# show results
my $result = 0;
$result = 1 if $warn;
$result = 2 if $crit;
# print "warn = $warn crit = $crit\n";

my $out = "No real disks found on machine";
$out = "All $drives drives happy as clams" if $drives;


# count unique num failed drives
my %counts = ();
for (@failedout) {
	$counts{$_}++;
}

my $uniquedrives = 0;
foreach my $keys (keys %counts) {
	$uniquedrives++;
}

# print multiline/nagios output if -m flag used
if ($ARGV[0] =~ /-m/) {
	if (@out) {
		print "$uniquedrives of $drives drives failing/missing |\n";
		foreach my $line (@out) {
			print $line, "\n";
		}
	} else {
		print "$out\n";
	}
} else {
	if (@out)
	{
		# this outputs all messages to one line presumably
		# because nagios < v3.0 couldn't handle multiline output
		$out = join(';     ', @out);
	}

	print "$out\n";
}
exit $result;
