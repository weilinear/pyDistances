### auto-generated from distfuncs.pxi_src using _parse_src.py

# Note: this script uses a simple template to replace SPARSE and DENSE
# loops which are re-used in each function.
#
# This can be parsed using the script _parse_src.py in this directory
# this will generate the file 'distfuncs.pxi' in this directory

from distmetrics cimport DTYPE_t, dist_params
from libc.math cimport fabs, fmax, sqrt, pow

#======================================================================
# buffer from ndarray
cdef extern from "arrayobject.h":
    object PyArray_SimpleNewFromData(int nd, np.npy_intp* dims, 
                                     int typenum, void* data)
np.import_array()  # required in order to use C-API

cdef inline np.ndarray _buffer_to_ndarray(DTYPE_t* x, np.npy_intp n):
    # Wrap a memory buffer with an ndarray.  Warning: this is not robust.
    # In particular, if x is deallocated before the returned array goes
    # out of scope, this could cause memory errors.

    # if we know what n is beforehand, we can simply call
    # (in newer cython versions)
    #return np.asarray(<double[:100]> x)

    # Note: this Segfaults unless np.import_array() is called above
    return PyArray_SimpleNewFromData(1, &n, DTYPECODE, <void*>x)

#======================================================================
#  Loop macros
#
#  These loops should iterate over the entries of the vectors, and at
#  the end of each cycle have i, x1i, x2i defined.  i is the index of
#  the feature, x1i is the value of the first vector at i, and x2i is
#  the value of the second vector at i

#U--------------------------------------------------
# Dense-Dense distance loop macro
#


#--------------------------------------------------
# Sparse-Dense distance loop macro
#
#   Note that this function assumes ordered form with no duplicate indices
#


#--------------------------------------------------
# Sparse-Sparse distance loop macro
#


