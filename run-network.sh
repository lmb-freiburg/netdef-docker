#######################################################################
# Author: Nikolaus Mayer (2018), mayern@cs.uni-freiburg.de
#######################################################################

#!/usr/bin/env bash

## Fail if any command fails (use "|| true" if a command is ok to fail)
set -e
## Treat unset variables as error
set -u

## Exit with error code
fun__die () {
  exit `false`;
}

## Print usage help
fun__print_usage () {
  printf "###################################################################\n";
  printf "#           Disparity, Optical flow, Scene flow                   #\n";
  printf "###################################################################\n";
  printf "\n";
  printf "Usage: ./run-network.sh -n network [-g gpu] [-v|vv] first-input second-input output\n";
  printf "\n";
  printf "where 'first-input' and 'second-input' are both images, and 'output'\n";
  printf "is an output folder (typically '.' for 'here').\n";
  printf "For disparity estimation, the first/second inputs are the left/right\n";
  printf "camera views. The estimated disparity maps are valid for the first (left)\n";
  printf "camera. For optical flow estimation, the estimated flow maps the first\n";
  printf "input to the second input (i.e. 'first'==t, 'second'==t+1).\n";
  printf "The input files must be within the current directory. All input and\n";
  printf "output filenames will be treated as relative to this directory.\n";
  printf "\n";
  printf "The 'gpu' argument is the numeric index of the GPU you want to use.\n";
  printf "This only makes sense on a multi-GPU system.\n";
  printf "\n";
  printf "By default, only errors are printed. Single verbosity (-v) prints\n";
  printf "debug outputs, and double verbosity (-vv) also prints whatever the\n";
  printf "docker container prints to stdout\n";
  printf "\n";
  printf "Available 'network' values:\n";


  printf "  DispNet3/CSS:             DispNet (ECCV 2018 architecture)\n";
  printf "  DispNet3/css:             DispNet (smaller and faster)\n";
  printf "  DispNet3/CSS-ft-kitti:    DispNet (finetuned for KITTI)\n";
  printf "  FlowNet3/CSS:             FlowNet (ECCV 2018 architecture)\n";
  printf "  FlowNet3/css:             FlowNet (smaller and faster)\n";
  printf "  FlowNet3/CSS-ft-sd:       FlowNet (finetuned for small motions)\n";
  printf "  FlowNet3/CSS-ft-kitti:    FlowNet (finetuned for KITTI)\n";
  printf "  FlowNet3/CSS-ft-sintel:   FlowNet (finetuned for Sintel)\n";
  printf "  FlowNetH/Pred-Merged:     FlowNet with multiple hypotheses\n";
  printf "  FlowNetH/Pred-Merged-SS:  FlowNet with multiple hypotheses\n";
  printf "                            (alternative architecture)\n";
  printf "  FlowNetH/Pred-Merged-FT-KITTI: FlowNet with multiple hypotheses\n";
  printf "                                 (finetuned for KITTI)\n";
  printf "\n";
}

## Parameters (some hardcoded, others user-settable)
GPU_IDX=0;
CONTAINER="lmb-freiburg-netdef";
NETWORK="";
VERBOSITY=0;

## Verbosity-controlled "printf" wrapper for ERROR
fun__error_printf () {
  if test $VERBOSITY -ge 0; then
    printf "%s\n" "$@";
  fi
}
## Verbosity-controlled "printf" wrapper for DEBUG
fun__debug_printf () {
  if test $VERBOSITY -ge 1; then
    printf "%s\n" "$@";
  fi
}

## Parse arguments into parameters
while getopts g:n:vh OPTION; do
  case "${OPTION}" in
    g) GPU_IDX=$OPTARG;;
    n) NETWORK=$OPTARG;;
    v) VERBOSITY=`expr $VERBOSITY + 1`;;
    h) fun__print_usage; exit `:`;;
    [?]) fun__print_usage; fun__die;;
  esac
done
shift `expr $OPTIND - 1`;

## Isolate network inputs
FIRST_INPUT="";
SECOND_INPUT="";
OUTPUT="";
if test "$#" -ne 3; then
  fun__error_printf "! Missing input or output arguments";
  fun__die;
else
  FIRST_INPUT="$1";
  SECOND_INPUT="$2";
  OUTPUT="$3";
fi

## Check if input files exist
if test ! -f "${FIRST_INPUT}"; then
  fun__error_printf "First input '${FIRST_INPUT}' is unreadable or does not exist.";
  fun__die;
