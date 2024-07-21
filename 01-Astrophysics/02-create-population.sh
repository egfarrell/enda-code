#!/bin/bash

#$ -l s_rt=100:00:00,virtual_free=12G,h_vmem=24G
#$ -m as
#$ -S /bin/bash
#$ -j y
#$ -cwd


# Enda Farrell 2013
# Enda Farrell 2013
# Enda Farrell 2013
# Enda Farrell 2013

main()
{
    # get utility functions.
    # This file is important and contains
    # bash functions used throughout this script.
    source "$CODE_DIR/common/utility_functions.sh"


    # define Fortran/Python executables
    # that this script will use
    program_pop="population"
    program_ranloc="ranLoc"
    program_extract="extract"
    program_mags="makeAllMags.py"


    # define output directories
    # for each star type
    export STARS_YOUNG="$OUTPUT_DIR/pop_s_y/$SGE_TASK_ID"
    export STARS_OLD="$OUTPUT_DIR/pop_s_o/$SGE_TASK_ID"
    export BINARIES_YOUNG="$OUTPUT_DIR/pop_b_y/$SGE_TASK_ID"
    export BINARIES_OLD="$OUTPUT_DIR/pop_b_o/$SGE_TASK_ID"


    # some housekeeping
    validate_variables
    set_python_env  anaconda  "$CODE_DIR"


    # misc variables
    SINGLE=1
    BINARY=0


    # Create a synthetic population of stars
    create_pop  "$STARS_YOUNG"     $BISEPS_DIR/sol     WEBwide_mag.dat.1  WEBwide_kepler.dat.1  $SINGLE
    create_pop  "$STARS_OLD"       $BISEPS_DIR/subSol  WEBwide_mag.dat.1  WEBwide_kepler.dat.1  $SINGLE
    create_pop  "$BINARIES_YOUNG"  $BISEPS_DIR/sol     WEB_mag.dat.1      WEB_kepler.dat.1      $BINARY
    create_pop  "$BINARIES_OLD"    $BISEPS_DIR/subSol  WEB_mag.dat.1      WEB_kepler.dat.1      $BINARY

}



create_pop()
{

    # assign input parameters
    STAR_TYPE_DIR=${1}
    BISEPS_METAL_DIR=${2}
    MAG_FILE=${3}
    KEPLER_FILE=${4}
    STAR_TYPE=${5}



    # Note!
    # we change to the output directory
    # and run everything from there
    cd $STAR_TYPE_DIR
    echo_value 'current output directory' "$STAR_TYPE_DIR"



    debug_msg "starting: $program_pop"

    $OUTPUT_DIR/$program_pop         pop.in \
                                     "$BISEPS_METAL_DIR/" \
                                     > ranPick.dat.$VER \
                                     2> pop.err



    debug_msg "starting sort"

    sort -n         ranPick.dat.$VER > tmp && \
                    mv tmp ranPick.dat.$VER



    debug_msg "starting: $program_ranloc"

    $OUTPUT_DIR/$program_ranloc      ranPick.dat.$VER \
                                     "$BISEPS_METAL_DIR/$MAG_FILE" \
                                     pop.in \
                                     > ranLoc.dat.$VER


    # -- return here if just testing
    # -- number counts from 'population' and 'ranloc'
    # return


    debug_msg "starting: $program_extract"

    $OUTPUT_DIR/$program_extract    ranPick.dat.$VER \
                                    "$BISEPS_METAL_DIR/$KEPLER_FILE" \
                                    > extract.$VER




    debug_msg "starting: $program_mags"

    $PYTHONBIN $OUTPUT_DIR/$program_mags   extract.$VER \
                                           ranLoc.dat.$VER \
                                           $STAR_TYPE  \
                                           > mag.dat.$VER


    debug_msg "finished: $program_mags"

}



validate_variables()
{
    # validate variables
    assert_not_null  "\$VER" "$VER"


    # validate  directories
    assert_folder_exists  "CODE_DIR"       "$CODE_DIR"
    assert_folder_exists  "BISEPS_DIR"     "$BISEPS_DIR"
    assert_folder_exists  "OUTPUT_DIR"     "$OUTPUT_DIR"
    assert_folder_exists  "STARS_YOUNG"    "$STARS_YOUNG"
    assert_folder_exists  "STARS_OLD"      "$STARS_OLD"
    assert_folder_exists  "BINARIES_YOUNG" "$BINARIES_YOUNG"
    assert_folder_exists  "BINARIES_OLD"   "$BINARIES_OLD"


    # validate files
    assert_file_exists    "OUTPUT_DIR/program_pop"      "$OUTPUT_DIR/$program_pop"
    assert_file_exists    "OUTPUT_DIR/program_ranloc"   "$OUTPUT_DIR/$program_ranloc"
    assert_file_exists    "OUTPUT_DIR/program_extract"  "$OUTPUT_DIR/$program_extract"
    assert_file_exists    "OUTPUT_DIR/program_mag"      "$OUTPUT_DIR/$program_mags"
}





# run main function
main