#======================================================================
# Euclidean Distance
#
# D(x, y) = sqrt[ sum_i (x_i - y_i) ^ 2 ]
#
cdef DTYPE_t euclidean_distance(DTYPE_t* x1, DTYPE_t* x2,
                                int n, dist_params* params,
                                int rowindex1,
                                int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        d = x1i - x2i
        res += d * d
    return sqrt(res)


cdef DTYPE_t euclidean_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, int n,
                                     dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        d = x1i - x2i
        res += d * d
    return sqrt(res)


cdef DTYPE_t euclidean_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                     int n, dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        d = x1i - x2i
        res += d * d
    return sqrt(res)


#======================================================================
# S-euclidean distance
#
# D(x, y) = sqrt{sum_i [ (x_i - y_i)^2 / v_i ]}
#
@cython.cdivision(True)
cdef DTYPE_t seuclidean_distance(DTYPE_t* x1, DTYPE_t* x2,
                                 int n, dist_params* params,
                                 int rowindex1,
                                 int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return sqrt(res)


@cython.cdivision(True)
cdef DTYPE_t seuclidean_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, int n,
                                      dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return sqrt(res)


@cython.cdivision(True)
cdef DTYPE_t seuclidean_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                      int n, dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return sqrt(res)


#======================================================================
# Squared Euclidean Distance
#
# D(x, y) = sum_i (x_i - y_i) ^ 2
#
cdef DTYPE_t sqeuclidean_distance(DTYPE_t* x1, DTYPE_t* x2,
                                  int n, dist_params* params,
                                  int rowindex1,
                                  int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        d = x1i - x2i
        res += d * d
    return res


cdef DTYPE_t sqeuclidean_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, int n,
                                       dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        d = x1i - x2i
        res += d * d
    return res


cdef DTYPE_t sqeuclidean_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                       int n, dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        d = x1i - x2i
        res += d * d
    return res


#======================================================================
# Squared S-euclidean distance
#
# D(x, y) = sum_i [ (x_i - y_i)^2 / v_i ]
#
@cython.cdivision(True)
cdef DTYPE_t sqseuclidean_distance(DTYPE_t* x1, DTYPE_t* x2,
                                   int n, dist_params* params,
                                   int rowindex1,
                                   int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return res


@cython.cdivision(True)
cdef DTYPE_t sqseuclidean_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                        DTYPE_t* x2, int n,
                                        dist_params* params,
                                        int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return res


@cython.cdivision(True)
cdef DTYPE_t sqseuclidean_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                        DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                        int n, dist_params* params,
                                        int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        d = x1i - x2i
        res += d * d / params.seuclidean.V[i]
    return res


#======================================================================
# Manhattan_distance
#
# D(x, y) = sum_i[ abs(x_i - y_i) ]
#
cdef DTYPE_t manhattan_distance(DTYPE_t* x1, DTYPE_t* x2,
                                int n, dist_params* params,
                                int rowindex1,
                                int rowindex2):
    cdef DTYPE_t res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res += fabs(x1i - x2i)
    return res


cdef DTYPE_t manhattan_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, int n,
                                     dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res += fabs(x1i - x2i)
    return res


cdef DTYPE_t manhattan_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                     int n, dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res += fabs(x1i - x2i)
    return res


#======================================================================
# Chebyshev distance
#
# D(x, y) = max_i[ abs(x_i - y_i) ]
#
cdef DTYPE_t chebyshev_distance(DTYPE_t* x1, DTYPE_t* x2,
                                int n, dist_params* params,
                                int rowindex1,
                                int rowindex2):
    cdef DTYPE_t res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res = fmax(res, fabs(x1i - x2i))
    return res


cdef DTYPE_t chebyshev_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, int n,
                                     dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res = fmax(res, fabs(x1i - x2i))
    return res


cdef DTYPE_t chebyshev_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                     int n, dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res = fmax(res, fabs(x1i - x2i))
    return res


#======================================================================
# Minkowski distance
#
# D(x, y) = [sum_i[abs(x_i - y_i)^p]]^(1/p)
#
@cython.cdivision(True)
cdef DTYPE_t minkowski_distance(DTYPE_t* x1, DTYPE_t* x2,
                                int n, dist_params* params,
                                int rowindex1,
                                int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


@cython.cdivision(True)
cdef DTYPE_t minkowski_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, int n,
                                     dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


@cython.cdivision(True)
cdef DTYPE_t minkowski_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                     int n, dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


#======================================================================
# pMinkowski distance
#
# D(x, y) = sum_i[abs(x_i - y_i)^p]
#
cdef DTYPE_t pminkowski_distance(DTYPE_t* x1, DTYPE_t* x2,
                                 int n, dist_params* params,
                                 int rowindex1,
                                 int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return res


cdef DTYPE_t pminkowski_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, int n,
                                      dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return res


cdef DTYPE_t pminkowski_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                      int n, dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res += pow(fabs(x1i - x2i), params.minkowski.p)
    return res


#======================================================================
# wMinkowski distance
#
# D(x, y) = [sum_i[w_i * abs(x_i - y_i)^p]]^(1/p)
#
@cython.cdivision(True)
cdef DTYPE_t wminkowski_distance(DTYPE_t* x1, DTYPE_t* x2,
                                 int n, dist_params* params,
                                 int rowindex1,
                                 int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


@cython.cdivision(True)
cdef DTYPE_t wminkowski_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, int n,
                                      dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


@cython.cdivision(True)
cdef DTYPE_t wminkowski_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                      int n, dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return pow(res, 1. / params.minkowski.p)


#======================================================================
# pwMinkowski distance
#
# D(x, y) = sum_i[w_i * abs(x_i - y_i)^p]
#
cdef DTYPE_t pwminkowski_distance(DTYPE_t* x1, DTYPE_t* x2,
                                  int n, dist_params* params,
                                  int rowindex1,
                                  int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return res


cdef DTYPE_t pwminkowski_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, int n,
                                       dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return res


cdef DTYPE_t pwminkowski_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                       int n, dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t d, res=0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        res += pow(params.minkowski.w[i] * fabs(x1i - x2i),
                   params.minkowski.p)
    return res


#======================================================================
# Cosine Distance
#
# D(x, y) = sum_i (x_i - y_i) ^ 2
#
@cython.cdivision(True)
cdef DTYPE_t cosine_distance(DTYPE_t* x1, DTYPE_t* x2,
                             int n, dist_params* params,
                             int rowindex1,
                             int rowindex2):
    cdef DTYPE_t x1nrm = 0, x2nrm = 0, x1Tx2 = 0, normalization = 0

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)
    
    cdef int i
    cdef DTYPE_t x1i, x2i

    if params.cosine.precomputed_norms and precomputed1 and precomputed2:
        for i from 0 <= i < n:
            x1i = x1[i]
            x2i = x2[i]
            x1Tx2 += x1i * x2i
        normalization = params.cosine.norms1[rowindex1]
        normalization *= params.cosine.norms2[rowindex2]
    else:
        for i from 0 <= i < n:
            x1i = x1[i]
            x2i = x2[i]
            x1nrm += x1i * x1i
            x2nrm += x2i * x2i
            x1Tx2 += x1i * x2i

        normalization = sqrt(x1nrm * x2nrm)

    return 1.0 - (x1Tx2) / normalization


@cython.cdivision(True)
cdef DTYPE_t cosine_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                  DTYPE_t* x2, int n,
                                  dist_params* params,
                                  int rowindex1, int rowindex2):
    cdef DTYPE_t x1nrm = 0, x2nrm = 0, x1Tx2 = 0, normalization = 0

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)

    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    
    if params.cosine.precomputed_norms and precomputed1 and precomputed2:
        i1 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = x2[i]        
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            x1Tx2 += x1i * x2i
        normalization = params.cosine.norms1[rowindex1]
        normalization *= params.cosine.norms2[rowindex2]
    else:
        i1 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = x2[i]        
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            x1nrm += x1i * x1i
            x2nrm += x2i * x2i
            x1Tx2 += x1i * x2i

        normalization = sqrt(x1nrm * x2nrm)

    return 1.0 - (x1Tx2) / normalization


@cython.cdivision(True)
cdef DTYPE_t cosine_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                  DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                  int n, dist_params* params,
                                  int rowindex1, int rowindex2):
    cdef DTYPE_t x1nrm = 0, x2nrm = 0, x1Tx2 = 0, normalization = 0

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)

    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    
    if params.cosine.precomputed_norms and precomputed1 and precomputed2:
        i1 = 0
        i2 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = 0
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            if i2 < n2:
                if ind2[i2] < i:
                    i2 += 1
                    if i2 < n2:
                        if ind2[i2] == i:
                            x2i = x2[i2]
                elif ind2[i2] == i:
                    x2i = x2[i2]
            x1Tx2 += x1i * x2i
        normalization = params.cosine.norms1[rowindex1]
        normalization *= params.cosine.norms2[rowindex2]
    else:
        i1 = 0
        i2 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = 0
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            if i2 < n2:
                if ind2[i2] < i:
                    i2 += 1
                    if i2 < n2:
                        if ind2[i2] == i:
                            x2i = x2[i2]
                elif ind2[i2] == i:
                    x2i = x2[i2]
            x1nrm += x1i * x1i
            x2nrm += x2i * x2i
            x1Tx2 += x1i * x2i

        normalization = sqrt(x1nrm * x2nrm)

    return 1.0 - (x1Tx2) / normalization


#======================================================================
# Correlation Distance
#
# D(x, y) = sum_i (x_i - y_i) ^ 2
#
@cython.cdivision(True)
cdef DTYPE_t correlation_distance(DTYPE_t* x1, DTYPE_t* x2,
                                  int n, dist_params* params,
                                  int rowindex1,
                                  int rowindex2):
    cdef DTYPE_t mu1 = 0, mu2 = 0, x1nrm = 0, x2nrm = 0, x1Tx2 = 0
    cdef DTYPE_t normalization

    cdef DTYPE_t tmp1, tmp2

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)

    cdef int i
    cdef DTYPE_t x1i, x2i

    if params.correlation.precomputed_data and precomputed1 and precomputed2:
        x1 = params.correlation.x1 + rowindex1 * n
        x2 = params.correlation.x2 + rowindex2 * n

        for i from 0 <= i < n:
            x1i = x1[i]
            x2i = x2[i]
            x1Tx2 += x1i * x2i

        normalization = params.correlation.norms1[rowindex1]
        normalization *= params.correlation.norms2[rowindex2]

    else:
        for i from 0 <= i < n:
            x1i = x1[i]
            x2i = x2[i]
            mu1 += x1i
            mu2 += x2i
        mu1 /= n
        mu2 /= n

        for i from 0 <= i < n:
            x1i = x1[i]
            x2i = x2[i]
            tmp1 = x1i - mu1
            tmp2 = x2i - mu2
            x1nrm += tmp1 * tmp1
            x2nrm += tmp2 * tmp2
            x1Tx2 += tmp1 * tmp2

        normalization = sqrt(x1nrm * x2nrm)

    return 1. - x1Tx2 / normalization


@cython.cdivision(True)
cdef DTYPE_t correlation_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, int n,
                                       dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t mu1 = 0, mu2 = 0, x1nrm = 0, x2nrm = 0, x1Tx2 = 0
    cdef DTYPE_t normalization

    cdef DTYPE_t tmp1, tmp2

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)

    cdef int i1, i
    cdef DTYPE_t x1i, x2i

    if params.correlation.precomputed_data and precomputed1 and precomputed2:
        x1 = params.correlation.x1 + rowindex1 * n
        x2 = params.correlation.x2 + rowindex2 * n

        i1 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = x2[i]        
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            x1Tx2 += x1i * x2i

        normalization = params.correlation.norms1[rowindex1]
        normalization *= params.correlation.norms2[rowindex2]

    else:
        i1 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = x2[i]        
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            mu1 += x1i
            mu2 += x2i
        mu1 /= n
        mu2 /= n

        i1 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = x2[i]        
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            tmp1 = x1i - mu1
            tmp2 = x2i - mu2
            x1nrm += tmp1 * tmp1
            x2nrm += tmp2 * tmp2
            x1Tx2 += tmp1 * tmp2

        normalization = sqrt(x1nrm * x2nrm)

    return 1. - x1Tx2 / normalization


@cython.cdivision(True)
cdef DTYPE_t correlation_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                       int n, dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef DTYPE_t mu1 = 0, mu2 = 0, x1nrm = 0, x2nrm = 0, x1Tx2 = 0
    cdef DTYPE_t normalization

    cdef DTYPE_t tmp1, tmp2

    cdef int precomputed1 = (rowindex1 >= 0)
    cdef int precomputed2 = (rowindex2 >= 0)

    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i

    if params.correlation.precomputed_data and precomputed1 and precomputed2:
        x1 = params.correlation.x1 + rowindex1 * n
        x2 = params.correlation.x2 + rowindex2 * n

        i1 = 0
        i2 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = 0
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            if i2 < n2:
                if ind2[i2] < i:
                    i2 += 1
                    if i2 < n2:
                        if ind2[i2] == i:
                            x2i = x2[i2]
                elif ind2[i2] == i:
                    x2i = x2[i2]
            x1Tx2 += x1i * x2i

        normalization = params.correlation.norms1[rowindex1]
        normalization *= params.correlation.norms2[rowindex2]

    else:
        i1 = 0
        i2 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = 0
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            if i2 < n2:
                if ind2[i2] < i:
                    i2 += 1
                    if i2 < n2:
                        if ind2[i2] == i:
                            x2i = x2[i2]
                elif ind2[i2] == i:
                    x2i = x2[i2]
            mu1 += x1i
            mu2 += x2i
        mu1 /= n
        mu2 /= n

        i1 = 0
        i2 = 0
        for i from 0 <= i < n:
            x1i = 0
            x2i = 0
            if i1 < n1:
                if ind1[i1] < i:
                    i1 += 1
                    if i1 < n1:
                        if ind1[i1] == i:
                            x1i = x1[i1]
                elif ind1[i1] == i:
                    x1i = x1[i1]
            if i2 < n2:
                if ind2[i2] < i:
                    i2 += 1
                    if i2 < n2:
                        if ind2[i2] == i:
                            x2i = x2[i2]
                elif ind2[i2] == i:
                    x2i = x2[i2]
            tmp1 = x1i - mu1
            tmp2 = x2i - mu2
            x1nrm += tmp1 * tmp1
            x2nrm += tmp2 * tmp2
            x1Tx2 += tmp1 * tmp2

        normalization = sqrt(x1nrm * x2nrm)

    return 1. - x1Tx2 / normalization


#======================================================================
# Mahalanobis Distance
#
# D(x, y) = sqrt[(x - y)^T V^-1 (x - y)]
#
cdef DTYPE_t mahalanobis_distance(DTYPE_t* x1, DTYPE_t* x2,
                                  int n, dist_params* params,
                                  int rowindex1,
                                  int rowindex2):
    return sqrt(sqmahalanobis_distance(x1, x2, n, params,
                                       rowindex1, rowindex2))


cdef DTYPE_t mahalanobis_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, int n,
                                       dist_params* params,
                                       int rowindex1, int rowindex2):
    return sqrt(sqmahalanobis_distance_spde(x1, ind1, n1, x2, n, params,
                                            rowindex1, rowindex2))


