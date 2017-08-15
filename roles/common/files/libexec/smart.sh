#!/bin/bash
# Description:	Bash script to check drive health using pending, uncorrectable,
# and reallocated sector count
#
# Nagios return codes: 0 = OK; 1 = WARNING; 2 = CRITICAL; 3 = UNKNOWN
# SMART Attribute Codes:
#   5 = Reallocated
#   187 = Reported Uncorrect
#   197 = Pending
#   198 = Uncorrectable Sector Count
#
# TO-DO: Add support for dynamic SMART attribute lookup.  For example,
#        187 is reported for Seagate HDD and all SSDs but not Hitachi HDDs.
#
# See https://en.wikipedia.org/wiki/S.M.A.R.T.#ATA_S.M.A.R.T._attributes

### Define global variables ###
# total number of drives (or RAID slots) discovered
numdrives=0
# Number of failed, failing, and/or missing drives
failingdrives=0
# Fallback message for UNKNOWN return code output
unknownmsg="Unknown error"
# Return code for nagios (Default to SUCCESS)
rc=0
# Location of nvme-cli executable
nvmecli="/usr/sbin/nvme"
# Array of messages indicating drive health.  Output after nagios status.
declare -a messages

### Functions ###
main ()
{
  preflight

  if [ "$raid" = true ]
  then
    areca_smart
    areca_failed
  elif [ "$raid" = false ]
  then
    normal_smart
  else
    echo "ERROR - Could not determine if RAID present"
    exit 3
  fi

  if [ "$nvme" = true ]
  then
    nvme_smart
  fi

  ## Return UNKNOWN if no drives found
  if [ "$numdrives" -eq "0" ]
  then
    unknownmsg="No drives found!"
    rc=3
  fi
  
  ## Return code and service status for nagios
  if [ "$rc" = 0 ]
  then
    echo "OK - All $numdrives drives healthy"
  elif [ "$rc" = 1 ]
  then
    echo "WARNING - $failingdrives of $numdrives drives sick"
  elif [ "$rc" = 2 ]
  then
    echo "CRITICAL - $failingdrives of $numdrives drives need replacing"
  elif [ "$rc" = 3 ]
  then
    echo "UNKNOWN - $unknownmsg"
  else
    echo "ERROR - Got no return code"
  fi
  
  ## Iterate through array of messages
  # Nagios reads and displays the first line of output on the Services page.
  # All individual messages about failed/failing disk statistics can be viewed
  # on the individual system's SMART detail page in nagios.
  for msg in "${messages[@]}"
  do
    echo "$msg"
  done
  
  exit $rc
}

# Pre-flight checks
preflight ()
{
  # Set raid var then check for cli64 command and bail if missing
  if lspci | grep -qi areca
  then
    raid=true
  else
    raid=false
  fi
  
  if [ "$raid" = true ] && ! [ -x "$(command -v cli64)" ]
  then
    echo "ERROR - cli64 command not found or is not executable"
    exit 3
  fi
  
  # Check for smartmontools and bail if missing
  if ! [ -x "$(command -v smartctl)" ]
  then
    echo "ERROR - smartctl is not installed or is not executable"
    echo "yum/apt-get install smartmontools"
    exit 3
  fi

  # Check for nvme devices and nvme-cli executable
  if cat /proc/partitions | grep -q nvme
  then
    nvme=true
    if ! [ -x "$nvmecli" ]
    then
      echo "ERROR - NVMe Device detected but no nvme-cli executable"
      exit 3
    fi
  fi
}

