#include <stdio.h>
#include "DNN.h"

#define KB * 1024

char ibuf[2 KB], wbuf[2 KB], obuf[6 KB], rbuf[50 KB];

int main(int argc, char* argv[])
{
	FILE *ifp, *wfp, *ofp, *rfp;
	int ic;
	unsigned i, ymr;

	if (argc != 5)
		return 1;
	if ((ifp = fopen(*++argv, "r")) == NULL || (wfp = fopen(*++argv, "r")) == NULL || (ofp = fopen(*++argv, "w")) == NULL || (rfp = fopen(*++argv, "r")) == NULL)
		return 2;

	i = 0;
	while ((ic = fgetc(ifp)) != EOF)
		ibuf[i++] = ic;
	printf("Input file: %u bytes\n", i);

	i = 0;
	while ((ic = fgetc(wfp)) != EOF)
		wbuf[i++] = ic;

	printf("Weight file: %u bytes\n", i);

	i = 0;
#ifndef RSIZE
	while ((ic = fgetc(rfp)) != EOF)
		rbuf[i++] = ic;
#else
	while (i < RSIZE)
		rbuf[i++] = fgetc(rfp);
#endif
	printf("Ref file: %u bytes\n", i);

	fclose(ifp);
	fclose(wfp);
	fclose(rfp);

	addr.rd_addr = ibuf;
	addr.weight_addr = wbuf;
	addr.wr_addr = obuf;

	printf("Starting convolution...\n");
	convolution();
	printf("Starting pooling...\n");
	ymr = pooling() * sizeof(short);

	for (i = 0; i < ymr; ++i)
		if (obuf[i] != rbuf[i])
		{
			printf("**Note: at %u, obuf is 0x%X, rbuf is 0x%X\n", i, obuf[i], rbuf[i]);
			break;
		}

	for (i = 0; i < ymr; ++i)
		fputc(obuf[i], ofp);
	printf("Output file: %u bytes\n", i);
	fclose(ofp);
	return 0;
}