cdef DTYPE_t mahalanobis_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                       int n, dist_params* params,
                                       int rowindex1, int rowindex2):
    return sqrt(sqmahalanobis_distance_spsp(x1, ind1, n1, x2, ind2, n2,
                                            n, params,
                                            rowindex1, rowindex2))


#======================================================================
# Squared Mahalanobis Distance
#
# D(x, y) = (x - y)^T V^-1 (x - y)
#
cdef DTYPE_t sqmahalanobis_distance(DTYPE_t* x1, DTYPE_t* x2,
                                    int n, dist_params* params,
                                    int rowindex1,
                                    int rowindex2):
    cdef int j
    cdef DTYPE_t d, res = 0

    assert n == params.mahalanobis.n

    # TODO: use blas here
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        params.mahalanobis.work_buffer[i] = x1i - x2i

    for i from 0 <= i < n:
        d = 0
        for j from 0 <= j < n:
            d += (params.mahalanobis.VI[i * n + j]
                  * params.mahalanobis.work_buffer[j])
        res += d * params.mahalanobis.work_buffer[i]

    return res


cdef DTYPE_t sqmahalanobis_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                         DTYPE_t* x2, int n,
                                         dist_params* params,
                                         int rowindex1, int rowindex2):
    cdef int j
    cdef DTYPE_t d, res = 0

    assert n == params.mahalanobis.n

    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        params.mahalanobis.work_buffer[i] = x1i - x2i

    for i from 0 <= i < n:
        d = 0
        for j from 0 <= j < n:
            d += (params.mahalanobis.VI[i * n + j]
                  * params.mahalanobis.work_buffer[j])
        res += d * params.mahalanobis.work_buffer[i]

    return res


