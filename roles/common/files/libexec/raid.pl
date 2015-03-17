#!/usr/bin/perl

use strict;

my $warn;
my $crit;
my $out;

my @out;
my $devices;
my $pci;
my $scsi;
my $derp;

$pci = `/usr/bin/lspci | /bin/grep -i raid | /bin/grep -v PATA | /usr/bin/head -2`;
$scsi = `/usr/bin/lspci | /bin/grep -i scsi | /bin/grep -v PATA | /usr/bin/head -1`;

# software raid!
if (-e "/proc/mdstat") {
    # check software raid!
#    open(R,"/tmp/mdstat");
    open(R,"/proc/mdstat");
    while (<R>) {
		if (/^(md\d+) : (\w+)/) {
			my $dev = $1;
			my $status = $2;
			my $rest = <R>;
			$devices++;
			
			my ($disks,$states) = $rest =~ /(\[.*\]) (\[.*\])/;
			my $mout .= "$dev is $status $disks $states" if $states =~ /_/;
			
			# recovery?
			my $next = <R>;  # possibly recovery?
			if ($next =~ / recovery = /) {
				my ($progress,$per) = $next =~ /(\[.*\])\s+recovery =\s+(\S+%)/;
				$mout .= " recovery $per";
				my $next = <R>;
				if (my ($finish,$speed) = $next =~ /finish=(.*)min speed=(.*)\/sec/) {
					$mout .= " finish $finish min";
				}
				$warn = 1;
            } elsif ($next =~ / resync = /) {
                my ($progress,$per) = $next =~ /(\[.*\])\s+resync =\s+(\S+%)/;
                $mout .= " resync $per";
                if (my ($finish,$speed) = $next =~ /finish=(.*)min speed=(.*)\/sec/) {
                    $mout .= " finish $finish min";
                }
                $warn = 1;
			} elsif ($states =~ /_/) {  # not all U
				$crit = 1;
			}
			
			push( @out, $mout ) if $mout;
		}
    }
}


# mylex raid!
if ($pci =~ /Mylex/i) {
#if (1) {
    my $s = `cat /proc/rd/status`;
    chomp($s);
    unless ($s =~ /OK/) {
	my @myinfo;
	for my $ctl (`ls -d /proc/rd/c*`) {
#	for my $ctl ('/proc/rd/c0') {
	    chomp $ctl;
	    my %bad;
	    my ($c) = $ctl =~ /\/(c\d)$/;
	    open(S,"$ctl/current_status") || print "can't open $ctl/current_status\n";;
#	    open(S,"/tmp/mylex.bad");
	    my $lastdevice;
	    while (<S>) {
		# disk status
		if (/^    (\d:\d)  Vendor/) {
		    $lastdevice = $1;
		}
		if (/ Disk Status: (\S+),/) {
		    if ($1 ne 'Online') {
			push( @myinfo, "$c disk $lastdevice $1");
		    }
		}

		# logical drives
		if (/    (\/dev\/rd\/\S+): (\S+), (\w+),/) {
		    my $dev = $1;
		    my $type = $2;
		    my $status = $3;
		    $devices++;
		    $bad{$dev} = 1;
		    if ($status ne 'Online') {
			push( @myinfo, "$dev ($type) $status");
		    }
		}

		# rebuild?
		if (/  Rebuild in Progress: .* \((\S+)\) (\d+%) completed/) {
		    push( @myinfo, "$1 rebuild $2 complete" );
		    delete $bad{$1};
		}
	    }
	    if (keys %bad) {
		$crit = 1;  # at least 1 is failed and !recovering
	    } else {
		$warn = 1;   # all are recovering
	    }
	}

	push( @out, "Mylex $s: " . join(', ',@myinfo)) if @myinfo;
    }
}


