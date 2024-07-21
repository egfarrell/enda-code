
# Enda Farrell 2013
# Enda Farrell 2013
# Enda Farrell 2013
# Enda Farrell 2013

# Purpose:
#   Create the 'pop.in' files needed for plato population runs


# Example Usage:

#   python  create_popin_files.py  pop_input/field1_central_stripe

#   this will create loads of 'pop.in' files inside 
#   the folder 'pop_input/field1_central_stripe'
    


# In[]:

import sys, os 
import getopt
import errno
import numpy as np


# array index for CCD corners
BOT_RIGHT = 0
TOP_RIGHT = 1
TOP_LEFT  = 2
BOT_LEFT  = 3

# array index for latitude/longitude coords
IDX_LON = 0
IDX_LAT = 1


# In[]:

def make_folder_parents(path):
    # make a new folder,
    # but also make any higher level 
    # folders in the path as needed
    try:
        os.makedirs(path)

    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else: raise


def make_folder(folder_name):
    # Make a new folder
    if not os.path.exists(folder_name):
        os.mkdir(folder_name)



def create_grid(start_lon, 
                start_lat, 
                num_squares_lon, 
                num_squares_lat, 
                square_width_deg, 
                square_height_deg):

    # Create a coordinate grid of squares 

    # Assume the starting longditude
    # and latitude are positioned in the
    # bottom left-hand corner of the grid.


    # how big is the grid?
    total_squares = num_squares_lon * num_squares_lat


    # initialise empty grid
    grid_array = np.zeros((total_squares, 4, 2))


    current_square = 0
    current_lon    = start_lon
    current_lat    = start_lat



    # start at a certain latitude
    for y in range(num_squares_lat):

        # do all fields along the the longditude
        for x in range(num_squares_lon):

            # define 4 corners making up the current grid_array square
            grid_array[current_square, BOT_RIGHT, IDX_LON] = (current_lon + square_width_deg)
            grid_array[current_square, BOT_RIGHT, IDX_LAT] = (current_lat)

            grid_array[current_square, TOP_RIGHT, IDX_LON] = (current_lon + square_width_deg)
            grid_array[current_square, TOP_RIGHT, IDX_LAT] = (current_lat + square_height_deg)

            grid_array[current_square, TOP_LEFT,  IDX_LON] = (current_lon)
            grid_array[current_square, TOP_LEFT,  IDX_LAT] = (current_lat + square_height_deg)

            grid_array[current_square, BOT_LEFT,  IDX_LON] = (current_lon)
            grid_array[current_square, BOT_LEFT,  IDX_LAT] = (current_lat)

            # Move on to next square
            current_lon    += square_width_deg
            current_square += 1
            
            
        # Finished all squares at this latitude.
        # Move up to the next latitude,
        # and move back to start of the longditude "row"
        current_lat += square_height_deg
        current_lon = start_lon


    # all finished
    return (total_squares, grid_array)





# In[]:


def write_popin_file(star_type_folder, num_squares, binaryClass, disk, 
                     sfr, scaleR, scaleZ, isSingle, grid, 
                     ext, imfType, imr, colourCorrect, bFrac):

        # magnitudes
        min_mag = 0.0
        max_mag = 26.0 # PLATO needs to go very faint


        # make folder e.g. pop_b_o
        make_folder(star_type_folder)


        # write out a pop.in file for each grid square
	for each_square in range(0, num_squares):

		square_folder = os.path.join(star_type_folder, str(each_square+1))
		make_folder(square_folder)


		with open(os.path.join(square_folder, "pop.in"), "w") as f:

                        print 'creating: ' + os.path.join(square_folder, "pop.in")

			f.write('# Binary class\n')
			f.write(str(binaryClass) + '\n')
			f.write('# BiSEPS input model' + '\n')		
			f.write('1' + '\n')
                        f.write('# 1. Star formation: Starburst (burst) or continuous (ctu), 2. disk: young or old ,  3. star formation rate' + '\n')
			f.write('ctu ' + str(disk) + ' ' + str(sfr) + '\n')
                        f.write('# Time bins: Ranges and number of bins ' + '\n')
			f.write('0.0d0 1.5d4 300' + '\n')
			f.write('# Age of the galaxy in Myr' + '\n')
			f.write('13000.0' + '\n')
			f.write('# (R,z) coordinates of the Sun in pc' + '\n')
			f.write('8500.0 30.0' + '\n')
			f.write('# Scale length and height of Galactic disc in pc' + '\n')
			f.write(str(scaleR) + ' ' + str(scaleZ) + '\n')

			f.write('# Ranges (degrees) and number of fields in galactic longitude and latitude' + '\n')

                        min_lon = str(np.min(grid[each_square, :, IDX_LON])) 
                        max_lon = str(np.max(grid[each_square, :, IDX_LON])) 

                        min_lat = str(np.min(grid[each_square, :, IDX_LAT])) 
                        max_lat = str(np.max(grid[each_square, :, IDX_LAT])) 

                        num_fields = 1
			f.write(min_lon + ' ' + max_lon + ' ' + str(num_fields) + '\n')
			f.write(min_lat + ' ' + max_lat + ' ' + str(num_fields) + '\n')

			f.write('# Want transits yes=1, are we on single stars yes=1,numTransits' + '\n')
			f.write('0 ' + str(isSingle) + ' 30' + '\n')

			f.write('# Min and max mag to run over' + '\n')
			f.write(str(min_mag) + ' ' + str(max_mag) + '\n')

                        corner_coords_lon = str(grid[each_square, BOT_RIGHT, IDX_LON]) + ' ' + \
                                            str(grid[each_square, TOP_RIGHT, IDX_LON]) + ' ' + \
                                            str(grid[each_square, TOP_LEFT,  IDX_LON]) + ' ' + \
                                            str(grid[each_square, BOT_LEFT,  IDX_LON]) 

                        corner_coords_lat = str(grid[each_square, BOT_RIGHT, IDX_LAT]) + ' ' + \
                                            str(grid[each_square, TOP_RIGHT, IDX_LAT]) + ' ' + \
                                            str(grid[each_square, TOP_LEFT,  IDX_LAT]) + ' ' + \
                                            str(grid[each_square, BOT_LEFT,  IDX_LAT]) 

			f.write(corner_coords_lon + '\n')
			f.write(corner_coords_lat + '\n')

                        # f.write(str(grid[i,0,0]) + ' ' + str(grid[i,1,0]) + ' ' + str(grid[i,2,0]) + ' ' + str(grid[i,3,0]) + '\n')
                        # f.write(str(grid[i,0,1]) + ' ' + str(grid[i,1,1]) + ' ' + str(grid[i,2,1]) + ' ' + str(grid[i,3,1]) + '\n')

                        # Extinction type(h,k,d), IMF type, imr, colourCorrect, binary fraction
			f.write(str(ext) + ' ' + str(imfType) + ' ' + str(imr) + ' ' + str(colourCorrect) + ' ' + str(bFrac) + '\n')
			f.close()