cdef DTYPE_t sqmahalanobis_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                         DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                         int n, dist_params* params,
                                         int rowindex1, int rowindex2):
    cdef int j
    cdef DTYPE_t d, res = 0

    assert n == params.mahalanobis.n

    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        params.mahalanobis.work_buffer[i] = x1i - x2i

    for i from 0 <= i < n:
        d = 0
        for j from 0 <= j < n:
            d += (params.mahalanobis.VI[i * n + j]
                  * params.mahalanobis.work_buffer[j])
        res += d * params.mahalanobis.work_buffer[i]

    return res


#======================================================================
# Hamming Distance
#
# D(x, y) = N_unequal(x, y) / N
#
@cython.cdivision(True)
cdef DTYPE_t hamming_distance(DTYPE_t* x1, DTYPE_t* x2,
                              int n, dist_params* params,
                              int rowindex1,
                              int rowindex2):
    cdef int n_disagree = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        if x1i != x2i:
            n_disagree += 1
    return <DTYPE_t>n_disagree / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t hamming_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                   DTYPE_t* x2, int n,
                                   dist_params* params,
                                   int rowindex1, int rowindex2):
    cdef int n_disagree = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if x1i != x2i:
            n_disagree += 1
    return <DTYPE_t>n_disagree / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t hamming_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                   DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                   int n, dist_params* params,
                                   int rowindex1, int rowindex2):
    cdef int n_disagree = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        if x1i != x2i:
            n_disagree += 1
    return <DTYPE_t>n_disagree / <DTYPE_t>n


