#!/bin/bash

source $CSAP_FOLDER/bin/csap-environment.sh

#
#   References:
#   - docker options: https://hub.docker.com/r/severalnines/sysbench/
#   - sysbench scenarios: https://github.com/centminmod/centminmod-sysbench
#
#   Invokation NOtes
#   if invoked from csap-job-run.sh will source csap-environment.sh, which includes all the helper functions and service variables
#   - ref: $CSAP_FOLDER/bin/csap-environment.sh
#   - ref: https://github.com/csap-platform/csap-core/wiki/Service-Definition#runtime-variables
#

print_section "Service Runner: $csapName"



function setup() {

  install_if_needed bc ;
  # print_command "environment variables" "$(env)"
  
	testProfile=${testProfile:-default} ;
  print_two_columns "testProfile" "$testProfile"
  
  
	export timeToRunInSeconds=${timeToRunInSeconds:-120} ;
  print_two_columns "timeToRunInSeconds" "$timeToRunInSeconds"
  
  
	maxPrime=${maxPrime:-100000} ;
  print_two_columns "maxPrime" "$maxPrime"
  
	threadIterations=${threadIterations:-1 2 4 8 16 32 64} ;
  print_two_columns "threadIterations" "$threadIterations"
 


  sysBenchImage=${sysBenchImage:-default} ;
  if [[ "$sysBenchImage" == "default" ]] ; then
    sysBenchImage="csapplatform/sysbench:latest"
    if [[ "$(hostname --long)" == *hostx.yourcompany ]] ; then sysBenchImage="docker-dev-artifactory.yourcompany.com/csapplatform/sysbench" ; fi
  fi ;
  
  print_two_columns "sysBenchImage" "$sysBenchImage"
  
  
  reportsFolder="$csapLogDir/reports" ;
  if ! test -d reportsFolder ; then
    print_two_columns "reportsFolder" "$(mkdir --verbose --parents $reportsFolder)"
  fi ;
  latestLogFile="$reportsFolder/sysbench-latest.log" ;
  print_two_columns "latestLogFile" "$latestLogFile"
  
  
  backup_file $latestLogFile
  
  
  wordPadding=12 ;
  printReportHeader "sysbench cpu tests"
  
  
  local verbose=false ;
  
}

function printReportHeader() {
  
  local testLabel="$*"
  local verbose="false"
  append_file "# generated by cpu-tester.sh" $latestLogFile $verbose
  append_line ""
  append_line ""
  append_line "#"
  append_line "# test: $testLabel"
  append_line "#"
  local headerLine=$(formatLine $wordPadding "threads maxPrime eventsPerSec eventsTotal timeSeconds percentile")
  append_line "$headerLine"
  
}

setup ;



function run_sysbench() {
  
  local containerName="$1"
  shift 1
  local args="$*"
  local dockerParameters="run --name=$containerName --rm=true" ;
  # 
  
  print_command "docker command" "$(echo "docker $dockerParameters \\"; echo "  $sysBenchImage  \\"; echo "  $args" )"
  
  #print_separator "START: $args output"
  print_two_columns "Starting" "output is being captured and will be printed after completion" ;
  local cpuReport=$(docker $dockerParameters  \
    $sysBenchImage $sysBenchCommand $sysBenchConnection \
    $args)
  # | tee $latestLogFile
  print_command "report completed" "$cpuReport"
  #print_separator "COMPLETED: $args output"
  
  local threads=$(find_word_after "threads:" $cpuReport) ;
  
  # remove seconds s
  local totalTime=$(find_word_after "total time:" $cpuReport | sed 's/s//g') ;
  totalTime=$(echo "scale=0;$totalTime/1" | bc --mathlib) ;
  local maxPrime=$(find_word_after "Prime numbers limit:" $cpuReport) ;
  local percentile=$(find_word_after "95th percentile:" $cpuReport) ;
  
  local eventsPerSecond=$(find_word_after "events per second:" $cpuReport) ;
  local eventsTotal=$(find_word_after "total number of events:" $cpuReport) ;
  
  local reportLine=$(formatLine $wordPadding "$threads $maxPrime $eventsPerSecond $eventsTotal $totalTime $percentile")
  print_two_columns "extracted data" "$reportLine"

  append_line "$reportLine"
  

  
}

#
# oltp scenario
#
function cpuTests() {
  
	print_section "cpuTests"
  
	testContainerName="$csapName" ;

# 	local sysBenchOltp="/usr/share/sysbench/tests/include/oltp_legacy/oltp.lua run" ;

  local threadCount
  local sysBenchParams
  
  for threadCount in $threadIterations ; do
	  sysBenchParams="sysbench cpu --time=$timeToRunInSeconds --threads=$threadCount --cpu-max-prime=$maxPrime run" ;
	  
	  
	  run_sysbench "$testContainerName" $sysBenchParams ;
	  
    delay_with_message 60 "Spacing reports to ensure collection result captured"
    
  done ;
  
  delay_with_message 60 "Run Completed - Final Spacing delay"
  
  print_with_date "Test Completed"
}

# /usr/share/sysbench/tests/include/oltp_legacy/csap-oltp.lua

function perform_operation() {

  local startSeconds=$(date +%s) ;
  
	case "$testProfile" in
		
		"cpuTests" | "default")
			cpuTests
			;;
		
		 *)
	            echo "Command Not found"
	            exit 1
	esac
	
	
  local endSeconds=$(date +%s) ;
  print_with_date "Test Completed: $(( ( $endSeconds - $startSeconds) / 60   )) minutes"

}

perform_operation