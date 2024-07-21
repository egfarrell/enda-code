#!/bin/bash

# Enda Farrell 2013
# Enda Farrell 2013
# Enda Farrell 2013

define_inputs() {

    # setup most basic locations
    USER_DIR="/padata/beta/users/pmr257"
    ROOT_DIR="$USER_DIR/data/plato"


    # set '$RUN_PATH' to
    # location of this script
    this_script=$(readlink -f "$0")
    RUN_PATH=$(dirname "$this_script")


    # git repositories with source code
    CODE_DIR="$USER_DIR/repos/biseps"


    # Where is the PLATO population folder?
    # (It'll search this folder for
    # every 'extract.1' file)
    # PLATO_RUN_DIR="$USER_DIR/data/github_plato/pop_output/field1/run_8" # centre square 1x1 degree
    # PLATO_RUN_DIR="$ROOT_DIR/pop_output/field1/run_2" # centre stripe, 1x1 degree
    PLATO_RUN_DIR="/padata/beta/users/efarrell/data/old_platos/github_plato/pop_output/field1/run_8"
    # Change above directory back when using own information


    # Where will output go?
    OUTPUT_BASE_DIR="$ROOT_DIR/jkt_output"


    # misc folders and filenames
    BINARY_FOLDERS='pop_b_'
    EXTRACT_FILENAME='extract.1'
    SPLIT_FILENAME='split'


    # specify what files we will process

    # e.g. just process grid square 16 only
    # target_pattern="*$BINARY_FOLDERS*16*$EXTRACT_FILENAME*"

    # just process the entire grid
    target_pattern="*$BINARY_FOLDERS*$EXTRACT_FILENAME*"

    # Fortran/Python programs used
    program_coeffs="$CODE_DIR/mag/magLdcGd.py"
    program_depths="$CODE_DIR/jktebop/jktebopGen"
    PROGRAM_SQLITE="$RUN_PATH/sqlite3"

}

main() {

    # Store command-line arguments
    # for use in other functions
    COMMANDLINE_ARGS=("$@")

    # Create global variables pointing
    # to input / output directories
    setup_variables

    # Save a copy
    # to a log file
    record_job_details

    printf "\n\nSetting up Cluster Jobs. Please wait...\n"

    # Find every 'extract' file in PLATO_RUN_DIR
    # and create a cluster job array for each one
    find $PLATO_RUN_DIR -iwholename "$target_pattern" -print | while read EXTRACT_FILE
    do

        # 'extract.1' files are stored
        # in this directory structure:
        #
        # ...plato/pop_output/field1/run_6/POP_B_O/{1..100}/extract.1
        #                                     ↑       ↑         ↑
        #           $BINARY_TYPE  ------------↑       ↑         ↑
        #                                             ↑         ↑
        #                           $GRID_SQUARE -----↑         ↑
        #                                                       ↑
        #                                        EXTRACT_FILE --↑

        # path to 'extract.1' file
        INPUT_DIR=$(dirname "$EXTRACT_FILE")

        # Tip of path holds grid square
        GRID_SQUARE=$(basename "$INPUT_DIR")

        # next folder up is either: 'pop_b_o' or 'pop_b_y'
        BINARY_DIR=$(dirname "$INPUT_DIR")
        BINARY_TYPE=$(basename "$BINARY_DIR")

        # create output folder:
        # may exist already because each grid
        # square run twice, once for each binary type
        OUTPUT_SQUARE_DIR="$OUTPUT_DIR/$GRID_SQUARE"

        if [ ! -d "$OUTPUT_SQUARE_DIR" ]; then
            mkdir "$OUTPUT_SQUARE_DIR"
        fi

        # Split up processing of "extract.1"
        # accross several cluster jobs.
        # (ie figure out $NUM_TASKS)
        split_extract_file $INPUT_DIR

        # How many cluster jobs should we run?
        # -t "{FROM}-{TO}:{STEP}"
        JOB_ARRAY="1-$NUM_TASKS:1"

        # launch cluster job but make
        # sure it waits until previous 'jkt'
        # jobs are finished first...
        job1_name="jkt-$GRID_SQUARE"

        job1_ids=$(qsub -terse  -hold_jid 'jkt*'              \
                  -v CODE_DIR="$CODE_DIR"                     \
                  -v INPUT_DIR="$INPUT_DIR"                   \
                  -v OUTPUT_DIR="$OUTPUT_DIR"                 \
                  -v OUTPUT_SQUARE_DIR="$OUTPUT_SQUARE_DIR"   \
                  -v SPLIT_FILENAME="$SPLIT_FILENAME"         \
                  -v BINARY_TYPE="$BINARY_TYPE"               \
                  -N "$job1_name"                             \
                  -t "$JOB_ARRAY"                             \
                  -o "$CLUSTER_MSGS"                          \
                  calc_depths.sh)

        # Load output into SQLITE database
        # but wait for previous jobs to finish ...
        job2_name="dbload-$GRID_SQUARE"

        job2_ids=$(qsub -terse -hold_jid ${job1_ids%%.*}      \
                   -v CODE_DIR="$CODE_DIR"                    \
                   -v GRID_SQUARE="$GRID_SQUARE"              \
                   -v BINARY_TYPE="$BINARY_TYPE"              \
                   -v OUTPUT_SQUARE_DIR="$OUTPUT_SQUARE_DIR"  \
                   -v PROGRAM_SQLITE="$PROGRAM_SQLITE"        \
                   -N "$job2_name"                            \
                   -o "$CLUSTER_MSGS"                         \
                   db_import.sh)

    done # end loop

    # Finally create indexes on SQLITE database
    # but wait until all 'dbload' jobs are finished
    job3_name="dbindex-all"

    job3_ids=$(qsub -terse -hold_jid 'dbload*'          \
               -v OUTPUT_DIR="$OUTPUT_DIR"              \
               -v PROGRAM_SQLITE="$PROGRAM_SQLITE"      \
               -N "$job3_name"                          \
               -o "$CLUSTER_MSGS"                       \
               db_indexes.sh)

    printf "\n\nUse 'qstat' to check on progress of this job.\n"

}

