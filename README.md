# Parallel-Sobel-Edge-Detection
Implemented sobel edge detection using MPI and Cuda

The code only works for images with '.pgm' extension. 'pgmio.h' is a helper file to read and write the image.

For MPI, In the main.c file,

From line 11 to line 23, sample image sizes are given. Select which image you want to use for edge detection and comment out the other two.
From line 55 to line 57, input image file names are specified. Use the required files, and comment out the others.
From line 115 to line 117, output image file names are specified. Use the required files, and comment out the others.
To compile the code do: $MPICC -o main main.c -lm

To run the code do: $MPIRUN -n 4 ./main

Here -n is the number of processes you want to use to parallelize the code.

For Cuda In the main.cu file,

In lines 18 and 19, sample image size is given. Change the value if you wish to use a different image.
A function load_image is provided. Change the input image file name if you wish to use a different image.
A function save_image is provided. Change the output image file name if you wish to use a different image.
After several rounds of trial and error, we set the threshold value as 100, as it gave the most ideal result. It can be changed in in the main.c or main.cu.
