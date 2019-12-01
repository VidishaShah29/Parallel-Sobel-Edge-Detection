#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "mpi.h"

#include "mpi_pgmio.h"

double start_time_sobel, end_time_sobel;
double start_time_total, end_time_total;

//set image size
/*
//for monalisa
#define M 250
#define N 360
*/
//for peppers
#define M 256
#define N 256
/*
//for tracks
#define M 300
#define N 200
*/


#define THRESH 100

int main(int argc, char **argv)
{

	int rank, size;
	MPI_Status status;

	MPI_Init(&argc, &argv);

	MPI_Comm_size(MPI_COMM_WORLD, &size);	
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);	

	int P = size;
	int MP = M/P;
	int NP = N;

	float image[MP + 2][NP + 2];

	float masterbuf[M][N];	
	float buf[MP][NP];		

	int i, j; 
	char *filename; 

	if (rank == 0)
	{
		start_time_total = MPI_Wtime();
		// un-comment the input file you want to use
		//char input[] = "image250x360.pgm";
		char input[] = "image256x256.pgm";
		//char input[] = "image300x200.pgm";
		filename = input;
		pgmread(filename, masterbuf, M, N);

		printf("width: %d \nheight: %d\nprocessors: %d\n", M, N, P);
	}
	start_time_sobel = MPI_Wtime();
	MPI_Scatter(masterbuf, MP*NP, MPI_FLOAT, buf, MP*NP, MPI_FLOAT, 0, MPI_COMM_WORLD);

	for (i = 1; i < MP + 1; i++)
	{
		for (j = 1; j < NP + 1; j++)
		{
			// horizontal gradient
			// -1  0  1
			// -2  0  2
			// -1  0  1

			// vertical gradient
			// -1 -2 -1
			//  0  0  0
			//  1  2  1

			float gradient_h = ((-1.0 * buf[i - 1][j - 1]) + (1.0 * buf[i + 1][j - 1]) + (-2.0 * buf[i - 1][j]) + (2.0 * buf[i + 1][j]) + (-1.0 * buf[i - 1][j + 1]) + (1.0 * buf[i + 1][j + 1]));
			float gradient_v = ((-1.0 * buf[i - 1][j - 1]) + (-2.0 * buf[i][j - 1]) + (-1.0 * buf[i + 1][j - 1]) + (1.0 * buf[i - 1][j + 1]) + (2.0 * buf[i][j + 1]) + (1.0 * buf[i + 1][j + 1]));

			float gradient = sqrt((gradient_h * gradient_h) + (gradient_v * gradient_v));

			if (gradient < THRESH) {
				gradient = 0;	
			}
			else {
				gradient = 255;	
			}
			image[i][j] = gradient;
		}
	}
	end_time_sobel = MPI_Wtime();

	if (rank == 0)
	{
		printf("Finished");
	}

	for (i = 1; i < MP + 1; i++)
	{
		for (j = 1; j < NP + 1; j++)
		{
			buf[i - 1][j - 1] = image[i][j];
		}
	}

	MPI_Gather(buf, MP*NP, MPI_FLOAT, masterbuf, MP*NP, MPI_FLOAT, 0, MPI_COMM_WORLD);


	if (rank == 0)
	{
		// un-comment the corresponding output filename
		//char output[] = "image-output250x360.pgm";
		char output[] = "image-output256x256.pgm";
		//char output[] = "image-output300x200.pgm";
		filename = output;
		
		printf("\nOutput: <%s>\n", filename);
		pgmwrite(filename, masterbuf, M, N);
		end_time_total = MPI_Wtime();

		double total = (end_time_sobel - start_time_sobel);
		printf("Total Parallel Time: %fs\n", total);
		printf("Total Serial Time: %fs\n", (end_time_total - start_time_total) - total);
		printf("Total Time: %fs\n", end_time_total - start_time_total);

	}

	
	MPI_Finalize();

	return 0;
}