setup_variables() {

    # Optional argument:
    # Short comment explaining purpose of run.
    COMMENT=${COMMANDLINE_ARGS[0]}

    # The version .NUMBER at end of all files.
    VER=1

    # define location of all input/output files
    # define what portions of the grid we're going to process
    define_inputs

    # Activate useful bash functions. If you
    # cant find a function mentioned in these
    # scripts, its probably in "utility_functions.sh"
    source "$CODE_DIR/common/utility_functions.sh"

    # setup an output directory
    create_output_dir

    # Does everything exist?
    assert_folder_exists    "USER_DIR"            "$USER_DIR"
    assert_folder_exists    "ROOT_DIR"            "$ROOT_DIR"
    assert_folder_exists    "RUN_PATH"            "$RUN_PATH"
    assert_folder_exists    "PLATO_RUN_DIR"       "$PLATO_RUN_DIR"
    assert_folder_exists    "CODE_DIR"            "$CODE_DIR"
    assert_folder_exists    "OUTPUT_DIR"          "$OUTPUT_DIR"
    assert_folder_exists    "CLUSTER_MSGS"        "$CLUSTER_MSGS"
    assert_file_exists      "program_coeffs"      "$program_coeffs"
    assert_file_exists      "program_depths"      "$program_depths"

    # copy the programs that the 'calc_depths.sh' script will use
    cp "$program_coeffs"    "$OUTPUT_DIR"
    cp "$program_depths"    "$OUTPUT_DIR"

    # Helpful info for user
    printf "\nAll output from this job will be in folder: \n%s" "$OUTPUT_DIR"

}

create_output_dir() {

    # make sure base Output directory exists
    if [ ! -d "$OUTPUT_BASE_DIR" ]; then
        mkdir "$OUTPUT_BASE_DIR" --parents
    fi

    # Create actual output folder e.g. 'run_1', 'run_2' etc.
    # All output from this job run will be stored here.
    OUTPUT_DIR=$(increment_folder "$OUTPUT_BASE_DIR"/run_)
    CLUSTER_MSGS="$OUTPUT_DIR/cluster_msgs"

    mkdir "$OUTPUT_DIR"
    mkdir "$CLUSTER_MSGS"

}