#======================================================================
# Jaccard Distance
#
# D(x, y) = N_unequal(x, y) / N_nonzero(x, y)
#
@cython.cdivision(True)
cdef DTYPE_t jaccard_distance(DTYPE_t* x1, DTYPE_t* x2,
                              int n, dist_params* params,
                              int rowindex1,
                              int rowindex2):
    cdef int num = 0, denom = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        if (x1i != 0) or (x2i != 0):
            denom += 1
            if x1i != x2i:
                num += 1
    return <DTYPE_t>num / <DTYPE_t>denom


@cython.cdivision(True)
cdef DTYPE_t jaccard_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                   DTYPE_t* x2, int n,
                                   dist_params* params,
                                   int rowindex1, int rowindex2):
    cdef int num = 0, denom = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if (x1i != 0) or (x2i != 0):
            denom += 1
            if x1i != x2i:
                num += 1
    return <DTYPE_t>num / <DTYPE_t>denom


@cython.cdivision(True)
cdef DTYPE_t jaccard_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                   DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                   int n, dist_params* params,
                                   int rowindex1, int rowindex2):
    cdef int num = 0, denom = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        if (x1i != 0) or (x2i != 0):
            denom += 1
            if x1i != x2i:
                num += 1
    return <DTYPE_t>num / <DTYPE_t>denom