# Gather smart data for drives behind Areca RAID controller
areca_smart ()
{
  # Store output of cli64 to reduce repeated executions
  cli64out=$(sudo cli64 disk info | grep -E "Slot#[[:digit:]]")
  numdrives=$(echo "$cli64out" | wc -l)
  # Loop through all disks not marked as 'N.A.' or 'Failed'
  for slot in $(echo "$cli64out" | grep -v 'N.A.\|Failed' \
  | grep -o "Slot#[[:digit:]]" | cut -c6-)
  do
    failed=false
    # Determine if disk is JBOD or part of hardware RAID
    if echo "$cli64out" | grep -E "Slot#$slot" | grep -q 'JBOD'
    then
      jbod=true
    else
      jbod=false
    fi
    output=$(sudo cli64 disk smart drv=$slot \
    | grep -E "^  "5"|^"197"|^"198"" | awk '{ print $(NF-1) }' | tr '\n' ' ')
    outputcount=$(echo $output | wc -w)
    # Only continue if we received 3 SMART data points
    if [ "$outputcount" = "3" ]
    then
      # Only do slot to drive letter matching once per bad JBOD
      if [[ $output != "0 0 0 " ]] && [ "$jbod" = true ]
      then
        dl=$(areca_bay_to_letter $slot)
      elif [ "$jbod" = false ]
      then
        dl="(RAID)"
      fi
      read reallocated pending uncorrect <<< $output
      if [ "$reallocated" != "0" ]
      then
        messages+=("Drive $slot $dl has $reallocated reallocated sectors")
        failed=true
        # A small number of reallocated sectors is OK
	# Don't set rc to WARN if we were already CRIT from previous drive
        if [ "$reallocated" -le 5 ] && [ "$rc" != 2 ]
        then
          rc=1 # Warn if <= 5
        else
          rc=2 # Crit if >5
        fi
      fi
      if [ "$pending" != "0" ]
      then
        messages+=("Drive $slot $dl has $pending pending sectors")
        failed=true
        rc=2
      fi
      if [ "$uncorrect" != "0" ]
      then
        messages+=("Drive $slot $dl has $uncorrect uncorrect sectors")
        failed=true
        rc=2
      fi
    else
      messages+=("Drive $slot returned $outputcount of 3 expected attributes")
      unknownmsg="SMART data could not be read for one or more drives"
      rc=3
    fi
    # Make sure drives with multiple types of bad sectors only get counted once
    if [ "$failed" = true ]
    then
      let "failingdrives+=1"
    fi
  done
}

# Correlate Areca drive bay to drive letter
areca_bay_to_letter ()
{
  # Get S/N according to RAID controller given argument $1 (slot #)
  areca_serial=$(sudo cli64 disk info drv=$1 | grep 'Serial Number' \
  | awk '{ print $NF }')
  # Loop through and get S/N according to smartctl given drive name
  for dl in $(cat /proc/partitions | grep -w 'sd[a-z]\|sd[a-z]\{2\}' \
  | awk '{ print $NF }')
  do
    smart_serial=$(sudo smartctl -a /dev/$dl | grep "Serial number" \
    | awk '{ print $NF }')
    # If cli64 and smartctl find a S/N match, return drive letter
    if [ "$areca_serial" = "$smart_serial" ]
    then
      echo "($dl)"
    fi
  done
}

# Tally missing and failed drives connected to Areca RAID
areca_failed ()
{
  # Store output of cli64 to reduce repeated executions
  cli64out=$(sudo cli64 disk info | grep -E "Slot#[[:digit:]]")
  # Missing (N.A.) drives
  for drive in $(echo "$cli64out" | grep -E "Slot#[[:digit:]]" \
  | grep "N.A." | awk '{ print $1 }')
  do
    messages+=("Drive $drive is missing")
    let "failingdrives+=1"
    rc=2
  done
  # Hard failed drives
  for drive in $(echo "$cli64out" | grep -E "Slot#[[:digit:]]" \
  | grep 'Failed' | awk '{ print $1 }')
  do
    messages+=("Drive $drive failed")
    let "failingdrives+=1"
    rc=2
  done
}

