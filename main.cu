
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifdef __INTELLISENSE__
void __syncthreads();
#endif

#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#include <device_functions.h>
#include <cuda_runtime_api.h>
#include <pgmio.h>

// image dimensions WIDTH & HEIGHT
#define WIDTH 256
#define HEIGHT 256

// Block width WIDTH & HEIGHT
#define BLOCK_W 16
#define BLOCK_H 16

// buffer to read image into
float image[HEIGHT][WIDTH];

// buffer for resulting image
float final[HEIGHT][WIDTH];

// prototype declarations
void load_image();
void call_kernel();
void save_image();

#define MAXLINE 128

float total, sobel;
cudaEvent_t start_total, stop_total;
cudaEvent_t start_sobel, stop_sobel;


__global__ void imageBlur(float *input, float *output, int width, int height) {
	
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;

	int numcols = WIDTH;

	float blur;

	if (row <= height && col <= width && row > 0 && col > 0)
	{
		// weights
		int		x1,
			x3, x4, x5,
				x7;

		// blur
		// 0.0 0.2 0.0
		// 0.2 0.2 0.2
		// 0.0 0.2 0.0

		x1 = input[(row + 1) * numcols + col];			// up
		x3 = input[row * numcols + (col - 1)];			// left
		x4 = input[row * numcols + col];				// center
		x5 = input[row * numcols + (col + 1)];			// right
		x7 = input[(row + -1) * numcols + col];			// down

		blur = (x1 * 0.2) + (x3 * 0.2) + (x4 * 0.2) + (x5 * 0.2) + (x7 * 0.2);

		output[row * numcols + col] = blur;
	}
}


__global__ void sobelFilter(float *input, float *output, int width, int height) {
	
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;

	int numcols = WIDTH;

	float gradient_h;	
	float gradient_v;	
	float gradient;		
	float thresh = 30;	

	if (row <= height && col <= width && row > 0 && col > 0)
	{
		int x0, x1, x2, 
		    x3,	    x5, 
			x6, x7, x8;

		// horizontal
		// -1  0  1
		// -2  0  2
		// -1  0  1

		// vertical 
		// -1 -2 -1
		//  0  0  0
		//  1  2  1

		x0 = input[(row - 1) * numcols + (col - 1)];	// leftup
		x1 = input[(row + 1) * numcols + col];			// up
		x2 = input[(row - 1) * numcols + (col + 1)];	// rightup
		x3 = input[row * numcols + (col - 1)];			// left
		x5 = input[row * numcols + (col + 1)];			// right
		x6 = input[(row + 1) * numcols + (col - 1)];	// leftdown
		x7 = input[(row + -1) * numcols + col];			// down
		x8 = input[(row + 1) * numcols + (col + 1)];	// rightdown


		gradient_h = (x0 * -1) + (x2 * 1) + (x3 * -2) + (x5 * 2) + (x6 * -1) + (x8 * 1);
		gradient_v = (x0 * -1) + (x1 * -2) + (x3 * -1) + (x6 * 1) + (x7 * 2) + (x8 * 1);

		gradient = sqrt((gradient_h * gradient_h) + (gradient_v * gradient_v));

		if (gradient >= thresh)
		{
			gradient = 255;
		}
		else {
			gradient = 0;
		}
		output[row * numcols + col] = gradient;
	}
}

void load_image() {
	pgmread("image512x512.pgm", (void *)image, WIDTH, HEIGHT);
}

void save_image() {
	pgmwrite("image-outputl512x512.pgm", (void *)final, WIDTH, HEIGHT);
}

void call_kernel() {
	int x, y;
	float *d_input, *d_output;

	printf("Block size: %dx%d\n", BLOCK_W, BLOCK_H);

	size_t memSize = WIDTH * HEIGHT * sizeof(float);

	cudaMalloc(&d_input, memSize);
	cudaMalloc(&d_output, memSize);

	for (y = 0; y < HEIGHT; y++) {
		for (x = 0; x < WIDTH; x++) {
			final[x][y] = 0.0;
		}
	}

	printf("Blocks per grid (width): %d |", (WIDTH / BLOCK_W));
	printf("Blocks per grid (height): %d |", (HEIGHT / BLOCK_H));


	cudaMemcpy(d_input, image, memSize, cudaMemcpyHostToDevice);

	dim3 threads(BLOCK_W, BLOCK_H); // threads per block
	dim3 blocks(WIDTH / BLOCK_W, HEIGHT / BLOCK_H); // blocks per grid 
  
  	imageBlur << <blocks, threads >> > (d_input, d_output, WIDTH, HEIGHT);
  
  	cudaThreadSynchronize();
    
  	cudaMemcpy(d_input, d_output, memSize, cudaMemcpyDeviceToHost);

	sobelFilter << <blocks, threads >> > (d_input, d_output, WIDTH, HEIGHT);

	cudaThreadSynchronize();

	cudaMemcpy(final, d_output, memSize, cudaMemcpyDeviceToHost);


	cudaError_t err = cudaGetLastError();
	if (cudaSuccess != err)
	{
		fprintf(stderr, "Cuda error: %s: %s.\n", "Main Loop", cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}

	cudaFree(d_input);
	cudaFree(d_output);
}

int main(int argc, char *argv[])
{
  cudaEventCreate(&start_total);
  cudaEventCreate(&stop_total);
    
  cudaEventCreate(&start_sobel);
  cudaEventCreate(&stop_sobel);
    
  cudaEventRecord(start_total, 0);

	load_image();
   
  cudaEventRecord(start_sobel, 0);

	call_kernel();
  
  cudaEventRecord(stop_sobel, 0);
  cudaEventSynchronize(stop_sobel);
  cudaEventElapsedTime(&sobel, start_sobel, stop_sobel);

	save_image();
   
  cudaEventRecord(stop_total, 0);
  cudaEventSynchronize(stop_total);
  cudaEventElapsedTime(&total, start_total, stop_total);
    
  printf("Total Parallel Time:  %f s |", sobel/1000);
  printf("Total Serial Time:  %f s |", (total-sobel)/1000);
  printf("Total Time:  %f s |", total/1000);
  
    
	cudaDeviceReset();
	
	return 0;
}