#======================================================================
# Canberra Distance
#
# D(x, y) = sum_i abs(x_i - y_i) / (abs(x_i) + abs(y_i))
#
@cython.cdivision(True)
cdef DTYPE_t canberra_distance(DTYPE_t* x1, DTYPE_t* x2,
                               int n, dist_params* params,
                               int rowindex1,
                               int rowindex2):
    cdef DTYPE_t res = 0, denom
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        denom = fabs(x1i) + fabs(x2i)
        if denom > 0:
            res += fabs(x1i - x2i) / denom
    return res


@cython.cdivision(True)
cdef DTYPE_t canberra_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                    DTYPE_t* x2, int n,
                                    dist_params* params,
                                    int rowindex1, int rowindex2):
    cdef DTYPE_t res = 0, denom
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        denom = fabs(x1i) + fabs(x2i)
        if denom > 0:
            res += fabs(x1i - x2i) / denom
    return res


@cython.cdivision(True)
cdef DTYPE_t canberra_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                    DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                    int n, dist_params* params,
                                    int rowindex1, int rowindex2):
    cdef DTYPE_t res = 0, denom
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        denom = fabs(x1i) + fabs(x2i)
        if denom > 0:
            res += fabs(x1i - x2i) / denom
    return res


#======================================================================
# Bray-Curtis Distance
#
# D(x, y) = sum_i [abs(x_i - y_i)] / sum_i [abs(x_i) + abs(y_i)]
#
@cython.cdivision(True)
cdef DTYPE_t braycurtis_distance(DTYPE_t* x1, DTYPE_t* x2,
                                 int n, dist_params* params,
                                 int rowindex1,
                                 int rowindex2):
    cdef DTYPE_t num = 0, denom = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        num += fabs(x1i - x2i)
        denom += fabs(x1i) + fabs(x2i)
    return num / denom


@cython.cdivision(True)
cdef DTYPE_t braycurtis_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, int n,
                                      dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t num = 0, denom = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        num += fabs(x1i - x2i)
        denom += fabs(x1i) + fabs(x2i)
    return num / denom


@cython.cdivision(True)
cdef DTYPE_t braycurtis_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                      int n, dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef DTYPE_t num = 0, denom = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        num += fabs(x1i - x2i)
        denom += fabs(x1i) + fabs(x2i)
    return num / denom


#======================================================================
# Yule Distance
#
# D(x, y) = 2 * ntf * nft / (ntt * nff + ntf * nft)
#
@cython.cdivision(True)
cdef DTYPE_t yule_distance(DTYPE_t* x1, DTYPE_t* x2,
                           int n, dist_params* params,
                           int rowindex1,
                           int rowindex2):
    cdef int TF1, TF2, ntt = 0, nff = 0, ntf = 0, nft = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        nff += (1 - TF1) and (1 - TF2)
        nft += (1 - TF1) and TF2
        ntf += TF1 and (1 - TF2)
        ntt += TF1 and TF2
    return <DTYPE_t>(2 * ntf * nft) / <DTYPE_t>(ntt * nff + ntf * nft)


@cython.cdivision(True)
cdef DTYPE_t yule_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, int n,
                                dist_params* params,
                                int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, nff = 0, ntf = 0, nft = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        nff += (1 - TF1) and (1 - TF2)
        nft += (1 - TF1) and TF2
        ntf += TF1 and (1 - TF2)
        ntt += TF1 and TF2
    return <DTYPE_t>(2 * ntf * nft) / <DTYPE_t>(ntt * nff + ntf * nft)


@cython.cdivision(True)
cdef DTYPE_t yule_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                int n, dist_params* params,
                                int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, nff = 0, ntf = 0, nft = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        nff += (1 - TF1) and (1 - TF2)
        nft += (1 - TF1) and TF2
        ntf += TF1 and (1 - TF2)
        ntt += TF1 and TF2
    return <DTYPE_t>(2 * ntf * nft) / <DTYPE_t>(ntt * nff + ntf * nft)