# Standard SATA/SAS drive smartctl check
normal_smart ()
{
  # The grep regex will include drives named sdaa, for example
  numdrives=$(cat /proc/partitions | grep -w 'sd[a-z]\|sd[a-z]\{2\}' | wc -l)
  for l in $(cat /proc/partitions | grep -w 'sd[a-z]\|sd[a-z]\{2\}' \
  | awk '{ print $NF }')
  do
    failed=false
    output=$(sudo smartctl -a /dev/$l | grep -E "^  "5"|^"197"|^"198"" \
    | awk '{ print $NF }' | tr '\n' ' ')
    outputcount=$(echo $output | wc -w)
    # Check if drive is SSD and set var accordingly
    if sudo smartctl -i /dev/$l | grep -q 'Solid State Device'; then
      is_ssd=true
    else
      is_ssd=false
    fi
    # Only continue if we received 3 SMART data points and drive is not SSD
    if [ "$outputcount" = "3" ] && [ "$is_ssd" = false ]
    then
      read reallocated pending uncorrect <<< $output
      if [ "$reallocated" != "0" ]
      then
        messages+=("Drive $l has $reallocated reallocated sectors")
        failed=true
        # A small number of reallocated sectors is OK
	# Don't set rc to WARN if we were already CRIT from previous drive
        if [ "$reallocated" -le 5 ] && [ "$rc" != 2 ]
        then
          rc=1 # Warn if <= 5
        else
          rc=2 # Crit if >5
        fi
      fi
      if [ "$pending" != "0" ]
      then
        messages+=("Drive $l has $pending pending sectors")
        failed=true
        rc=2
      fi
      if [ "$uncorrect" != "0" ]
      then
        messages+=("Drive $l has $uncorrect uncorrect sectors")
        failed=true
        rc=2
      fi
    elif [ "$outputcount" != "3" ] && [ "$is_ssd" = false ]
    then
      messages+=("Drive $l returned $outputcount of 3 expected attributes")
      unknownmsg="SMART data could not be read for one or more drives"
      rc=3
    # Set no return code and assume any SSD is healthy for now
    elif [ "$is_ssd" = true ]
    then
      messages+=("Drive $l is an SSD.  Not yet supported.")
      rc=0
    else
      messages+=("Error processing data for drive $l")
      rc=3
    fi
    # Make sure drives with multiple types of bad sectors only get counted once
    if [ "$failed" = true ]
    then
      let "failingdrives+=1"
    fi
  done
}

nvme_smart ()
{
  # Loop through NVMe devices
  for nvmedisk in $(sudo $nvmecli list | grep nvme | awk '{ print $1 }')
  do
    # Include NVMe devices in overall drive count
    let "numdrives+=1"
    # Clear output variable from any previous disk checks
    output=""
    output=$(sudo $nvmecli smart-log $nvmedisk | \
             grep -E "^"critical_warning"|^"percentage_used"|^"media_errors"|^"num_err_log_entries"" \
             | awk '{ print $NF }' | sed 's/%//' | tr '\n' ' ')
    outputcount=$(echo $output | wc -w)
    # Only continue if we received 4 SMART data points
    if [ "$outputcount" = "4" ]
    then
      read critical_warning percentage_used media_errors num_err_log_entries <<< $output
      # Check for critical warnings
      if [ "$critical_warning" != "0" ]
      then
        messages+=("$nvmedrive indicates there is a critical warning")
        failed=true
        rc=1
      fi
      # Alert if >= 90% of manufacturer predicted life consumed
      if [ "$percentage_used" -ge 90 ] && [ "$percentage_used" -lt 100 ]
      then
        messages+=("$nvmedisk has estimated $(expr 100 - $percentage_used)% life remaining")
        failed=true
        rc=1 # Warn if >= 90 and < 100
      elif [ "$percentage_used" -ge 100 ]
      then
        messages+=("$nvmedisk has consumed $percentage_used% of its estimated life")
        failed=true
        rc=2 # Crit if > 100
      fi
      # Check for media errors
      if [ "$media_errors" != "0" ]
      then
        messages+=("$nvmedisk indicates there are $media_errors media errors")
        failed=true
        rc=2
      fi
      # Check for error log entries
      if [ "$num_err_log_entries" != "0" ]
      then
        messages+=("$nvmedisk indicates there are $num_err_log_entries error log entries")
        failed=true
        rc=2
      fi
    elif [ "$outputcount" != "4" ]
    then
      messages+=("$nvmedisk returned $outputcount of 4 expected attributes")
      unknownmsg="SMART data could not be read for one or more drives"
      rc=3
    else
      messages+=("Error processing data for $nvmedisk")
      rc=3
    fi
    # Make sure NVMe devices with more than one type of error only get counted once
    if [ "$failed" = true ]
    then
      let "failingdrives+=1"
    fi
  done
}

## Call main() function
main
