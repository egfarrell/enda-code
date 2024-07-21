! E Farrell 2014
! Refactor code for population synthesis
PROGRAM population

	USE distributions
	USE integration
	USE fmods
	USE extinction
	USE params
	USE error
	USE dtypes
	USE polygon
	USE extras
	USE input
	USE randomNum

	IMPLICIT NONE

	INTEGER(8)                              :: i, ii, j, jj, k, kk, nn, mm
	INTEGER                                 :: idx_t1, idx_t2, idx_T_galaxy, z, m, i_step
	INTEGER                                 :: kw1, kw2, bkw
	INTEGER                                 :: nmbr, alloc_status, ioerr
	INTEGER                                 :: lineCount
	INTEGER, PARAMETER                      :: N_DIST  = 5000
	INTEGER, PARAMETER                      :: NUM_LB_SUB = 2

 	DOUBLE PRECISION, DIMENSION(NUM_LB_SUB+1)           :: l0, b0, l0deg, b0deg
	DOUBLE PRECISION                                    :: rdmx
	DOUBLE PRECISION                                    :: pi
	DOUBLE PRECISION                                    :: dd
	DOUBLE PRECISION                                    :: grid_points_mass1, grid_points_mass2, grid_points_A, dVs
	DOUBLE PRECISION                                    :: dt
	DOUBLE PRECISION                                    :: bsn, bsnt, ms1, ms2, Ps
	DOUBLE PRECISION                                    :: rrt1, rrt2, rrd1, rrd2
	DOUBLE PRECISION                                    :: q, a, at, ad, md1, md2, Pd
	DOUBLE PRECISION                                    :: dlon, dlat, delta_d
	DOUBLE PRECISION                                    :: l_mid, b_mid
	DOUBLE PRECISION                                    :: rr1, rr2, f_density_min, f_density_max

	DOUBLE PRECISION                                    :: delta_t, weighting, tmp, minF, diff, newMinF
    DOUBLE PRECISION, PARAMETER                         :: D_MAX = 50000.0

	DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)         :: Bin, f, Rt
	INTEGER, PARAMETER                                  :: numAbsMag = N_DIST
	DOUBLE PRECISION, DIMENSION(1:numAbsMag)            :: absMags, minDist, maxDist
	INTEGER                                             :: absMagIndex, min_index, max_index

	DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)         :: time_bins, popOut, sf_rate
	DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)         :: lon, lat
	DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:, :, :)   :: dist, ifg
	DOUBLE PRECISION                                    :: Rchn

	INTEGER, DIMENSION(:), ALLOCATABLE                  :: ran_pick
	DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:)         :: cumulative_sum
	DOUBLE PRECISION                                    :: total_prob, random_num
	INTEGER                                             :: min_id, max_id, mid_id, int_total_prob

	TYPE :: popFile
		! from 'pop' file
		DOUBLE PRECISION   :: id
		DOUBLE PRECISION   :: t1, t2
		DOUBLE PRECISION   :: initial_mass1, initial_mass2, initial_period
		DOUBLE PRECISION   :: dmin, dmax
		CHARACTER(len=100) :: chn

		! Dervied in this code
		DOUBLE PRECISION   :: fs, fss
		DOUBLE PRECISION   :: f_mass1, f_mass2, f_periods, a, q
		DOUBLE PRECISION   :: rdmax, rdmin, f_density_min, f_density_max
	END TYPE popFile

	TYPE :: magFile
		DOUBLE PRECISION :: id
		DOUBLE PRECISION :: mag1, mag2, magBin, magUsed
	END TYPE magFile

	TYPE(popFile), ALLOCATABLE, DIMENSION(:)            :: pop
	TYPE(magFile), ALLOCATABLE, DIMENSION(:)            :: mag

	CHARACTER(len=3)                                    :: schn
	CHARACTER(len=2)                                    :: magValue
	CHARACTER(len=50)                                   :: file_extension
	CHARACTER(len=250)                                  :: fin, fout
	CHARACTER(len=250), DIMENSION(20)                   :: iname
	CHARACTER(len=250)                                  :: BUFFER, inDir
	CHARACTER(len=100)                                  :: infile

    ! Define pi
	pi = ACOS(-1.d0)

    ! Get population parameters file
	call GETARG(1, infile)
	call read_pop_params(inFile)


    ! Get directory for channels folder
    ! 'inDir' will hold '_grid_' spacings file
	CALL getarg(2, inDir)

    ! Setup input filenames
	file_extension = 'dat.' // model(1:LEN_TRIM(model))

	iname(1) = trim(inDir) // fname(class, '_grid.'   // file_extension)
	iname(2) = trim(inDir) // fname(class, '_birth_'  // file_extension)
	iname(3) = trim(inDir) // fname(class, '_death.'  // file_extension)
	iname(4) = trim(inDir) // fname(class, '_init.'   // file_extension)
	iname(5) = trim(inDir) // fname(class, '_extra.'  // file_extension)
	iname(6) = trim(inDir) // fname(class, '_pop.'    // file_extension)
	iname(8) = trim(inDir) // fname(class, '_mag.'    // file_extension)
	iname(9) = trim(inDir) // fname(class, '_kepler.' // file_extension)

    ! Setup 2D grid (bins) of galactic
    ! longitudes and latitudes in radians
	ALLOCATE(lon(nlon+1), lat(nlat+1), STAT=alloc_status)

    call check_alloc_error(alloc_status, 'Error allocating lon, lat!')

	lon1 = lon1 * pi/180.d0
	lon2 = lon2 * pi/180.d0
	lat1 = lat1 * pi/180.d0
	lat2 = lat2 * pi/180.d0

	dlon = (lon2 - lon1) / DBLE(nlon)
	dlat = (lat2 - lat1) / DBLE(nlat)

	CALL create_bins(x0=lon1, dx=dlon, n=nlon, bin_edges=lon)
	CALL create_bins(x0=lat1, dx=dlat, n=nlat, bin_edges=lat)

    ! Integrate Galactic potential and store for later use

	ALLOCATE(dist(nlon+1, nlat+1, N_DIST+1), &
	          ifg(nlon+1, nlat+1, N_DIST+1), STAT=alloc_status)

    call check_alloc_error(alloc_status, 'Error allocating dist, ifg!')

	DO ii = 1, nlon

		DO jj = 1, nlat
			delta_d = D_MAX / DBLE(N_DIST)

			IF (delta_d > 10.d0) THEN
                WRITE(0, *)
                WRITE(0, *) 'ERROR: delta_d > 10 pc!'
                WRITE(0, *)
                call setError()
                STOP 'Abnormal program termination!!!'
			END IF

 			CALL create_bins(x0=0.d0, dx=delta_d, n=N_DIST, bin_edges=dist(ii, jj, 1:N_DIST+1))

			ifg(ii, jj, 1) = 0.d0

			DO kk = 2, N_DIST+1
                ifg(ii, jj, kk) = integrate_galactic_field(0.d0,                     &
                                                           dist(ii, jj, kk),         &
                                                           lon(ii), lon(ii+1),       &
                                                           lat(jj), lat(jj+1),       &
                                                           R0, z0, hR, hz)
			END DO

		END DO

	END DO
    ! 	write(*, *) "Done initial integration"

    ! Determine bin sizes
	dt = (t_end - t_start) / n_time_steps

    ! Allocate memory to bin arrays
	ALLOCATE(time_bins(n_time_steps+1), STAT=alloc_status)

    call check_alloc_error(alloc_status, 'Error allocating time_bins!')

    ! Make time bins
	CALL create_bins(x0=t_start, dx=dt, n=n_time_steps, bin_edges=time_bins)

    ! T_galaxy  = age of Galaxy
    ! find the age of the Galaxy in time bins
	CALL locate(search_array=time_bins, n=n_time_steps+1, search_for=T_galaxy, found_idx=idx_T_galaxy)

	IF ((idx_T_galaxy < 1) .OR. (idx_T_galaxy > n_time_steps)) THEN
        WRITE(0, *)
        WRITE(0, *) '2z,  ERROR in timegrid!', idx_T_galaxy, n_time_steps, T_galaxy
        WRITE(0, *)
        call setError()
        STOP 'Abnormal program termination!!!'
	END IF

    ! Read grid spacings
    ! of the initial parameter grid
    ! _GRID_ file
	fin = iname(1)
	OPEN(1, FILE=fin(1:LEN_TRIM(fin)), STATUS='OLD', ACTION='READ')
	READ(1, *)
	READ(1, *) grid_points_mass1, grid_points_mass2, grid_points_A
	CLOSE(1)

    ! how many rows in "_POP_" file?
	fin=iname(6)
	lineCount=0
	OPEN(1, FILE=fin(1:LEN_TRIM(fin)), STATUS='OLD', ACTION='READ')
	do  while  (.true.)
		read(1, '(A)', end=99) BUFFER
		lineCount = lineCount + 1
	enddo