#======================================================================
# Matching Distance
#
# D(x, y) = (ntf + nft) / n
#
@cython.cdivision(True)
cdef DTYPE_t matching_distance(DTYPE_t* x1, DTYPE_t* x2,
                               int n, dist_params* params,
                               int rowindex1,
                               int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1 != TF2:
            n_neq += 1

    return <DTYPE_t>n_neq / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t matching_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                    DTYPE_t* x2, int n,
                                    dist_params* params,
                                    int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1 != TF2:
            n_neq += 1

    return <DTYPE_t>n_neq / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t matching_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                    DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                    int n, dist_params* params,
                                    int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1 != TF2:
            n_neq += 1

    return <DTYPE_t>n_neq / <DTYPE_t>n


#======================================================================
# Dice Distance
#
# D(x, y) = (ntf + nft) / (2 * ntt + ntf + nft)
#
@cython.cdivision(True)
cdef DTYPE_t dice_distance(DTYPE_t* x1, DTYPE_t* x2,
                           int n, dist_params* params,
                           int rowindex1,
                           int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += (TF1 and TF2)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(ntt + ntt + n_neq)


@cython.cdivision(True)
cdef DTYPE_t dice_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, int n,
                                dist_params* params,
                                int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += (TF1 and TF2)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(ntt + ntt + n_neq)


@cython.cdivision(True)
cdef DTYPE_t dice_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                int n, dist_params* params,
                                int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += (TF1 and TF2)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(ntt + ntt + n_neq)


#======================================================================
# Kulsinski Distance
#
# D(x, y) = (ntf + nft - ntt + n) / (n_neq + n)
#
@cython.cdivision(True)
cdef DTYPE_t kulsinski_distance(DTYPE_t* x1, DTYPE_t* x2,
                                int n, dist_params* params,
                                int rowindex1,
                                int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += TF1 * TF2
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq - ntt + n) / <DTYPE_t>(n_neq + n)


@cython.cdivision(True)
cdef DTYPE_t kulsinski_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, int n,
                                     dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += TF1 * TF2
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq - ntt + n) / <DTYPE_t>(n_neq + n)


@cython.cdivision(True)
cdef DTYPE_t kulsinski_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                     DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                     int n, dist_params* params,
                                     int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        ntt += TF1 * TF2
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq - ntt + n) / <DTYPE_t>(n_neq + n)