fi
if test ! -f "${SECOND_INPUT}"; then
  fun__error_printf "Second input '${SECOND_INPUT}' is unreadable or does not exist.";
  fun__die;
fi


## Check and use "-n" input argument
BASEDIR="/home/netdef/netdef_models";
WORKDIR="";
case "${NETWORK}" in
  DispNet3/css)                  WORKDIR="${BASEDIR}/DispNet3/css";;
  DispNet3/CSS)                  WORKDIR="${BASEDIR}/DispNet3/CSS";;
  DispNet3/CSS-ft-kitti)         WORKDIR="${BASEDIR}/DispNet3/CSS-ft-kitti";;
  FlowNet3/css)                  WORKDIR="${BASEDIR}/FlowNet3/css";;
  FlowNet3/CSS)                  WORKDIR="${BASEDIR}/FlowNet3/CSS";;
  FlowNet3/CSS-ft-sd)            WORKDIR="${BASEDIR}/FlowNet3/CSS-ft-sd";;
  FlowNet3/CSS-ft-kitti)         WORKDIR="${BASEDIR}/FlowNet3/CSS-ft-kitti";;
  FlowNet3/CSS-ft-sintel)        WORKDIR="${BASEDIR}/FlowNet3/CSS-ft-sintel";;
  FlowNetH/Pred-Merged)          WORKDIR="${BASEDIR}/FlowNetH/Pred-Merged";;
  FlowNetH/Pred-Merged-SS)       WORKDIR="${BASEDIR}/FlowNetH/Pred-Merged-SS";;
  FlowNetH/Pred-Merged-FT-KITTI) WORKDIR="${BASEDIR}/FlowNetH/Pred-Merged-FT-KITTI";;
  *) fun__error_printf "Unknown network: ${NETWORK} (run with -h to print available networks)";
     fun__die;;
esac

## (Debug output)
fun__debug_printf "Using GPU:       ${GPU_IDX}";
fun__debug_printf "Running network: ${NETWORK}";
fun__debug_printf "Working dir:     ${WORKDIR}";
fun__debug_printf "First input:     ${FIRST_INPUT}";
fun__debug_printf "Second input:    ${SECOND_INPUT}";
fun__debug_printf "Output:          ${OUTPUT}";

export ;
export 

#source ~/netdef_slim/bashrc;

## Run docker container
#  - "--device" lines map a specified host GPU into the contained
#  - "-v" allows the container the read from/write to the current $PWD
#  - "-w" executes "cd" in the container (each network has a folder)
## Note: The ugly conditional only switches stdout on/off.
if test $VERBOSITY -ge 2; then
  docker run                     \
    --rm                         \
    --runtime=nvidia             \
    --volume "${PWD}:/input:ro"  \
    --volume "${PWD}:/output:rw" \
    --workdir "${WORKDIR}"       \
    --env LMBSPECIALOPS_LIB="/home/netdef/lmbspecialops/build/lib/lmbspecialops.so" \
    --env PYTHONPATH="/usr/local/lib/python3.6/dist-packages:/home/netdef/lmbspecialops/python:/home/netdef" \
    --env CUDA_VISIBLE_DEVICES="${GPU_IDX}" \
    --env PATH="/home/netdef/netdef_slim/tools:$PATH" \
    -it "$CONTAINER" python3 controller.py eval /input/"${FIRST_INPUT}" /input/"${SECOND_INPUT}" /output/"${OUTPUT}"
else
  docker run                     \
    --rm                         \
    --runtime=nvidia             \
    --volume "${PWD}:/input:ro"  \
    --volume "${PWD}:/output:rw" \
    --workdir "${WORKDIR}"       \
    --env LMBSPECIALOPS_LIB="/home/netdef/lmbspecialops/build/lib/lmbspecialops.so" \
    --env PYTHONPATH="/usr/local/lib/python3.6/dist-packages:/home/netdef/lmbspecialops/python:/home/netdef" \
    --env CUDA_VISIBLE_DEVICES="${GPU_IDX}" \
    --env PATH="/home/netdef/netdef_slim/tools:$PATH" \
    -it "$CONTAINER" python3 controller.py eval /input/"${FIRST_INPUT}" /input/"${SECOND_INPUT}" /output/"${OUTPUT}" \
    > /dev/null;
fi

## Bye!
fun__debug_printf "Done!";
exit `:`;

