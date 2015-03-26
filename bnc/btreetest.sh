#!/bin/bash
(set -o igncr) 2>/dev/null && set -o igncr; # this comment is required
# Above line makes this script ignore Windows line endings, to avoid this error without having to run dos2unix:
#   $'\r': command not found
# As per http://stackoverflow.com/questions/14598753/running-bash-script-in-cygwin-on-windows-7

# btreetest.sh [--iter i] [--verbose] [--xdebug] [--treetype t] [--masternode m] [--port p] [--collectstats]
#    [--recordonly] [--record] [--streamimpl s] [--workload c] [--help] [--debugscript]

let SUCCEEDED=0
let FAILURES=0
let UNSUPPORTED=0
ITERATIONS=1
specificclass="___"
specificworkload="___"
specificstreamimpl="___"
masternode="http://localhost:8002/corfu"
port=9091
verbose="FALSE"
xdebug="FALSE"
collectstats="TRUE"
debugscript="FALSE"
showoutput=0
readmore=1
help=0
record=0
recordonly=0

inform() {
  str=$1
  if [ "$debugscript" == "TRUE" ]; then
    echo $str
  fi
}

usage() {
  echo "BTreeFS benchmark usage:"
  echo "btreetest.sh [--iter i] [--verbose] [--xdebug] [--treetype t] [--masternode m] [--collectstats b] [--recordonly] [--record] [--streamimpl s] [--workload c] [--debugscript] [--help]"
  echo "--iter i:           run each case i times"
  echo "--verbose:          extra output"
  echo "--xdebug:           extreme debug output"
  echo "--masternode m:     master node (default = http://localhost:8002)"
  echo "--port p:           client port (default = 9091)"
  echo "--collectstats b:   collect fine-grain request latency stats (1->collect, 0->don't, default=1)"
  echo "--treetype t:       runs *only* tests for the given list class [CDBLogicalBTree|CDBPhysicalBTree]"
  echo "--record:           record new workloads, in addition to running tests over them (default: use existing traces)"
  echo "--recordonly:       record new workloads, exit"
  echo "--streamimpl s:     use *only* the specified stream implementation [DUMMY|HOP]"
  echo "--workload c:       run *only* the specified workload, rather than all [miniscule|tiny|small|medium|large]"
  echo "--debugscript:      emit script commands to console"
  echo "--help:             prints this message"
}

until [ -z $readmore ]; do
  readmore=
  if [ "x$1" == "x--help" ]; then
    help=1
	shift
	readmore=1
  fi
  if [ "x$1" == "x--masternode" ]; then
    masternode=$2
    inform "masternode = $masternode"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--treetype" ]; then
    specificclass=$2
    inform "run only $specificclass test cases"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--iter" ]; then
    ITERATIONS=$2
    inform "task iterations: $ITERATIONS"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--verbose" ]; then
    verbose="TRUE"
    verboseflags=" -v "
    inform "verbose mode"
	shift
	readmore=1
  fi
  if [ "x$1" == "x--xdebug" ]; then
    xdebug="TRUE"
    xdebugflags=" -x "
    inform "extreme debug mode"
	shift
	readmore=1
  fi
  if [ "x$1" == "x--record" ]; then
    record="TRUE"
    inform "record mode"
	shift
	readmore=1
  fi
  if [ "x$1" == "x--debugscript" ]; then
    debugscript="TRUE"
    inform "script debugging mode"
	shift
	readmore=1
  fi
  if [ "x$1" == "x--recordonly" ]; then
    recordonly="TRUE"
    inform "record *only* mode"
	shift
	readmore=1
  fi
  if [ "x$1" == "x--streamimpl" ]; then
    specificstreamimpl=$2
    inform "specific stream impl = $specificstreamimpl"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--workload" ]; then
    specificworkload=$2
    inform "specific workload = $specificworkload"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--port" ]; then
    port=$2
    inform "port = $port"
	shift
	shift
	readmore=1
  fi
  if [ "x$1" == "x--collectstats" ]; then
    collectstatsparm=$2
    collectstats=" "
    if [ "x$collectstatsparm" == "x1" ]; then
      collectstats=" -S "
    fi
    inform "collectstats = $collectstats"
	shift
	shift
	readmore=1
  fi

done

function getrtflags() {
  local streamlabel=$1
  local __rtflags=$2
  local flags=""
  local verboseflags=""
  local xdebugflags=""
  local statsflags=""
  local streamflags=""
  if [ "$streamlabel" == "HOP" ]; then
	  streamflags="-s 1"
  fi
  if [ "$verbose" == "TRUE" ]; then
	  verboseflags="-v"
  fi
  if [ "$xdebug" == "TRUE" ]; then
	  xdebugflags="-x"
  fi
  if [ "$collectstats" == "TRUE" ]; then
	  statsflags="-S"
  fi
  flags="-m $masternode -p $port $streamflags $verboseflags $xdebugflags $statsflags"
  eval $__rtflags="'$flags'"
}

function getscript() {
  local streamlabel=$1
  local __script=$2
  local sscript=""
  if [ "$streamlabel" == "HOP" ]; then
	  sscript="corfuDBmultiple"
  else
	  sscript="corfuDBsingle"
  fi
  eval $__script="'$sscript'"
}

