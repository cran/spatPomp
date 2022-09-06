// -*- C++ -*-

#include "spatPomp_defines.h"
#include <Rdefines.h>

void nosort_resamp (int nw, double *w, int np, int *p, int offset)
{
  int i, j;
  double du, u;

  for (j = 1; j < nw; j++) w[j] += w[j-1];

  if (w[nw-1] <= 0.0)
    errorcall(R_NilValue,"in 'systematic_resampling': non-positive sum of weights");

  du = w[nw-1] / ((double) np);
  u = -du*unif_rand();

  for (i = 0, j = 0; j < np; j++) {
    u += du;
    // In the following line, the second test is needed to correct
    // the infamous Bug of St. Patrick, 2017-03-17.
    while ((u > w[i]) && (i < nw-1)) i++;
    p[j] = i;
  }
  if (offset)			// add offset if needed
    for (j = 0; j < np; j++) p[j] += offset;

}