# icp vortex raid!
if ( $pci =~ /intel/i) {
    opendir(D,"/proc/scsi/gdth");
    my @dev = readdir(D);
    closedir D;
    my @vortex;
    for my $dev (@dev) {
	next if $dev =~ /^\./;
	my $read = `cat /proc/scsi/gdth/$dev`;
	# my $read = `cat /tmp/asdf9.warn`;
	my $cur;   # Logical | Physical | Host | Array
	my @myinfo;
#	print "dev $dev\n";
	for $_ (split(/\n/,$read)) {
	    chomp;
	    if (/^\w/) {
		# new section
		($cur) = /^(\w+)/;
#		print "cur = $cur\n";
		next;
	    }
	    if ($cur eq 'Logical') {
		my ($num,$status) = /Number:\s+(\d+)\s+Status:\s+(\w+)/;
		next unless $status;
		if ($status ne 'ok') {
		    $warn = 1;
		    #push( @myinfo, "Logical #$num $status" );
		    unshift( @myinfo, "Logical #$num $status" );
		}
	    }
	    if ($cur eq 'Array') {
		my ($num,$status) = /Number:\s+(\d+)\s+Status:\s+(\w+)/;
		next unless $status;
		if ($status ne 'ready') {
		    $warn = 1;
		    #push( @myinfo, "Array #$num $status" );
		    unshift( @myinfo, "Array #$num $status" );
		}
	    }
	    if ($cur eq 'Host') {
		if (/Number/) {
		    $devices++;
		}
	    }
	    if ($cur eq 'Controller') {
		# push( @myinfo, $_ );
		unshift( @myinfo, $_ );
	    }
	}
	
	if (@myinfo) {
	    # push( @vortex, "dev $dev: " . join(', ', @myinfo) );
	    # unshift( @vortex, "dev $dev: " . join(', ', @myinfo) );
	    push( @vortex, "dev $dev: " . join(', ', $myinfo[0], $myinfo[1], $myinfo[2], $myinfo[3], $myinfo[4] ) );
	    # $warn = 1;
	}
    }

    if (@vortex) {
	# push( @out, 'Vortex: ' . join('.   ', @vortex) );
	push( @out, 'Vortex: ' . join('.   ', @vortex) );
    }
}
# SAS megaraid
if ( $pci =~ /LSI\ Logic/i) {
    my $read = `/usr/bin/sudo /usr/sbin/megacli -LDInfo -lall -a0`;
    for $_ (split(/\n/,$read)) {
    	chomp;
	# The line we care about is State: Optimal, if we don't have that, we've problems
	if ($_ =~/^State\s*\:\s*(.*)/m) {
            $devices++;
	    #/^State\?:\s?(\w+)/;
	    my $state = $1;
	    next unless $state;
	    if ($state ne 'Optimal') {
		my $rebuild = `/usr/bin/sudo /usr/sbin/megacli -PDList -a0 | /bin/grep -i firmware`;
			if ( $rebuild =~ /Rebuild/i) {
				my $enclosure = `/usr/bin/sudo /usr/sbin/megacli -PDList -a0 | /bin/grep -B15 Rebuild | /bin/grep -e Enclosure -e Slot | /usr/bin/cut -d':' -f2 | /usr/bin/awk '{printf \$1\":\"}' | /usr/bin/awk -F ":" '{printf \$1":"\$2}'`;
				#my $rebuildstatus = `/usr/bin/sudo /usr/sbin/megacli -PDRbld -ShowProg -PhysDrv\[$enclosure\] -a0 | /bin/grep -i rebuild`;
				my $rebuildstatus = `/usr/bin/sudo /usr/sbin/megacli -PDRbld -ShowProg -PhysDrv\[$enclosure\] -a0 | /bin/egrep -i \'\(rebuild\|not found\)\'`;
				if ($rebuildstatus =~ /not found/m) {
				   # check by device id instead of enclosure id if we get a not found error above
				   $enclosure = `/usr/bin/sudo /usr/sbin/megacli -PDList -a0 | /bin/grep -B15 Rebuild | /bin/grep -e Enclosure -e Slot | /bin/grep -v position | /usr/bin/cut -d':' -f2 | /usr/bin/awk '{printf \$1\":\"}' | /usr/bin/awk -F ":" '{printf \$1":"\$2}'`;
				   $rebuildstatus = `/usr/bin/sudo /usr/sbin/megacli -PDRbld -ShowProg -PhysDrv\[$enclosure\] -a0 | /bin/grep -i rebuild`;
				}
					for $_ ($rebuildstatus) {
					$crit = 1;
					push(@out,$_);
					}
			} else {
	        $crit = 1;
                my $virtual=`/usr/bin/sudo /usr/sbin/megacli -LDInfo -lall -a0 | grep -i failed -B6 | grep -i virtual | cut -d'(' -f1`;
		push(@out, $virtual, $_);
		}
	    }
	}	
        # Should to catch the syntax or permissions errors this thing spits out
	if (/ERROR/i) {
	    $crit = 1;
	    push(@out, $_);
	foreach my $k (@out)
	{
		print $_;
	}
	}
    }
}

# e3ware
if ( $pci =~ /3ware/i) {
	open(CLI,"/usr/bin/sudo /usr/sbin/tw_cli show|");
	#my $read = `/usr/sbin/megacli -LDInfo -l0 -a0`;

	$devices++;
	my @controllers;
	while (<CLI>) {
		if ( $_ =~ /^c[0-9]/ ) {
			my ($c) = split(/\s+/,$_);
			push(@controllers,$c);
		}
	}
	close(CLI);

	foreach my $cont (@controllers) {
		open(CLI,"/usr/bin/sudo /usr/sbin/tw_cli /$cont show|");
		while (<CLI>) {
			if ( $_ =~ /^u[0-9]+/ ) {
				my @info = split(/\s+/,$_);
				if ( $info[2] ne 'OK' ) {
					if ( $info[2] =~ /REBUILDING/i) {
						my $rebuildstatus = `/usr/bin/sudo /usr/sbin/tw_cli /$cont/$info[0] show | /bin/grep REBUILD | /bin/grep -v RAID-10`;
							for $_ ($rebuildstatus) {
							$crit = 1;
							push(@out,$_);
							}
					} else {
					$crit = 1;
					push(@out,$_);
					}
				}
			}
			if ( $_ =~ /^p[0-9]+/ ) {
				my @info = split(/\s+/,$_);
				if ( $info[1] ne 'OK' ) {
					$crit = 1;
					push(@out,$_);
				}
			}
		}
	}	
}

#Areca

if ( $pci =~ /areca/i) {
                open(CLI,"sudo /usr/sbin/cli64 vsf info|");
                while (<CLI>) {
                        if ( $_ =~ /^\ \ [0-9]+/ ) {
				$devices++;
                                my @info = split(/\s+/,$_);
				if ( $_ !~ /Normal/i) {
                                        $crit = 1;
                                        push(@out,$_);
                                }
                        }
                }
        }

if ( $scsi =~ /LSI Logic/i) {
                open(CLI,"sudo /usr/sbin/mpt-status | /usr/bin/head -1 |");
                $devices++;
                while (<CLI>) {
                        if ( $_ =~ /^ioc/ ) {
                                my @info = split(/\s+/,$_);
                                if ( $info[10] ne 'OPTIMAL,' ) {
                                        $crit = 1;
                                        push(@out,$_);
                                }
                        }
                }
        }

# show results
my $result = 0;
$result = 1 if $warn;
$result = 2 if $crit;
# print "warn = $warn crit = $crit\n";
print $derp;
my $out = "No raid devices found $pci";
$out = "All $devices raid devices happy as clams" if $devices;
if (@out) {
    $out = join(';     ', @out);  
}

print "$out\n";
exit $result;