#======================================================================
# Roger-Stanimoto Distance
#
# D(x, y) = 2 * n_neq / (n + n_neq)
#
@cython.cdivision(True)
cdef DTYPE_t rogerstanimoto_distance(DTYPE_t* x1, DTYPE_t* x2,
                                     int n, dist_params* params,
                                     int rowindex1,
                                     int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


@cython.cdivision(True)
cdef DTYPE_t rogerstanimoto_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                          DTYPE_t* x2, int n,
                                          dist_params* params,
                                          int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


@cython.cdivision(True)
cdef DTYPE_t rogerstanimoto_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                          DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                          int n, dist_params* params,
                                          int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


#======================================================================
# Russell-Rao Distance
#
# D(x, y) = (n - ntt) / n
#
@cython.cdivision(True)
cdef DTYPE_t russellrao_distance(DTYPE_t* x1, DTYPE_t* x2,
                                 int n, dist_params* params,
                                 int rowindex1,
                                 int rowindex2):
    cdef int TF1, TF2, ntt = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1

    return <DTYPE_t>(n - ntt) / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t russellrao_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, int n,
                                      dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1

    return <DTYPE_t>(n - ntt) / <DTYPE_t>n


@cython.cdivision(True)
cdef DTYPE_t russellrao_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                      DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                      int n, dist_params* params,
                                      int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1

    return <DTYPE_t>(n - ntt) / <DTYPE_t>n


#======================================================================
# Sokal-Michener Distance
#
# D(x, y) = 2 * n_neq / (n + n_neq)
#
@cython.cdivision(True)
cdef DTYPE_t sokalmichener_distance(DTYPE_t* x1, DTYPE_t* x2,
                                    int n, dist_params* params,
                                    int rowindex1,
                                    int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


@cython.cdivision(True)
cdef DTYPE_t sokalmichener_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                         DTYPE_t* x2, int n,
                                         dist_params* params,
                                         int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


@cython.cdivision(True)
cdef DTYPE_t sokalmichener_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                         DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                         int n, dist_params* params,
                                         int rowindex1, int rowindex2):
    cdef int TF1, TF2, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        n_neq += (TF1 != TF2)

    return <DTYPE_t>(n_neq + n_neq) / <DTYPE_t>(n + n_neq)


#======================================================================
# Sokal-Sneath Distance
#
# D(x, y) = n_neq / (n_tt / 2 + n_neq)
#
@cython.cdivision(True)
cdef DTYPE_t sokalsneath_distance(DTYPE_t* x1, DTYPE_t* x2,
                                  int n, dist_params* params,
                                  int rowindex1,
                                  int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i
    cdef DTYPE_t x1i, x2i
    for i from 0 <= i < n:
        x1i = x1[i]
        x2i = x2[i]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(0.5 * ntt + n_neq)


@cython.cdivision(True)
cdef DTYPE_t sokalsneath_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, int n,
                                       dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i1, i
    cdef DTYPE_t x1i, x2i
    i1 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = x2[i]        
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(0.5 * ntt + n_neq)


@cython.cdivision(True)
cdef DTYPE_t sokalsneath_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                       DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                       int n, dist_params* params,
                                       int rowindex1, int rowindex2):
    cdef int TF1, TF2, ntt = 0, n_neq = 0
    cdef int i, i1, i2
    cdef DTYPE_t x1i, x2i
    i1 = 0
    i2 = 0
    for i from 0 <= i < n:
        x1i = 0
        x2i = 0
        if i1 < n1:
            if ind1[i1] < i:
                i1 += 1
                if i1 < n1:
                    if ind1[i1] == i:
                        x1i = x1[i1]
            elif ind1[i1] == i:
                x1i = x1[i1]
        if i2 < n2:
            if ind2[i2] < i:
                i2 += 1
                if i2 < n2:
                    if ind2[i2] == i:
                        x2i = x2[i2]
            elif ind2[i2] == i:
                x2i = x2[i2]
        TF1 = (x1i != 0)
        TF2 = (x2i != 0)
        if TF1:
            if TF2:
                ntt += 1
        n_neq += (TF1 != TF2)

    return <DTYPE_t>n_neq / <DTYPE_t>(0.5 * ntt + n_neq)


#======================================================================
# User-defined Distance
#
# call a python distance function at each point
#
@cython.cdivision(True)
cdef DTYPE_t user_distance(DTYPE_t* x1, DTYPE_t* x2,
                           int n, dist_params* params,
                           int rowindex1,
                           int rowindex2):
    cdef np.ndarray y1 = _buffer_to_ndarray(x1, n)
    cdef np.ndarray y2 = _buffer_to_ndarray(x2, n)
    return (<object>(params.user.func))(y1, y2)


@cython.cdivision(True)
cdef DTYPE_t user_distance_spde(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, int n,
                                dist_params* params,
                                int rowindex1, int rowindex2):
    cdef np.ndarray y1 = np.zeros(n, dtype=DTYPE)
    cdef DTYPE_t* y1data = <DTYPE_t*>y1.data
    cdef np.ndarray y2 = _buffer_to_ndarray(x2, n)

    cdef int i
    for i from 0 <= i < n1:
        y1data[ind1[i]] = x1[i]

    return (<object>(params.user.func))(y1, y2)


@cython.cdivision(True)
cdef DTYPE_t user_distance_spsp(DTYPE_t* x1, ITYPE_t* ind1, int n1,
                                DTYPE_t* x2, ITYPE_t* ind2, int n2,
                                int n, dist_params* params,
                                int rowindex1, int rowindex2):
    cdef np.ndarray y1 = np.zeros(n, dtype=DTYPE)
    cdef np.ndarray y2 = np.zeros(n, dtype=DTYPE)

    cdef DTYPE_t* y1data = <DTYPE_t*>y1.data
    cdef DTYPE_t* y2data = <DTYPE_t*>y2.data

    cdef int i
    for i from 0 <= i < n1:
        y1data[ind1[i]] = x1[i]
    for i from 0 <= i < n2:
        y2data[ind2[i]] = x2[i]

    return (<object>(params.user.func))(y1, y2)