corfucmd() {
  local ccmd=$1
  local astreamlabel=$2
  getscript $astreamlabel corfuscript
  ./bin/$corfuscript.sh $ccmd > /dev/null 2>$1
}

startcorfu() {
  corfucmd start $1
}

stopcorfu() {
  corfucmd stop $1
}

runtester() {
  local streamimpl=$1
  local args="${@:2}"
  getrtflags $streamimpl rtflags
  startcorfu $streamimpl
  ./bin/corfuDBTestRuntime.sh CorfuDBTester $rtflags $args
  stopcorfu $streamimpl
}

function skipitem() {
  local item=$1
  local specificitem=$2
  local __skip=$3
  if [ "$specificitem" != "___" ]; then
	if [ "$specificitem" != "$item" ]; then
	  shouldskip="TRUE"
    else
      shouldskip="FALSE"
	fi
  fi
  eval $__skip="'$shouldskip'"
}

recordWorkload() {

  local class=$1
  local ops=$2
  local workload=${3}
  local height=${4}
  local fanout=${5}
  local streamimpl=DUMMY
  local initfile=bnc/initfs_$workload.ser
  local wkldfile=bnc/wkldfs_$workload.ser
  local skipit

  skipitem $workload $specificworkload skipit
  if [ "$skipit" == "TRUE" ]; then
    inform "recordWorkload skipping workload=$workload..."
    return
  fi
  runtester $streamimpl -A record -t 1 -n $ops -i $initfile -w $wkldfile -h $height -f $fanout -C $class
}

crashRecoverTest() {

  local class=$1
  local size=${2}
  local crashop=${3}
  local recoverop=${4}
  local stats=${5}
  local threads=${6}
  local streamimpl=${7}
  local run=${8}

  skipitem $class $specificclass skclass
  skipitem $size $specificworkload skwkld
  skipitem $streamimpl $specificstreamimpl skstream
  getstreamflags $streamimpl streamflags
  if [ "$skclass" == "TRUE" ] || [ "$skwkld" == "TRUE" ] || [ "$skstream" == "TRUE" ]; then
    inform "crashRecoverTest skipping $size-$class-t$threads-s$streamlabel-r$run"
    return;
  fi

  ddir=bnc/data
  initops=bnc/initfs_$size.ser
  wlkdops=bnc/wkldfs_$size.ser
  caselbl=$size-$class-t$threads-s$streamlabel-r$run
  crashlog=$ddir/crash-$caselbl.txt
  recoverlog=$ddir/recover-$caselbl.txt
  tputlog=$ddir/btree-tput-$caselbl.csv
  rlatlog=$ddir/btree-reqlat-$caselbl.csv
  runstart="`date +%Y-%m-%d`"
  runtimeparms=CorfuDBTester -m $masternode -p 9091 -s $streamimpl -t $threads $Xverbose $Xdebug $stats
  caseparms=-C $class -i $initops -w $wkldops
  crashcmd="./bin/corfuDBTestRuntime.sh $runtimeparms $caseparms -A crash -z $crashop  > $crashlog"
  recovercmd="./bin/corfuDBTestRuntime.sh $runtimeparms $caseparms -A recover -z $recoverop -L $crashlog > $recoverlog"

  inform "running crash/recover $caselbl:"
  inform "    $crashcmd"
  inform "    $recovercmd"
  startcorfu streamlabel
  ./bin/corfuDBTestRuntime.sh $runtimeparms $caseparms -A crash -z $crashop  > $crashlog
  ./bin/corfuDBTestRuntime.sh $runtimeparms $caseparms -A recover -z $recoverop -L $crashlog > $recoverlog
  stopcorfu streamlabel
  inform "...done"

  echo $runstart: $caselbl >> $ddir/tput-all.csv
  grep TPUT $crashlog $recoverlog >> $ddir/tput-all.csv
  grep TPUT $crashlog $recoverlog > $tputlog
  grep FSREQLAT $crashlog $recoverlog > $rlatlog
  grep FSCMDLAT $crashlog $recoverlog >> $rlatlog
}

if [ "$record" == "TRUE" ] || [ "$recordonly" == "TRUE" ]; then
  echo "recording workloads..."
  recordWorkload CDBLogicalBTree 30 miniscule 4 6
  recordWorkload CDBLogicalBTree 50 tiny 5 10
  recordWorkload CDBLogicalBTree 100 small 7 10
  recordWorkload CDBLogicalBTree 1000 medium 10 12
  recordWorkload CDBLogicalBTree 10000 large 16 20
  if [ "$recordonly" == "TRUE" ]; then
    exit
  fi
fi

DATETIME="`date +%Y-%m-%d`"
echo -e "\nCorfuDB BTreeFS test $DATETIME"
echo -e "-----------------------------------"

for run in `seq 1 $ITERATIONS`; do
for size in miniscule tiny small medium large; do
for class in CDBLogicalBTree CDBPhysicalBTree; do
for streamimpl in DUMMY HOP; do
for threads in 1; do

crashRecoverTest $class $size 20 21 $verbose $xdebug $collectstats $threads $streamimpl $streamlabel $corfustartscript $specificworkload $specificclass $specificstreamimpl $run

done
done
done
done
done