# In[]:


if __name__ == "__main__":

    opts, args = getopt.getopt(sys.argv,'')

    # Check command-line arguments
    # args[0] is always the name of the script
    if len(args) < 2:
        print "You must specify an output folder."
        print "Exiting..."
        sys.exit()
    else:
        output_folder = str(args[1])


    if os.path.exists(output_folder):
        print "This output folder exists already"
        print "Exiting..."
        sys.exit()
    else:
        # Create an output folder
        make_folder_parents(output_folder)


    # create grid 1x1 deg
    squares, grid_array = create_grid(start_lon=65, 
                                      start_lat=15, 
                                      num_squares_lon=1, 
                                      num_squares_lat=50, 
                                      square_width_deg=1, 
                                      square_height_deg=1)


    # # create grid 5x5 deg
    # squares, grid_array = create_grid(start_lon=40, 
                                      # start_lat=15, 
                                      # num_squares_lon=10, 
                                      # num_squares_lat=10, 
                                      # square_width_deg=5, 
                                      # square_height_deg=5)


    # # create grid 10x10 deg
    # squares, grid_array = create_grid(start_lon=40, 
                                            # start_lat=15, 
                                          # num_squares_lon=5, 
                                          # num_squares_lat=5, 
                                          # square_width_deg=10, 
                                          # square_height_deg=10)

    # initial mass function (imf):
    # 'k' - kroupka imf
    # 'l' - log normal imf
    # 'e' - exponential IMF from Chabrier 2001
    imf        = 'k'

    # Drimmel extinction
    extinction = 'd'

    # Fraction of Binary systems
    bin_frac   = 0.5



    stars_young  = os.path.join(output_folder, 'pop_s_y')
    stars_old    = os.path.join(output_folder, 'pop_s_o')
    binary_young = os.path.join(output_folder, 'pop_b_y')
    binary_old   = os.path.join(output_folder, 'pop_b_o')


    write_popin_file(stars_young,  num_squares=squares, binaryClass=3, disk='young', sfr=3000.0, scaleR=2800.0, scaleZ=300.0,  isSingle=1, grid=grid_array, ext=extinction, imfType=imf, imr=0.0, colourCorrect=0.88, bFrac=bin_frac)
    write_popin_file(stars_old,    num_squares=squares, binaryClass=3, disk='old',   sfr=3000.0, scaleR=3700.0, scaleZ=1000.0, isSingle=1, grid=grid_array, ext=extinction, imfType=imf, imr=0.0, colourCorrect=0.88, bFrac=bin_frac)
    write_popin_file(binary_young, num_squares=squares, binaryClass=2, disk='young', sfr=3000.0, scaleR=2800.0, scaleZ=300.0,  isSingle=0, grid=grid_array, ext=extinction, imfType=imf, imr=0.0, colourCorrect=0.88, bFrac=bin_frac)
    write_popin_file(binary_old,   num_squares=squares, binaryClass=2, disk='old',   sfr=3000.0, scaleR=3700.0, scaleZ=1000.0, isSingle=0, grid=grid_array, ext=extinction, imfType=imf, imr=0.0, colourCorrect=0.88, bFrac=bin_frac)