99    continue
	CLOSE(1)


	ALLOCATE(pop(1:lineCount), mag(1:lineCount), popOut(1:lineCount), STAT=alloc_status)

    call check_alloc_error(alloc_status, 'error allocating pop, mag, popOut!')

    ! write(*, *) lineCount
	pop%fss = 0.d0

	! Read "_pop_" file
	fin = iname(6)
	OPEN(1, FILE=fin(1:LEN_TRIM(fin)), STATUS='OLD', ACTION='READ')
	do i=1, lineCount
		READ(1, *) pop(i)%id, pop(i)%initial_mass1, pop(i)%initial_mass2, pop(i)%initial_period, pop(i)%t1, pop(i)%t2, pop(i)%chn
	end do
	CLOSE(1)

    ! write(*, *) pop(1)

	! Derive intial distributions
    ! Mass ratio
	pop%q = pop%initial_mass2 / pop%initial_mass1

    ! Semi-major axis in Rsun
	pop%a = Porb2a(pop%initial_period/365.d0, pop%initial_mass1, pop%initial_mass2)

    ! Distribution of log10(ms1)
    ! imf = initial mass function
	pop%f_mass1 = get_imf(pop%initial_mass1, imfType)

	IF (imr >= 1.0D32) THEN
        ! Distribution of log10(ms2)
		pop%f_mass2 = get_imf(pop%initial_mass2, imfType)
	ELSE
        ! EF may 2014
        ! imr = 0, this branch is being chosen

        ! Initial Mass Ratio Distribution of log10(ms2)
		pop%f_mass2 = LOG(10.d0) * pop%q * IMRD(pop%q, imr)
	END IF

    ! pop%f_periods = LOG(10.d0)*(2.d0/3.d0)*pop%a*IOSD(pop%a)
    ! Distribution of log10(Ps)
    ! IOSD = initial orbit separation distribution
	pop%f_periods = log(10.d0) * pop%a * IOSD(pop%a)

	!DO NOT need to read transit file

	!Read _MAG_ file
	fin = iname(8)
	OPEN(1, FILE=fin(1:LEN_TRIM(fin)), STATUS='OLD', ACTION='READ')
	do i=1,  lineCount
		READ(1, *) mag(i)%id, mag(i)%mag1, mag(i)%mag2, mag(i)%magBin
        ! write(*, *) i, lineCount
	end do
	CLOSE(1)

	mag%magUsed = mag%magBin

	ALLOCATE(f(n_time_steps),           &
             Rt(n_time_steps),          &
             Bin(n_time_steps),         &
             sf_rate(n_time_steps+1),   &
             STAT=alloc_status)

    call check_alloc_error(alloc_status, 'error allocating f, Rt, Bin, sf_rate!')

	pop%fs = pop%f_mass1

	if ( isSingle == 0 ) then
        ! its a binary system
		pop%fs = pop%fs * pop%f_mass2 * pop%f_periods
	END IF

    ! pop%fs=1.d0

	dVs = grid_points_mass1

	if(isSingle == 0) then
        ! binary system
        dVs = grid_points_mass1 * grid_points_mass2 * grid_points_A
	end if

	DO nn = 1, NUM_LB_SUB+1
		l0(nn) = lon(1) + DBLE(nn-1) * dlon / DBLE(NUM_LB_SUB)
		b0(nn) = lat(1) + DBLE(nn-1) * dlat / DBLE(NUM_LB_SUB)
	END DO

	l0deg = l0 * 180.d0/pi
	b0deg = b0 * 180.d0/pi

	where (l0deg < 0.d0)
        l0deg = l0deg + 360.0
    end where

    ! !Get distance corrected for extinction
    !       DO k=1, lineCount
    !       	pop(k)%dmax=distanceCalc(pop(k)%dmax, l0deg, b0deg, NUM_LB_SUB, colourCorrect, dlon, dlat, extType)
    ! 		pop(k)%dmin=distanceCalc(pop(k)%dmin, l0deg, b0deg, NUM_LB_SUB, colourCorrect, dlon, dlat, extType)
    ! 	END DO

    ! Lets try precomputing the extinction
    ! for a series of abs mag values
    ! then interpolating the result
 	FORALL(i=1:numAbsMag) absMags(i) = 1.1 * minval(mag%magUsed) + &
                                       ((i-1) * (1.1*maxval(mag%magUsed) - 1.1*minval(mag%magUsed)) / (numAbsMag))

	! Overwrite the distances for each object
	forall (k=1:numAbsMag) minDist(k) = 10.d0**((minMag - absMags(k) + 5.d0) / 5.d0)
	forall (k=1:numAbsMag) maxDist(k) = 10.d0**((maxMag - absMags(k) + 5.d0) / 5.d0)

    ! Lets scale the system down if we go to far
    ! EF should it be 'minDist .lt. 50000.d0'?
	where (minDist .gt. 50000.d0) minDist = 50000.d0
	where (maxDist .gt. 50000.d0) maxDist = 50000.d0

	DO i=1, numAbsMag
    	maxDist(i) = distanceCalc(maxDist(i), l0deg, b0deg, NUM_LB_SUB, colourCorrect, dlon, dlat, extType)
 		minDist(i) = distanceCalc(minDist(i), l0deg, b0deg, NUM_LB_SUB, colourCorrect, dlon, dlat, extType)
	END DO



    ! Now match the stars abs mag against the absMag array
    ! and interpolate against next element
	DO i=1, lineCount
 		CALL locate(search_array=absMags, n=numAbsMag, search_for=mag(i)%magUsed, found_idx=absMagIndex)

		min_index = absMagIndex
		max_index = absMagIndex + 1

        ! write(*, *) mag(i)%magUsed, absMagIndex, absMags(min_index-2), absMags(min_index-1), absMags(min_index), absMags(min_index+1), absMags(min_index+2)
        ! write(*, *) minDist(min_index-1), minDist(min_index), minDist(min_index+1), minDist(min_index+2)
        ! write(*, *) maxDist(min_index-1), maxDist(min_index), maxDist(min_index+1), maxDist(min_index+2)

		pop(i)%dmin = linpol(x=mag(i)%magUsed, x0=absMags(min_index), x1=absMags(max_index), y0=minDist(min_index), y1=minDist(max_index))
		pop(i)%dmax = linpol(x=mag(i)%magUsed, x0=absMags(min_index), x1=absMags(max_index), y0=maxDist(min_index), y1=maxDist(max_index))

        ! write(*, *) pop(i)%dmin, pop(i)%dmax
        ! write(*, *) "*"
	end do

    ! write(*, *) maxval(mag%magUsed), minval(mag%magUsed)

	! Get stellar density between the two distances
	DO k=1, lineCount
        pop(k)%f_density_min = get_stellar_density(dist(1, 1, 1:N_DIST+1),    &
                                                   N_DIST + 1,                &
                                                   dist_star=pop(k)%dmin,     &
                                                   ifg=ifg(1, 1, 1:N_DIST+1))

        pop(k)%f_density_max = get_stellar_density(dist(1, 1, 1:N_DIST+1),    &
                                                   N_DIST + 1,                &
                                                   dist_star=pop(k)%dmax,     &
                                                   ifg=ifg(1, 1, 1:N_DIST+1))

        ! write(*, *) pop(k)%f_density_min, pop(k)%f_density_max
	END DO

	where (pop%f_density_min > pop%f_density_max)
        pop%f_density_min = pop%f_density_max
    end where

    ! pop%fss = pop%fs*(pop%f_density_max-pop%f_density_min)
	pop%fss = pop%fs * (pop%f_density_max - pop%f_density_min)

    ! Generate star formation rate.
    ! This determines how many stars
    ! have been made in each time bin
	sf_rate = 0.d0
	CALL generate_sf_rate(time_bins, n_time_steps+1, sf_method, disk_age, T0, imfType, rate=sf_rate)

	where(pop%t1 < 0.0d0)     pop%t1 = 0.0d0
	where(pop%t2 < 0.0d0)     pop%t2 = 0.0d0
	where(pop%t1 > 15000.0d0) pop%t1 = 15000.0d0
	where(pop%t2 > 15000.0d0) pop%t2 = 15000.0d0

	stars: DO j = 1, lineCount

        ! Put current parameter space in bins
		Bin = 0.d0

		CALL locate(search_array=time_bins, n=n_time_steps+1, search_for=pop(j)%t1, found_idx=idx_t1)
		CALL locate(search_array=time_bins, n=n_time_steps+1, search_for=pop(j)%t2, found_idx=idx_t2)

		IF ((idx_t1 > 0) .AND. &
            (idx_t1 < n_time_steps+1) .AND. pop(j)%t1 <= T_galaxy) THEN

			delta_t   = MIN(time_bins(idx_t1+1), pop(j)%t2) - pop(j)%t1
			weighting = delta_t/dt

			IF ((weighting < 0.d0) .OR. (weighting > 1.d0)) THEN
				WRITE(0, *)
				WRITE(0, *) '1a ERROR in time weightings!'
				WRITE(0, *) weighting, j, pop(j)%t2, pop(j)%t1, dt, delta_t, n_time_steps, idx_t1, idx_t2
				!write(0, *) time_bins
				call setError()
				STOP 'Abnormal program termination!!!'
			END IF

			Bin(idx_t1) = Bin(idx_t1) + pop(j)%fss * weighting * dVs/dt

		ELSE IF ((idx_t1 < 1) .OR. (idx_t1 > n_time_steps)) THEN
			WRITE(0, *)
			WRITE(0, *) '2a,  ERROR in timegrid!'
			WRITE(0, *) idx_t1, n_time_steps, pop(j)%t1, pop(j)%t2
			call setError()
			STOP 'Abnormal program termination!!!'
		END IF

		if ((idx_t2 > n_time_steps) .or. (pop(j)%t2 > T_galaxy)) then
            idx_t2 = MIN(idx_T_galaxy, n_time_steps)
        end if

		DO kk = idx_t1 + 1, idx_t2

			IF (kk == idx_t2) THEN
				delta_t   = MIN(pop(j)%t2, T_galaxy) - time_bins(idx_t2)
				weighting = delta_t/dt
			ELSE
				weighting = 1.d0
			END IF

			IF ((weighting < 0.d0) .OR. (weighting > 1.d0)) THEN
				WRITE(0, *)
				WRITE(0, *) '3a ERROR in time weighting!'
				WRITE(0, *)
				call setError()
				STOP 'Abnormal program termination!!!'
			END IF

			Bin(kk) = Bin(kk) + pop(j)%fss * weighting * dVs/dt

		END DO

		f  = 0.d0
		Rt = 0.d0

		DO i_step = 1, n_time_steps

			FORALL(i = 1:i_step)    f(i) = sf_rate(i) * Bin(i_step + 1 - i)

			Rt(i_step) = calc_integral(values=f, n=n_time_steps, low=1, high=i_step, bin_widths=dt)

		END DO

        ! DEALLOCATE(f, Bin)

        ! Store results
		popOut(j) = Rt(idx_T_galaxy) * dt

        ! DEALLOCATE(Rt)
        ! write(0, *) pop(j)%id, j, answer(j)
	END DO stars

	ALLOCATE(cumulative_sum(0:lineCount), stat=alloc_status)

    call check_alloc_error(alloc_status, 'error allocating cumulative_sum!')

    ! chop down population
    ! according to binary fraction?
	popOut    = popOut * bFrac

	cumulative_sum(0) = 0

	DO i=1, lineCount
		cumulative_sum(i) = cumulative_sum(i-1) + popOut(i)
	END DO

    ! Get total probability, round to nearest int
    ! and re-scale everything between 0 and 1
	total_prob      = cumulative_sum(lineCount)
	int_total_prob  = nint(total_prob)
	cumulative_sum  = cumulative_sum / total_prob

	! Initialize random number generator
	CALL preIntRan()

	ALLOCATE(ran_pick(1:int_total_prob), stat=alloc_status)

    call check_alloc_error(alloc_status, 'error allocating ran_pick!')

	! Loop until we've generated all stars needed
	DO i=1, int_total_prob

		! generate random number between 0 to 1
		random_num = unif(0.d0, 1.d0)

		! Search 'cumulative_sum' for 'random_num'
        ! between element 'i' and 'i-1'
		min_id = 1
		max_id = lineCount

		binary_search : DO

			mid_id = floor(dble(max_id + min_id) / 2)

			IF (random_num .ge. cumulative_sum(mid_id - 1) .and. &
                random_num .lt. cumulative_sum(mid_id)) THEN
                ! found it!
                ! quit loop!
				ran_pick(i) = mid_id
				EXIT binary_search

			ELSE IF(random_num .lt. cumulative_sum(mid_id-1)) THEN
				max_id = mid_id

			ELSE
				min_id = mid_id

			END IF

		END DO binary_search

	END DO

	DO i=1, int_total_prob
        ! write chosen line numbers to 'stdout'.
        ! 'stdout' usually points to 'ran_pick.dat.1'
		write(*, *) ran_pick(i)
	END DO

	STOP
END PROGRAM population