record_job_details () {

    # Store info about this job in a log file

    JOB_INFO="$OUTPUT_DIR/job_info.txt"
    LOG_FILE="$RUN_PATH/log.txt"

    echo_job_time                                           >> "$JOB_INFO"
    echo_value  'OUTPUT_DIR'         "${OUTPUT_DIR}"        >> "$JOB_INFO"
    echo_value  'COMMENT'            "${COMMENT}"           >> "$JOB_INFO"
    echo_value  'VER'                "${VER}"               >> "$JOB_INFO"
    echo_value  'RUN_PATH'           "${RUN_PATH}"          >> "$JOB_INFO"
    echo_value  'PLATO_RUN_DIR'      "${PLATO_RUN_DIR}"     >> "$JOB_INFO"
    echo_value  'CODE_DIR'           "${CODE_DIR}"          >> "$JOB_INFO"
    echo_value  'BINARY_FOLDERS'     "${BINARY_FOLDERS}"    >> "$JOB_INFO"
    echo_value  'EXTRACT_FILENAME'   "${EXTRACT_FILENAME}"  >> "$JOB_INFO"
    echo_value  'SPLIT_FILENAME'     "${SPLIT_FILENAME}"    >> "$JOB_INFO"

    show_git_status    "$CODE_DIR/mag"                      >> "$JOB_INFO"
    show_git_status    "$CODE_DIR/plot"                     >> "$JOB_INFO"
    show_git_status    "$CODE_DIR/common"                   >> "$JOB_INFO"
    show_git_status    "$CODE_DIR/jktebop"                  >> "$JOB_INFO"

    insert_log  "${COMMENT}"  "${OUTPUT_DIR}"               >> "$LOG_FILE"

    # make a copy of the scripts
    find "$RUN_PATH" -maxdepth 1 -type f -name '*' -exec cp "{}" "$OUTPUT_DIR" \;

    # make a few copies of the log file
    cp "$LOG_FILE"  "$OUTPUT_DIR"
    cp "$LOG_FILE"  "$OUTPUT_BASE_DIR"

    # record all the extract
    # files we're going to process
    printf "\nThe following files will be processed:\n"       >> "$JOB_INFO"
    find $PLATO_RUN_DIR -iwholename "$target_pattern" -print  >> "$JOB_INFO"
}

split_extract_file() {

    FOLDER="$1"
    echo "Processing folder: $FOLDER"

    # 'extract.dat' in '$FOLDER' is very big.
    # Use unix 'split' to chop it into smaller files
    # each with extension ".000", ".001" etc
    split --lines=20000 \
          --numeric-suffixes \
          --suffix-length=3 \
          "$FOLDER"/extract.$VER  "$FOLDER/$SPLIT_FILENAME."

    # which is final split file?
    LAST_FILE=$(ls -Art "$FOLDER/" | tail -n 1)

    # what number does final split file have?
    # e.g. $SPLIT_FILENAME.007 or $SPLIT_FILENAME.164 etc
    # (and remove leading zeros)
    NUM_SPLIT_FILES=$(echo ${LAST_FILE##*.} | sed 's/^0*//')

    # split files start from "00",
    # but cluster tasks start from "1",
    # so shift up by one...
    NUM_TASKS=$(($NUM_SPLIT_FILES + 1))

    # record details
    printf "\nFolder: %s\nLast file: %s  \nNumber of tasks: %s\n\n" \
           "${FOLDER}"     \
           "${LAST_FILE}"  \
           "${NUM_TASKS}"  \
           >> "$JOB_INFO"

    # Dont create too many jobs!
    if [ "$NUM_TASKS" -gt 100 ];
    then
        echo_value  'Input file too big'     "$FOLDER/extract.$VER"
        echo "$NUM_TASKS cluster tasks would have been created."
        echo "Aborting this run..."
        exit 1
    fi

}

# Validate command-line arguments
if [ "$#" -ne 1 ];
then
    echo "Error! Command-line argument missing."
    echo "Please supply a comment (in quotes) explaining the purpose of this job"
    exit 1
fi

# Kick off the job
main "$@"
