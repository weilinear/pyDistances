# Author: Jake Vanderplas <vanderplas@astro.washington.edu>
# License: BSD

# TODO:
#  - documentation update with metrics
#
#  - currently all metrics are used without precomputed values.
#    Allowing precomputed values could speed computation with some metrics.
#
#  - KDBound: doesn't work for chebyshev
#
#  - correlation function query
#
# Other Thoughts:
#  what about using fibonacci heaps to keep track of visited nodes?  This is
#  fairly easy to try out with the HeapBase abstraction.

"""
=========
Ball Tree
=========
A ball tree is a data object which speeds up nearest neighbor
searches in high dimensions (see scikit-learn neighbors module
documentation for an overview of neighbor trees). There are many
types of ball trees.  This package provides a basic implementation
in cython.

Implementation Notes
--------------------

A ball tree can be thought of as a collection of nodes.  Each node
stores a centroid, a radius, and the pointers to two child nodes.

* centroid : the centroid of a node is the mean of all the locations
    of points within the node
* radius : the radius of a node is the distance from the centroid
    to the furthest point in the node.
* subnodes : each node has a maximum of 2 child nodes.  The data within
    the parent node is divided between the two child nodes.

In a typical tree implementation, nodes may be classes or structures which
are dynamically allocated as needed.  This offers flexibility in the number
of nodes, and leads to very straightforward and readable code.  It also means
that the tree can be dynamically augmented or pruned with new data, in an
in-line fashion.  This approach generally leads to recursive code: upon
construction, the head node constructs its child nodes, the child nodes
construct their child nodes, and so-on.

For an illustration of this sort of approach, refer to slow_ball_tree.py, which
is a python-only implementation designed for readibility rather than speed.

The current package uses a different approach: all node data is stored in
a set of numpy arrays which are pre-allocated.  The main advantage of this
approach is that the whole object can be quickly and easily saved to disk
and reconstructed from disk.  This also allows for an iterative interface
which gives more control over the heap, and leads to speed.  There are a
few disadvantages, however: once the tree is built, augmenting or pruning it
is not as straightforward.  Also, the size of the tree must be known from the
start, so there is not as much flexibility in building it.

BallTree Storage
~~~~~~~~~~~~~~~~
The BallTree information is stored using a combination of
"Array of Structures" and "Structure of Arrays" to maximize speed.
Given input data of size ``(n_samples, n_features)``, BallTree computes the
expected number of nodes ``n_nodes`` (see below), and allocates the
following arrays:

* ``data`` : a float array of shape ``(n_samples, n_features)``
    This is simply the input data.  If the input matrix is well-formed
    (contiguous, c-ordered, correct data type) then no copy is needed
* ``idx_array`` : an integer array of size ``n_samples``
    This can be thought of as an array of pointers to the data in ``data``.
    Rather than shuffling around the data itself, we shuffle around pointers
    to the rows in data.
* ``node_centroid_arr`` : a float array of shape ``(n_nodes, n_features)``
    This stores the centroid of the data in each node.
* ``node_info_arr`` : a size-``n_nodes`` array of ``NodeInfo`` structures.
    This stores information associated with each node.  Each ``NodeInfo``
    instance has the following attributes:
    - ``idx_start``
    - ``idx_end`` : ``idx_start`` and ``idx_end`` reference the part of
      ``idx_array`` which point to the data associated with the node.
      The data in node with index ``i_node`` is given by
      ``data[idx_array[idx_start:idx_end]]``
    - ``is_leaf`` : a boolean value which tells whether this node is a leaf:
      that is, whether or not it has children.
    - ``radius`` : a floating-point value which gives the distance from
      the node centroid to the furthest point in the node.

One feature here is that there are no stored pointers from parent nodes to
child nodes and vice-versa.  These pointers are implemented implicitly:
For a node with index ``i``, the two children are found at indices
``2 * i + 1`` and ``2 * i + 2``, while the parent is found at index
``floor((i - 1) / 2)``.  The root node has no parent.

With this data structure in place, the functionality of the above BallTree
pseudo-code can be implemented in a much more efficient manner.
Most of the data passing done in this code uses raw data pointers.
Using numpy arrays would be preferable for indexing safety, but the
overhead of array slicing and sub-array construction leads to execution
time which is several orders of magnitude slower than the current
implementation.

Priority Queue vs Max-heap
~~~~~~~~~~~~~~~~~~~~~~~~~~
When querying for more than one neighbor, the code must maintain a list of
the current k nearest points.  The BallTree code implements this in two ways.

- A priority queue: this is simply a sorted list.  When an item is added,
  it is inserted in the appropriate location.  The cost of the search plus
  insert averages O[k].
- A max-heap: this is a binary tree structure arranged such that each node is
  greater than its children.  The cost of adding an item is O[log(k)].
  At the end of the iterations, the results must be sorted: a quicksort is
  used, which averages O[k log(k)].  Quicksort has worst-case O[k^2]
  performance, but because the input is already structured in a max-heap,
  the worst case will not be realized.  Thus the sort is a one-time operation
  with cost O[k log(k)].

Each insert is performed an average of log(N) times per query, where N is
the number of training points.  Because of this, for a single query, the
priority-queue approach costs O[k log(N)], and the max-heap approach costs
O[log(k)log(N)] + O[k log(k)].  Empirical tests show that for sufficiently
large k, the max-heap approach out-performs the priority queue approach by
a factor of a few.  In light of these tests, the code uses a priority queue
for k < 5, and a max-heap otherwise.

Memory Allocation
~~~~~~~~~~~~~~~~~
It is desirable to construct a tree in as balanced a way as possible.
Given a training set with n_samples and a user-supplied leaf_size, if
the points in each node are divided as evenly as possible between the
two children, the maximum depth needed so that leaf nodes satisfy
``leaf_size <= n_points <= 2 * leaf_size`` is given by
``n_levels = 1 + max(0, floor(log2((n_samples - 1) / leaf_size)))``
(with the exception of the special case where ``n_samples <= leaf_size``)
For a given number of levels, the number of points in a tree is given by
``n_nodes = 2 ** n_levels - 1``.  Both of these results can be shown
by induction.  Using them, the correct amount of memory can be pre-allocated
for a given ``n_samples`` and ``leaf_size``.
"""
import numpy as np

cimport numpy as np
cimport cython
from libc.math cimport fmax, fmin, fabs

from distmetrics cimport DistanceMetric, DTYPE_t
from distmetrics import DTYPE

# validation function ported from scikit-learn (sklearn.utils.array2d)
def array2d(X, dtype=None, order=None):
    """Returns at least 2-d array with data from X"""
    return np.asarray(np.atleast_2d(X), dtype=dtype, order=order)

######################################################################
# global definitions

# type used for indices & counts
# warning: there will be problems if ITYPE is switched to an unsigned type!
ITYPE = np.int32
ctypedef np.int32_t ITYPE_t

# explicitly define infinity
cdef DTYPE_t INF = np.inf

######################################################################
# NodeInfo struct
#  used to keep track of node information.
#  there is also a centroid for each node: this is kept in a separate
#  array for efficiency.  This is a hybrid of the "Array of Structures"
#  and "Structure of Arrays" styles.
cdef struct NodeInfo:
    ITYPE_t idx_start
    ITYPE_t idx_end
    ITYPE_t is_leaf
    DTYPE_t radius # radius is used for BallTree

######################################################################
# newObj function
#  this is a helper function for pickling
def newObj(obj):
    return obj.__new__(obj)

######################################################################
# Invalid metrics
#
# These are not true metrics (they don't satisfy the triangle inequality)
# so BallTree will not work with them
INVALID_METRICS = ['sqeuclidean', 'correlation', 'pminkowski',
                   'pwminkowski', 'sqseuclidean', 'sqmahalanobis']

######################################################################
# BinaryTree class.
# This is a base class for tree-based N-point queries
cdef class _BinaryTree(object):
    """Base class for KDTree and BallTree"""
    cdef readonly np.ndarray data
    cdef np.ndarray idx_array
    cdef np.ndarray node_info_arr
    cdef np.ndarray node_data_arr1
    cdef np.ndarray node_data_arr2

    cdef ITYPE_t leaf_size
    cdef ITYPE_t n_levels
    cdef ITYPE_t n_nodes

    cdef DistanceMetric dm
    cdef BoundBase bound
    cdef HeapBase heap

    cdef int n_trims
    cdef int n_leaves
    cdef int n_splits

    def get_stats(self):
        return (self.n_trims, self.n_leaves, self.n_splits)

    def get_arrays(self):
        return (self.data, self.idx_array,
                self.node_data_arr1, self.node_data_arr2)

    def __cinit__(self):
        """
        initialize all arrays to empty.  This will prevent memory errors
        in rare cases where __init__ is not called
        """
        self.data = np.zeros((0,0), dtype=DTYPE)
        self.idx_array = np.zeros(0, dtype=ITYPE)
        self.node_data_arr1 = np.zeros((0,0), dtype=DTYPE)
        self.node_data_arr2 = np.zeros((0,0), dtype=DTYPE)
        self.node_info_arr = np.zeros(0, dtype='c')
        
        self.dm = DistanceMetric()
        self.bound = BoundBase()
        self.heap = HeapBase()

    def __init__(self, X, leaf_size=20, metric="minkowski", p=2, **kwargs):
        raise ValueError("_BinaryTree cannot be instantiated on its own")

    def __init_metric(self, metric, **kwargs):
        if isinstance(metric, DistanceMetric):
            self.dm = metric
            metric = self.dm.metric
        else:
            self.dm = DistanceMetric(metric, **kwargs)

    def __init_common(self, X, leaf_size=20, data1=True, data2=False):
        """Common initialization steps"""
        self.data = np.asarray(X, dtype=DTYPE, order='C')

        if self.data.size == 0:
            raise ValueError("X is an empty array")

        if self.data.ndim != 2:
            raise ValueError("X should have two dimensions")

        if leaf_size < 1:
            raise ValueError("leaf_size must be greater than or equal to 1")
        self.leaf_size = leaf_size
        
        cdef ITYPE_t n_samples = self.data.shape[0]
        cdef ITYPE_t n_features = self.data.shape[1]

        # set up dist_metric
        if self.dm.learn_params_from_data:
            self.dm.set_params_from_data(self.data)

        # determine number of levels in the tree, and from this
        # the number of nodes in the tree.  This results in leaf nodes
        # with numbers of points betweeen leaf_size and 2 * leaf_size
        # (see module-level doc string for details)
        self.n_levels = np.log2(fmax(1, (n_samples - 1) / self.leaf_size)) + 1
        self.n_nodes = (2 ** self.n_levels) - 1

        # allocate arrays for storage
        self.idx_array = np.arange(n_samples, dtype=ITYPE)
        self.node_info_arr = np.zeros(self.n_nodes * sizeof(NodeInfo),
                                      dtype='c', order='C')

        if data1:
            self.node_data_arr1 = np.zeros((self.n_nodes, n_features),
                                           dtype=DTYPE, order='C')
        if data2:
            self.node_data_arr2 = np.zeros((self.n_nodes, n_features),
                                           dtype=DTYPE, order='C')
        
        self._recursive_build(0, 0, n_samples)

    def __reduce__(self):
        """reduce method used for pickling"""
        return (newObj, (self.__class__,), self.__getstate__())

    def __getstate__(self):
        """get state for pickling"""
        return (self.data,
                self.idx_array,
                self.node_data_arr1,
                self.node_data_arr2,
                self.node_info_arr,
                self.leaf_size,
                self.n_levels,
                self.n_nodes,
                self.dm,
                self.bound)

    def __setstate__(self, state):
        """set state for pickling"""
        (self.data,
         self.idx_array,
         self.node_data_arr1,
         self.node_data_arr2,
         self.node_info_arr,
         self.leaf_size,
         self.n_levels,
         self.n_nodes,
         self.dm,
         self.bound) = state

    def query(self, X, k=1, return_distance=True, dualtree=False):
        """
        query(X, k=1, return_distance=True)

        query the Ball Tree for the k nearest neighbors

        Parameters
        ----------
        X : array-like, last dimension self.n_features
            An array of points to query
        k : integer  (default = 1)
            The number of nearest neighbors to return
        return_distance : boolean (default = True)
            if True, return a tuple (d,i)
            if False, return array i

        Returns
        -------
        i    : if return_distance == False
        (d, i) : if return_distance == True

        d : array of doubles - shape: x.shape[:-1] + (k,)
            each entry gives the sorted list of distances to the
            neighbors of the corresponding point

        i : array of integers - shape: x.shape[:-1] + (k,)
            each entry gives the sorted list of indices of
            neighbors of the corresponding point

        Examples
        --------
        Query for k-nearest neighbors

            # >>> import numpy as np
            # >>> np.random.seed(0)
            # >>> X = np.random.random((10,3))  # 10 points in 3 dimensions
            # >>> ball_tree = BallTree(X, leaf_size=2)
            # >>> dist, ind = ball_tree.query(X[0], k=3)
            # >>> print ind  # indices of 3 closest neighbors
            # [0 3 1]
            # >>> print dist  # distances to 3 closest neighbors
            # [ 0.          0.19662693  0.29473397]
        """
        cdef ITYPE_t n_neighbors = k
        cdef ITYPE_t n_features = self.data.shape[1]
        X = array2d(X, dtype=DTYPE, order='C')

        if X.shape[-1] != n_features:
            raise ValueError("query data dimension must match BallTree "
                             "data dimension")

        if self.data.shape[0] < n_neighbors:
            raise ValueError("k must be less than or equal "
                             "to the number of training points")

        # flatten X, and save original shape information
        orig_shape = X.shape
        X = X.reshape((-1, n_features))

        cdef ITYPE_t n_queries = X.shape[0]

        # allocate distances and indices for return
        cdef np.ndarray distances = np.zeros((X.shape[0], n_neighbors),
                                             dtype=DTYPE)
        distances.fill(INF)

        cdef np.ndarray idx_array = np.zeros((X.shape[0], n_neighbors),
                                             dtype=ITYPE)
        cdef np.ndarray Xarr = X

        # define some variables needed for the computation
        cdef np.ndarray bounds
        cdef ITYPE_t i
        cdef DTYPE_t* pt
        #cdef DTYPE_t* dist_ptr = <DTYPE_t*> distances.data
        cdef DTYPE_t* dist_ptr = <DTYPE_t*> np.PyArray_DATA(distances)
        #cdef ITYPE_t* idx_ptr = <ITYPE_t*> idx_array.data
        cdef ITYPE_t* idx_ptr = <ITYPE_t*> np.PyArray_DATA(idx_array)
        cdef DTYPE_t reduced_dist_LB
        
        # create heap/queue object for holding results
        if n_neighbors == 1:
            self.heap = OneItemHeap()
        elif n_neighbors >= 5:
            self.heap = MaxHeap()
        else:
            self.heap = PriorityQueue()
        self.heap.init(dist_ptr, idx_ptr, n_neighbors)

        self.n_trims = 0
        self.n_leaves = 0
        self.n_splits = 0

        if dualtree:
            # build a tree on query data with the same metric as self
            other = self.__class__(X, leaf_size=self.leaf_size,
                                   metric=self.dm,
                                   **self.dm.init_kwargs)

            reduced_dist_LB = self.bound.min_rdist_dual(self, 0, other, 0)

            # bounds store the current furthest neighbor which is stored
            # in each node of the "other" tree.  This makes it so that we
            # don't need to repeatedly search every point in the node.
            bounds = np.empty(other.data.shape[0])
            bounds.fill(INF)

            self.query_dual_(0, other, 0, n_neighbors,
                             dist_ptr, idx_ptr, reduced_dist_LB,
                             #<DTYPE_t*> bounds.data)
                            <DTYPE_t*> np.PyArray_DATA(bounds))

        else:
            pt = <DTYPE_t*> np.PyArray_DATA(Xarr)
            #pt = <DTYPE_t*> Xarr.data
            for i in range(Xarr.shape[0]):
                reduced_dist_LB = self.bound.min_rdist(self, 0, pt)
                self.query_one_(0, pt, n_neighbors,
                                dist_ptr, idx_ptr, reduced_dist_LB)

                dist_ptr += n_neighbors
                idx_ptr += n_neighbors
                pt += n_features

        dist_ptr = <DTYPE_t*> np.PyArray_DATA(distances)
        idx_ptr = <ITYPE_t*> np.PyArray_DATA(idx_array)
        #dist_ptr = <DTYPE_t*> distances.data
        #idx_ptr = <ITYPE_t*> idx_array.data
        for i in range(n_neighbors * n_queries):
            dist_ptr[i] = self.dm.reduced_to_dist(dist_ptr[i],
                                                  &self.dm.params)
        if self.heap.needs_final_sort():
            for i in range(n_queries):
                sort_dist_idx(dist_ptr, idx_ptr, n_neighbors)
                dist_ptr += n_neighbors
                idx_ptr += n_neighbors

        # deflatten results
        if return_distance:
            return (distances.reshape((orig_shape[:-1]) + (k,)),
                    idx_array.reshape((orig_shape[:-1]) + (k,)))
        else:
            return idx_array.reshape((orig_shape[:-1]) + (k,))

    def query_radius(self, X, r, return_distance=False,
                     int count_only=False, int sort_results=False):
        """
        query_radius(self, X, r, return_distance=False,
                     count_only = False, sort_results=False):

        query the Ball Tree for neighbors within a ball of size r

        Parameters
        ----------
        X : array-like, last dimension self.dim
            An array of points to query
        r : distance within which neighbors are returned
            r can be a single value, or an array of values of shape
            x.shape[:-1] if different radii are desired for each point.
        return_distance : boolean (default = False)
            if True,  return distances to neighbors of each point
            if False, return only neighbors
            Note that unlike BallTree.query(), setting return_distance=True
            adds to the computation time.  Not all distances need to be
            calculated explicitly for return_distance=False.  Results are
            not sorted by default: see ``sort_results`` keyword.
        count_only : boolean (default = False)
            if True,  return only the count of points within distance r
            if False, return the indices of all points within distance r
            If return_distance==True, setting count_only=True will
            result in an error.
        sort_results : boolean (default = False)
            if True, the distances and indices will be sorted before being
            returned.  If False, the results will not be sorted.  If
            return_distance == False, setting sort_results = True will
            result in an error.

        Returns
        -------
        count       : if count_only == True
        ind         : if count_only == False and return_distance == False
        (ind, dist) : if count_only == False and return_distance == True

        count : array of integers, shape = X.shape[:-1]
            each entry gives the number of neighbors within
            a distance r of the corresponding point.

        ind : array of objects, shape = X.shape[:-1]
            each element is a numpy integer array listing the indices of
            neighbors of the corresponding point.  Note that unlike
            the results of BallTree.query(), the returned neighbors
            are not sorted by distance

        dist : array of objects, shape = X.shape[:-1]
            each element is a numpy double array
            listing the distances corresponding to indices in i.

        Examples
        --------
        Query for neighbors in a given radius

        # >>> import numpy as np
        # >>> np.random.seed(0)
        # >>> X = np.random.random((10,3))  # 10 points in 3 dimensions
        # >>> ball_tree = BallTree(X, leaf_size=2)
        # >>> print ball_tree.query_radius(X[0], r=0.3, count_only=True)
        # 3
        # >>> ind = ball_tree.query_radius(X[0], r=0.3)
        # >>> print ind  # indices of neighbors within distance 0.3
        # [3 0 1]
        """
        if count_only and return_distance:
            raise ValueError("count_only and return_distance "
                             "cannot both be true")

        if sort_results and not return_distance:
            raise ValueError("return_distance must be True "
                             "if sort_results is True")

        cdef np.ndarray idx_array, idx_array_i, distances, distances_i
        cdef np.ndarray pt, count
        cdef ITYPE_t count_i = 0
        cdef ITYPE_t n_features = self.data.shape[1]

        # prepare X for query
        X = array2d(X, dtype=DTYPE, order='C')
        if X.shape[-1] != self.data.shape[1]:
            raise ValueError("query data dimension must match BallTree "
                             "data dimension")

        # prepare r for query
        r = np.asarray(r, dtype=DTYPE, order='C')
        r = np.atleast_1d(r)
        if r.shape == (1,):
            r = r[0] * np.ones(X.shape[:-1], dtype=DTYPE)
        else:
            if r.shape != X.shape[:-1]:
                raise ValueError("r must be broadcastable to X.shape")

        # flatten X and r for iteration
        orig_shape = X.shape
        X = X.reshape((-1, X.shape[-1]))
        r = r.reshape(-1)
        
        cdef np.ndarray Xarr = X
        cdef np.ndarray rarr = r

        cdef DTYPE_t* Xdata = <DTYPE_t*> np.PyArray_DATA(Xarr)
        cdef DTYPE_t* rdata = <DTYPE_t*> np.PyArray_DATA(rarr)
        #cdef DTYPE_t* Xdata = <DTYPE_t*> Xarr.data
        #cdef DTYPE_t* rdata = <DTYPE_t*> rarr.data

        cdef ITYPE_t i

        # prepare variables for iteration
        if not count_only:
            idx_array = np.zeros(X.shape[0], dtype='object')
            if return_distance:
                distances = np.zeros(X.shape[0], dtype='object')

        idx_array_i = np.zeros(self.data.shape[0], dtype=ITYPE)
        distances_i = np.zeros(self.data.shape[0], dtype=DTYPE)
        count = np.zeros(X.shape[0], ITYPE)
        cdef ITYPE_t* count_data = <ITYPE_t*> np.PyArray_DATA(count)
        #cdef ITYPE_t* count_data = <ITYPE_t*> count.data

        #TODO: avoid enumerate and repeated allocation of pt slice
        for i in range(Xarr.shape[0]):
            count_data[i] = self.query_radius_one_(
                                      0,
                                      Xdata + i * n_features,
                                      rdata[i],
                                      <ITYPE_t*> np.PyArray_DATA(idx_array_i),
                                      <DTYPE_t*> np.PyArray_DATA(distances_i),
                                      #<ITYPE_t*> idx_array_i.data,
                                      #<DTYPE_t*> distances_i.data,
                                      0, count_only, return_distance)

            if count_only:
                pass
            else:
                if sort_results:
                    sort_dist_idx(#<DTYPE_t*> distances_i.data,
                                  #<ITYPE_t*> idx_array_i.data,
                                  <DTYPE_t*> np.PyArray_DATA(distances_i),
                                  <ITYPE_t*> np.PyArray_DATA(idx_array_i),
                                  count_data[i])

                idx_array[i] = idx_array_i[:count_data[i]].copy()
                if return_distance:
                    distances[i] = distances_i[:count_data[i]].copy()

        # deflatten results
        if count_only:
            return count.reshape(orig_shape[:-1])
        elif return_distance:
            return (idx_array.reshape(orig_shape[:-1]),
                    distances.reshape(orig_shape[:-1]))
        else:
            return idx_array.reshape(orig_shape[:-1])

    @cython.cdivision(True)
    cdef void _recursive_build(self, ITYPE_t i_node,
                               ITYPE_t idx_start, ITYPE_t idx_end):
        cdef ITYPE_t imax
        cdef ITYPE_t n_features = self.data.shape[1]
        cdef ITYPE_t n_points = idx_end - idx_start
        cdef ITYPE_t n_mid = n_points / 2
        cdef ITYPE_t* idx_array = (<ITYPE_t*> np.PyArray_DATA(self.idx_array)
                                   + idx_start)
        cdef DTYPE_t* data = <DTYPE_t*> np.PyArray_DATA(self.data)
        #cdef ITYPE_t* idx_array = (<ITYPE_t*> self.idx_array.data + idx_start)
        #cdef DTYPE_t* data = <DTYPE_t*> self.data.data

        # initialize node data
        cdef NodeInfo* node_info = self.bound.init_node(self, i_node,
                                                        idx_start, idx_end)

        # set up node info
        node_info.idx_start = idx_start
        node_info.idx_end = idx_end

        if 2 * i_node + 1 >= self.n_nodes:
            node_info.is_leaf = 1
            if idx_end - idx_start > 2 * self.leaf_size:
                # this shouldn't happen if our memory allocation is correct
                # we'll proactively prevent memory errors, but raise a warning
                # saying we're doing so.
                import warnings
                warnings.warn("Internal: memory layout is flawed: "
                              "not enough nodes allocated")
        elif idx_end - idx_start < 2:
            # this shouldn't happen if our memory allocation is correct
            # we'll proactively prevent memory errors, but raise a warning
            # saying we're doing so.
            import warnings
            warnings.warn("Internal: memory layout is flawed: "
                          "too many nodes allocated")
            node_info.is_leaf = 1

        else:  # split node and recursively construct child nodes.
            # determine dimension on which to split
            node_info.is_leaf = 0

            i_max = find_split_dim(data, idx_array, n_features, n_points)

            # partition indices along this dimension
            partition_indices(data, idx_array, i_max, n_mid,
                              n_features, n_points)

            self._recursive_build(2 * i_node + 1,
                                  idx_start, idx_start + n_mid)
            self._recursive_build(2 * i_node + 2,
                                  idx_start + n_mid, idx_end)

    cdef void query_one_(self,
                         ITYPE_t i_node,
                         DTYPE_t* pt,
                         ITYPE_t n_neighbors,
                         DTYPE_t* near_set_dist,
                         ITYPE_t* near_set_indx,
                         DTYPE_t reduced_dist_LB):
        cdef DTYPE_t* data = <DTYPE_t*> np.PyArray_DATA(self.data)
        cdef ITYPE_t* idx_array = <ITYPE_t*> np.PyArray_DATA(self.idx_array)
        #cdef DTYPE_t* data = <DTYPE_t*> self.data.data
        #cdef ITYPE_t* idx_array = <ITYPE_t*> self.idx_array.data
        cdef ITYPE_t n_features = self.data.shape[1]
        cdef NodeInfo* node_info = self.node_info(i_node)

        cdef DTYPE_t dist_pt, reduced_dist_LB_1, reduced_dist_LB_2
        cdef ITYPE_t i, i1, i2

        # set the values in the heap
        self.heap.init(near_set_dist, near_set_indx, n_neighbors)

        #------------------------------------------------------------
        # Case 1: query point is outside node radius:
        #         trim it from the query
        if reduced_dist_LB > self.heap.largest():
            self.n_trims += 1

        #------------------------------------------------------------
        # Case 2: this is a leaf node.  Update set of nearby points
        elif node_info.is_leaf:
            self.n_leaves += 1
            for i in range(node_info.idx_start, node_info.idx_end):
                dist_pt = self.rdist(pt, data + n_features * idx_array[i])

                if dist_pt < self.heap.largest():
                    self.heap.insert(dist_pt, idx_array[i])

        #------------------------------------------------------------
        # Case 3: Node is not a leaf.  Recursively query subnodes
        #         starting with the closest
        else:
            self.n_splits += 1
            i1 = 2 * i_node + 1
            i2 = i1 + 1
            reduced_dist_LB_1 = self.bound.min_rdist(self, i1, pt)
            reduced_dist_LB_2 = self.bound.min_rdist(self, i2, pt)

            # recursively query subnodes
            if reduced_dist_LB_1 <= reduced_dist_LB_2:
                self.query_one_(i1, pt, n_neighbors, near_set_dist,
                                near_set_indx, reduced_dist_LB_1)
                self.query_one_(i2, pt, n_neighbors, near_set_dist,
                                near_set_indx, reduced_dist_LB_2)
            else:
                self.query_one_(i2, pt, n_neighbors, near_set_dist,
                                near_set_indx, reduced_dist_LB_2)
                self.query_one_(i1, pt, n_neighbors, near_set_dist,
                                near_set_indx, reduced_dist_LB_1)

    cdef void query_dual_(self,
                          ITYPE_t i_node1,
                          _BinaryTree other,
                          ITYPE_t i_node2,
                          ITYPE_t n_neighbors,
                          DTYPE_t* near_set_dist,
                          ITYPE_t* near_set_indx,
                          DTYPE_t reduced_dist_LB,
                          DTYPE_t* bounds):
        cdef ITYPE_t n_features = self.data.shape[1]

        cdef NodeInfo* node_info1 = self.node_info(i_node1)
        cdef NodeInfo* node_info2 = other.node_info(i_node2)
        
        #cdef DTYPE_t* data1 = <DTYPE_t*> self.data.data
        #cdef DTYPE_t* data2 = <DTYPE_t*> other.data.data
        cdef DTYPE_t* data1 = <DTYPE_t*> np.PyArray_DATA(self.data)
        cdef DTYPE_t* data2 = <DTYPE_t*> np.PyArray_DATA(other.data)

        #cdef ITYPE_t* idx_array1 = <ITYPE_t*> self.idx_array.data
        #cdef ITYPE_t* idx_array2 = <ITYPE_t*> other.idx_array.data
        cdef ITYPE_t* idx_array1 = <ITYPE_t*> np.PyArray_DATA(self.idx_array)
        cdef ITYPE_t* idx_array2 = <ITYPE_t*> np.PyArray_DATA(other.idx_array)

        cdef DTYPE_t dist_pt, reduced_dist_LB1, reduced_dist_LB2
        cdef ITYPE_t i1, i2

        #------------------------------------------------------------
        # Case 1: nodes are further apart than the current bound:
        #         trim both from the query
        if reduced_dist_LB > bounds[i_node2]:
            pass

        #------------------------------------------------------------
        # Case 2: both nodes are leaves:
        #         do a brute-force search comparing all pairs
        elif node_info1.is_leaf and node_info2.is_leaf:
            bounds[i_node2] = -1

            for i2 in range(node_info2.idx_start, node_info2.idx_end):
                self.heap.init(near_set_dist + idx_array2[i2] * n_neighbors,
                               near_set_indx + idx_array2[i2] * n_neighbors,
                               n_neighbors)

                if self.heap.largest() <= reduced_dist_LB:
                    continue

                for i1 in range(node_info1.idx_start, node_info1.idx_end):
                    dist_pt = self.rdist(data1 + n_features * idx_array1[i1],
                                         data2 + n_features * idx_array2[i2])
                    if dist_pt < self.heap.largest():
                       self.heap.insert(dist_pt, idx_array1[i1])
                
                # keep track of node bound
                bounds[i_node2] = fmax(bounds[i_node2], self.heap.largest())
            
        #------------------------------------------------------------
        # Case 3a: node 1 is a leaf: split node 2 and recursively
        #          query, starting with the nearest node
        elif node_info1.is_leaf:
            reduced_dist_LB1 = self.bound.min_rdist_dual(self, i_node1,
                                                         other, 2 * i_node2 + 1)
            reduced_dist_LB2 = self.bound.min_rdist_dual(self, i_node1,
                                                         other, 2 * i_node2 + 2)

            if reduced_dist_LB1 < reduced_dist_LB2:
                self.query_dual_(i_node1, other, 2 * i_node2 + 1, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
                self.query_dual_(i_node1, other, 2 * i_node2 + 2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
            else:
                self.query_dual_(i_node1, other, 2 * i_node2 + 2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
                self.query_dual_(i_node1, other, 2 * i_node2 + 1, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
            
            # update node bound information
            bounds[i_node2] = fmax(bounds[2 * i_node2 + 1],
                                   bounds[2 * i_node2 + 2])
            
        #------------------------------------------------------------
        # Case 3b: node 2 is a leaf: split node 1 and recursively
        #          query, starting with the nearest node
        elif node_info2.is_leaf:
            reduced_dist_LB1 = self.bound.min_rdist_dual(self, 2 * i_node1 + 1,
                                                         other, i_node2)
            reduced_dist_LB2 = self.bound.min_rdist_dual(self, 2 * i_node1 + 2,
                                                         other, i_node2)

            if reduced_dist_LB1 < reduced_dist_LB2:
                self.query_dual_(2 * i_node1 + 1, other, i_node2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
                self.query_dual_(2 * i_node1 + 2, other, i_node2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
            else:
                self.query_dual_(2 * i_node1 + 2, other, i_node2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
                self.query_dual_(2 * i_node1 + 1, other, i_node2, n_neighbors,
                                 near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
        
        #------------------------------------------------------------
        # Case 4: neither node is a leaf:
        #         split both and recursively query all four pairs
        else:
            reduced_dist_LB1 = self.bound.min_rdist_dual(self, 2 * i_node1 + 1,
                                                         other, 2 * i_node2 + 1)
            reduced_dist_LB2 = self.bound.min_rdist_dual(self, 2 * i_node1 + 2,
                                                         other, 2 * i_node2 + 1)

            if reduced_dist_LB1 < reduced_dist_LB2:
                self.query_dual_(2 * i_node1 + 1, other, 2 * i_node2 + 1,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
                self.query_dual_(2 * i_node1 + 2, other, 2 * i_node2 + 1,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
            else:
                self.query_dual_(2 * i_node1 + 2, other, 2 * i_node2 + 1,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
                self.query_dual_(2 * i_node1 + 1, other, 2 * i_node2 + 1,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)

            reduced_dist_LB1 = self.bound.min_rdist_dual(self, 2 * i_node1 + 1,
                                                         other, 2 * i_node2 + 2)
            reduced_dist_LB2 = self.bound.min_rdist_dual(self, 2 * i_node1 + 2,
                                                         other, 2 * i_node2 + 2)
            if reduced_dist_LB1 < reduced_dist_LB2:
                self.query_dual_(2 * i_node1 + 1, other, 2 * i_node2 + 2,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
                self.query_dual_(2 * i_node1 + 2, other, 2 * i_node2 + 2,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
            else:
                self.query_dual_(2 * i_node1 + 2, other, 2 * i_node2 + 2,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB2, bounds)
                self.query_dual_(2 * i_node1 + 1, other, 2 * i_node2 + 2,
                                 n_neighbors, near_set_dist, near_set_indx,
                                 reduced_dist_LB1, bounds)
            
            # update node bound information
            bounds[i_node2] = fmax(bounds[2 * i_node2 + 1],
                                   bounds[2 * i_node2 + 2])

    cdef ITYPE_t query_radius_one_(self,
                                   ITYPE_t i_node,
                                   DTYPE_t* pt, DTYPE_t r,
                                   ITYPE_t* indices,
                                   DTYPE_t* distances,
                                   ITYPE_t count,
                                   int count_only,
                                   int return_distance):
        #cdef DTYPE_t* data = <DTYPE_t*> self.data.data
        #cdef ITYPE_t* idx_array = <ITYPE_t*> self.idx_array.data
        cdef DTYPE_t* data = <DTYPE_t*> np.PyArray_DATA(self.data)
        cdef ITYPE_t* idx_array = <ITYPE_t*> np.PyArray_DATA(self.idx_array)
        cdef ITYPE_t n_features = self.data.shape[1]

        cdef NodeInfo* node_info = self.node_info(i_node)

        cdef ITYPE_t i
        cdef DTYPE_t reduced_r

        cdef DTYPE_t dist_pt, dist_LB, dist_UB
        self.bound.minmax_dist(self, i_node, pt, &dist_LB, &dist_UB)

        #------------------------------------------------------------
        # Case 1: all node points are outside distance r.
        #         prune this branch.
        if dist_LB > r:
            pass

        #------------------------------------------------------------
        # Case 2: all node points are within distance r
        #         add all points to neighbors
        elif dist_UB <= r:
            if count_only:
                count += (node_info.idx_end - node_info.idx_start)
            else:
                for i in range(node_info.idx_start, node_info.idx_end):
                    if (count < 0) or (count >= self.data.shape[0]):
                        raise ValueError("count too big")
                    indices[count] = idx_array[i]
                    if return_distance:
                        distances[count] = self.dist(pt, (data + n_features
                                                          * idx_array[i]))
                    count += 1

        #------------------------------------------------------------
        # Case 3: this is a leaf node.  Go through all points to
        #         determine if they fall within radius
        elif node_info.is_leaf:
            reduced_r = self.dm.dist_to_reduced(r, &self.dm.params)

            for i in range(node_info.idx_start, node_info.idx_end):
                dist_pt = self.rdist(pt, (data + n_features
                                          * idx_array[i]))
                if dist_pt <= reduced_r:
                    if (count < 0) or (count >= self.data.shape[0]):
                        raise ValueError("Fatal: count out of range")
                    if count_only:
                        pass
                    else:
                        indices[count] = idx_array[i]
                        if return_distance:
                            distances[count] = self.dm.reduced_to_dist(
                                                      dist_pt, &self.dm.params)
                    count += 1

        #------------------------------------------------------------
        # Case 4: Node is not a leaf.  Recursively query subnodes
        else:
            count = self.query_radius_one_(2 * i_node + 1, pt, r,
                                           indices, distances, count,
                                           count_only, return_distance)
            count = self.query_radius_one_(2 * i_node + 2, pt, r,
                                           indices, distances, count,
                                           count_only, return_distance)

        return count

    cdef DTYPE_t dist(self, DTYPE_t* x1, DTYPE_t* x2):
        return self.dm.dfunc(x1, x2, self.data.shape[1],
                             &self.dm.params, -1, -1)

    cdef DTYPE_t rdist(self, DTYPE_t* x1, DTYPE_t* x2):
        return self.dm.reduced_dfunc(x1, x2, self.data.shape[1],
                                     &self.dm.params, -1, -1)

    cdef NodeInfo* node_info(self, ITYPE_t i_node):
        return <NodeInfo*> np.PyArray_DATA(self.node_info_arr) + i_node
        #return <NodeInfo*> self.node_info_arr.data + i_node
    
    cdef DTYPE_t* node_data1(self, ITYPE_t i_node):
        return (<DTYPE_t*> np.PyArray_DATA(self.node_data_arr1)
                + i_node * self.node_data_arr1.shape[1])
        #return (<DTYPE_t*> self.node_data_arr1.data
        #        + i_node * self.node_data_arr1.shape[1])

    cdef DTYPE_t* node_data2(self, ITYPE_t i_node):
        return (<DTYPE_t*> np.PyArray_DATA(self.node_data_arr2)
                + i_node * self.node_data_arr2.shape[1])
        #return (<DTYPE_t*> self.node_data_arr2.data
        #        + i_node * self.node_data_arr2.shape[1])

cdef class BallTree(_BinaryTree):
    """
    Ball Tree for fast nearest-neighbor searches :

    BallTree(X, leaf_size=20, p=2.0)

    Parameters
    ----------
    X : array-like, shape = [n_samples, n_features]
        n_samples is the number of points in the data set, and
        n_features is the dimension of the parameter space.
        Note: if X is a C-contiguous array of doubles then data will
        not be copied. Otherwise, an internal copy will be made.

    leaf_size : positive integer (default = 20)
        Number of points at which to switch to brute-force. Changing
        leaf_size will not affect the results of a query, but can
        significantly impact the speed of a query and the memory required
        to store the built ball tree.  The amount of memory needed to
        store the tree scales as
        2 ** (1 + floor(log2((n_samples - 1) / leaf_size))) - 1
        For a specified ``leaf_size``, a leaf node is guaranteed to
        satisfy ``leaf_size <= n_points <= 2 * leaf_size``, except in
        the case that ``n_samples < leaf_size``.

    metric : string, function, or float
        distance metric.  See distmetrics docstring for available values.

    p : distance metric for the BallTree.  ``p`` encodes the Minkowski
        p-distance::

            D = sum((X[i] - X[j]) ** p) ** (1. / p)

        p must be greater than or equal to 1, so that the triangle
        inequality will hold.  If ``p == np.inf``, then the distance is
        equivalent to::

            D = max(X[i] - X[j])

    Attributes
    ----------
    data : np.ndarray
        The training data

    Examples
    --------
    Query for k-nearest neighbors

        # >>> import numpy as np
        # >>> np.random.seed(0)
        # >>> X = np.random.random((10,3))  # 10 points in 3 dimensions
        # >>> ball_tree = BallTree(X, leaf_size=2)
        # >>> dist, ind = ball_tree.query(X[0], n_neighbors=3)
        # >>> print ind  # indices of 3 closest neighbors
        # [0 3 1]
        # >>> print dist  # distances to 3 closest neighbors
        # [ 0.          0.19662693  0.29473397]

    Pickle and Unpickle a ball tree (using protocol = 2).  Note that the
    state of the tree is saved in the pickle operation: the tree is not
    rebuilt on un-pickling

        # >>> import numpy as np
        # >>> import pickle
        # >>> np.random.seed(0)
        # >>> X = np.random.random((10,3))  # 10 points in 3 dimensions
        # >>> ball_tree = BallTree(X, leaf_size=2)
        # >>> s = pickle.dumps(ball_tree, protocol=2)
        # >>> ball_tree_copy = pickle.loads(s)
        # >>> dist, ind = ball_tree_copy.query(X[0], k=3)
        # >>> print ind  # indices of 3 closest neighbors
        # [0 3 1]
        # >>> print dist  # distances to 3 closest neighbors
        # [ 0.          0.19662693  0.29473397]
    """
    def __init__(self, X, leaf_size=20, metric="minkowski", p=2, **kwargs):
        self.__init_metric(metric, p=p, **kwargs)
        self.bound = BallBound()

        # check that the metric is valid
        if self.dm.metric in INVALID_METRICS:
            raise ValueError("metric %s does not satisfy the triangle "
                             "inequality: BallTree cannot be used")

        # for BallTree, node_data_arr1 holds the centroid of each node
        self.__init_common(X, leaf_size,data1=True, data2=False)


cdef class KDTree(_BinaryTree):
    def __init__(self, X, leaf_size=20, metric='minkowski', p=2, **kwargs):
        self.__init_metric(metric, p=p, **kwargs)
        self.bound = KDBound()

        if self.dm.metric not in ['minkowski', 'euclidean', 'l1', 'l2',
                                  'manhattan', 'cityblock']:
            raise ValueError("metric %s not recognized by KDTree" % metric)

        if self.dm.params.minkowski.p == INF:
            raise ValueError('Chebyshev metric (p = inf) not '
                             'supported by KDTree.  Use BallTree instead')

        # for KDTree, node_data_arr1 and node_data_arr2 respectively hold the
        # lower bounds and upper bounds for each node
        self.__init_common(X, leaf_size, data1=True, data2=True)


######################################################################
# Helper functions for building and querying
#
cdef ITYPE_t find_split_dim(DTYPE_t* data,
                            ITYPE_t* node_indices,
                            ITYPE_t n_features,
                            ITYPE_t n_points):
    # this computes the following
    # j_max = np.argmax(np.max(data, 0) - np.min(data, 0))
    cdef DTYPE_t min_val, max_val, val, spread, max_spread
    cdef ITYPE_t i, j, j_max

    j_max = 0
    max_spread = 0

    for j in range(n_features):
        max_val = data[node_indices[0] * n_features + j]
        min_val = max_val
        for i in range(1, n_points):
            val = data[node_indices[i] * n_features + j]
            max_val = fmax(max_val, val)
            min_val = fmin(min_val, val)
        spread = max_val - min_val
        if spread > max_spread:
            max_spread = spread
            j_max = j
    return j_max


@cython.profile(False)
cdef inline void iswap(ITYPE_t* arr, ITYPE_t i1, ITYPE_t i2):
    cdef ITYPE_t tmp = arr[i1]
    arr[i1] = arr[i2]
    arr[i2] = tmp


@cython.profile(False)
cdef inline void dswap(DTYPE_t* arr, ITYPE_t i1, ITYPE_t i2):
    cdef DTYPE_t tmp = arr[i1]
    arr[i1] = arr[i2]
    arr[i2] = tmp


cdef void partition_indices(DTYPE_t* data,
                            ITYPE_t* node_indices,
                            ITYPE_t split_dim,
                            ITYPE_t split_index,
                            ITYPE_t n_features,
                            ITYPE_t n_points):
    # partition_indices will modify the array node_indices between
    # indices 0 and n_points.  Upon return (assuming numpy-style slicing)
    #   data[node_indices[0:split_index], split_dim]
    #     <= data[node_indices[split_index], split_dim]
    # and
    #   data[node_indices[split_index], split_dim]
    #     <= data[node_indices[split_index:n_points], split_dim]
    # will hold.  The algorithm amounts to a partial quicksort
    cdef ITYPE_t left, right, midindex, i
    cdef DTYPE_t d1, d2
    left = 0
    right = n_points - 1

    while True:
        midindex = left
        for i in range(left, right):
            d1 = data[node_indices[i] * n_features + split_dim]
            d2 = data[node_indices[right] * n_features + split_dim]
            if d1 < d2:
                iswap(node_indices, i, midindex)
                midindex += 1
        iswap(node_indices, midindex, right)
        if midindex == split_index:
            break
        elif midindex < split_index:
            left = midindex + 1
        else:
            right = midindex - 1

######################################################################
# sort_dist_idx :
#  this is a recursive quicksort implementation which sorts `dist` and
#  simultaneously performs the same swaps on `idx`.
cdef void sort_dist_idx(DTYPE_t* dist, ITYPE_t* idx, ITYPE_t k):
    cdef ITYPE_t pivot_idx, store_idx, i
    cdef DTYPE_t pivot_val

    if k > 1:
        #-- determine pivot -----------
        pivot_idx = k / 2
        pivot_val = dist[pivot_idx]
        store_idx = 0
                         
        dswap(dist, pivot_idx, k - 1)
        iswap(idx, pivot_idx, k - 1)

        for i in range(k - 1):
            if dist[i] < pivot_val:
                dswap(dist, i, store_idx)
                iswap(idx, i, store_idx)
                store_idx += 1
        dswap(dist, store_idx, k - 1)
        iswap(idx, store_idx, k - 1)
        pivot_idx = store_idx
        #------------------------------

        sort_dist_idx(dist, idx, pivot_idx)

        sort_dist_idx(dist + pivot_idx + 1,
                      idx + pivot_idx + 1,
                      k - pivot_idx - 1)

######################################################################
# Bound implementations
#
# We can have several different types of bound in a binary tree.  Here
# we use a BallBound, a KDBound, and perhaps will extend this to similar
# cases with periodic boundary conditions.  The bound type must depend
# on the distance metric used, and provides an interface to the distance
# between points and to the minimum and maximum bounds between a node
# and a point or between two nodes.
#
# These classes function more as mixins.  True mixins are not supported by
# the cython class hierarchy, so instead we use cdef'd attributes of the
# binary tree class.  As long as these are declared correctly, they'll be
# implemented as c structs with the associated fast access
cdef class BoundBase:
    """base class for bound interface"""
    cdef NodeInfo* init_node(self, _BinaryTree bt, ITYPE_t i_node,
                             ITYPE_t idx_start, ITYPE_t idx_end):
        return NULL

    def __reduce__(self):
        """reduce method used for pickling"""
        return (newObj, (self.__class__,))

    cdef DTYPE_t min_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return 0.0
    
    cdef DTYPE_t min_rdist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return 0.0

    cdef DTYPE_t max_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return INF

    cdef DTYPE_t max_rdist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return INF

    cdef void minmax_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt,
                          DTYPE_t* dmin, DTYPE_t* dmax):
        dmin[0] = 0
        dmax[0] = INF

    cdef DTYPE_t min_dist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                               _BinaryTree bt2, ITYPE_t i_node2):
        return 0.0

    cdef DTYPE_t min_rdist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                                _BinaryTree bt2, ITYPE_t i_node2):
        return 0.0

    cdef DTYPE_t max_dist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                               _BinaryTree bt2, ITYPE_t i_node2):
        return INF

    cdef DTYPE_t max_rdist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                                _BinaryTree bt2, ITYPE_t i_node2):
        return INF


cdef class BallBound(BoundBase):
    @cython.cdivision(True)
    cdef NodeInfo* init_node(self, _BinaryTree bt, ITYPE_t i_node,
                             ITYPE_t idx_start, ITYPE_t idx_end):
        cdef ITYPE_t n_features = bt.data.shape[1]
        cdef ITYPE_t n_points = idx_end - idx_start

        cdef ITYPE_t* idx_array = <ITYPE_t*> np.PyArray_DATA(bt.idx_array)
        cdef DTYPE_t* data = <DTYPE_t*> np.PyArray_DATA(bt.data)
        #cdef ITYPE_t* idx_array = <ITYPE_t*> bt.idx_array.data
        #cdef DTYPE_t* data = <DTYPE_t*> bt.data.data
        cdef NodeInfo* node_info = bt.node_info(i_node)
        cdef DTYPE_t* centroid = bt.node_data1(i_node)

        cdef ITYPE_t i, j
        cdef DTYPE_t radius
        cdef DTYPE_t *this_pt

        # determine Node centroid
        for j in range(n_features):
            centroid[j] = 0

        for i in range(idx_start, idx_end):
            this_pt = data + n_features * idx_array[i]
            for j from 0 <= j < n_features:
                centroid[j] += this_pt[j]

        for j in range(n_features):
            centroid[j] /= n_points

        # determine Node radius
        radius = 0
        for i in range(idx_start, idx_end):
            radius = fmax(radius,
                          bt.rdist(centroid, data + n_features * idx_array[i]))

        node_info.radius = bt.dm.reduced_to_dist(radius, &bt.dm.params)
        
        return node_info

    cdef DTYPE_t min_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        cdef ITYPE_t n_features = bt.data.shape[1]
        cdef NodeInfo* info = bt.node_info(i_node)
        cdef DTYPE_t* centroid = bt.node_data1(i_node)

        return fmax(0, bt.dist(pt, centroid) - info.radius)

    cdef DTYPE_t min_rdist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return bt.dm.dist_to_reduced(self.min_dist(bt, i_node, pt),
                                     &bt.dm.params)

    cdef void minmax_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt,
                          DTYPE_t* dmin, DTYPE_t* dmax):
        cdef ITYPE_t n_features = bt.data.shape[1]
        cdef NodeInfo* info = bt.node_info(i_node)
        cdef DTYPE_t* centroid = bt.node_data1(i_node)
        cdef DTYPE_t dist_pt = bt.dist(pt, centroid)

        dmin[0] = fmax(0, dist_pt - info.radius)
        dmax[0] = dist_pt + info.radius

    cdef DTYPE_t min_dist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                               _BinaryTree bt2, ITYPE_t i_node2):
        cdef ITYPE_t n_features = bt1.data.shape[1]
        cdef NodeInfo* info1 = bt1.node_info(i_node1)
        cdef NodeInfo* info2 = bt2.node_info(i_node2)
        cdef DTYPE_t* centroid1 = bt1.node_data1(i_node1)
        cdef DTYPE_t* centroid2 = bt2.node_data1(i_node2)
        
        return fmax(0, (bt1.dist(centroid2, centroid1)
                        - info1.radius
                        - info2.radius))

    cdef DTYPE_t min_rdist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                                _BinaryTree bt2, ITYPE_t i_node2):
        return bt1.dm.dist_to_reduced(self.min_dist_dual(bt1, i_node1,
                                                         bt2, i_node2),
                                      &bt1.dm.params)

cdef class KDBound(BoundBase):
    @cython.cdivision(True)
    cdef NodeInfo* init_node(self, _BinaryTree bt, ITYPE_t i_node,
                             ITYPE_t idx_start, ITYPE_t idx_end):
        cdef ITYPE_t n_features = bt.data.shape[1]
        cdef ITYPE_t n_points = idx_end - idx_start

        #cdef ITYPE_t* idx_array = <ITYPE_t*> bt.idx_array.data
        #cdef DTYPE_t* data = <DTYPE_t*> bt.data.data
        cdef ITYPE_t* idx_array = <ITYPE_t*> np.PyArray_DATA(bt.idx_array)
        cdef DTYPE_t* data = <DTYPE_t*> np.PyArray_DATA(bt.data)
        cdef NodeInfo* node_info = bt.node_info(i_node)
        cdef DTYPE_t* lower = bt.node_data1(i_node)
        cdef DTYPE_t* upper = bt.node_data2(i_node)

        cdef ITYPE_t i, j
        cdef DTYPE_t *this_pt

        # determine Node bounds
        for j in range(n_features):
            lower[j] = INF
            upper[j] = -INF

        for i in range(idx_start, idx_end):
            this_pt = data + n_features * idx_array[i]
            for j in range(n_features):
                lower[j] = fmin(lower[j], this_pt[j])
                upper[j] = fmax(upper[j], this_pt[j])

        return node_info
    
    @cython.cdivision(True)
    cdef DTYPE_t min_rdist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        cdef ITYPE_t n_features = bt.data.shape[1]
        cdef DTYPE_t* lower = bt.node_data1(i_node)
        cdef DTYPE_t* upper = bt.node_data2(i_node)

        cdef DTYPE_t d, d_lo, d_hi, rdist=0.0
        cdef ITYPE_t j

        # here we'll use the fact that x + abs(x) = 2 * max(x, 0)
        for j in range(n_features):
            d_lo = lower[j] - pt[j]
            d_hi = pt[j] - upper[j]
            d = (d_lo + fabs(d_lo)) + (d_hi + fabs(d_hi))
            
            #rdist += d ^ p
            rdist += bt.dm.dist_to_reduced(d, &bt.dm.params)

        #rdist /= 2 ^ p
        return rdist / bt.dm.dist_to_reduced(2.0, &bt.dm.params)

    cdef DTYPE_t min_dist(self, _BinaryTree bt, ITYPE_t i_node, DTYPE_t* pt):
        return bt.dm.reduced_to_dist(self.min_rdist(bt, i_node, pt),
                                     &bt.dm.params)
    
    @cython.cdivision(True)
    cdef DTYPE_t min_rdist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                                _BinaryTree bt2, ITYPE_t i_node2):
        cdef ITYPE_t n_features = bt1.data.shape[1]

        cdef DTYPE_t* lower1 = bt1.node_data1(i_node1)
        cdef DTYPE_t* upper1 = bt1.node_data2(i_node1)

        cdef DTYPE_t* lower2 = bt2.node_data1(i_node2)
        cdef DTYPE_t* upper2 = bt2.node_data2(i_node2)

        cdef DTYPE_t d, d1, d2, rdist=0.0
        cdef DTYPE_t zero = 0.0
        cdef ITYPE_t j

        # here we'll use the fact that x + abs(x) = 2 * max(x, 0)
        for j in range(n_features):
            d1 = lower1[j] - upper2[j]
            d2 = lower2[j] - upper1[j]
            d = (d1 + fabs(d1)) + (d2 + fabs(d2))
            
            #rdist += d ^ p
            rdist += bt1.dm.dist_to_reduced(d, &bt1.dm.params)

        #rdist /= 2 ^ p
        return rdist / bt1.dm.dist_to_reduced(2.0, &bt1.dm.params)
    
    cdef DTYPE_t min_dist_dual(self, _BinaryTree bt1, ITYPE_t i_node1,
                               _BinaryTree bt2, ITYPE_t i_node2):
        return bt1.dm.reduced_to_dist(self.min_rdist_dual(bt1, i_node1,
                                                          bt2, i_node2),
                                     &bt1.dm.params)

        
        

######################################################################
# Heap implementations
#
# We use an inheritance structure to allow multiple implementations with
# the same interface.  As long as each derived class only overloads functions
# in the base class rather than defining new functions, this will allow
# very fast execution.

#----------------------------------------------------------------------
# Heap base class
cdef class HeapBase:
    cdef DTYPE_t* val
    cdef ITYPE_t* idx
    cdef ITYPE_t size

    cdef void init(self, DTYPE_t* val, ITYPE_t* idx, ITYPE_t size):
        self.val = val
        self.idx = idx
        self.size = size

    cdef int needs_final_sort(self):
        return 0

    cdef DTYPE_t largest(self):
        return 0.0

    cdef ITYPE_t idx_largest(self):
        return 0

    cdef void insert(self, DTYPE_t val, ITYPE_t i_val):
        pass

#----------------------------------------------------------------------
# MaxHeap
#
#  This is a basic implementation of a fixed-size binary max-heap.
#  It can be used in place of priority_queue to keep track of the
#  k-nearest neighbors in a query.  The implementation is faster than
#  priority_queue for a very large number of neighbors (k > 50 or so).
#  The implementation is slower than priority_queue for fewer neighbors.
#  The other disadvantage is that for max_heap, the indices/distances must
#  be sorted upon completion of the query.  In priority_queue, the indices
#  and distances are sorted without an extra call.
#
#  The root node is at heap[0].  The two child nodes of node i are at
#  (2 * i + 1) and (2 * i + 2).
#  The parent node of node i is node floor((i-1)/2).  Node 0 has no parent.
#  A max heap has (heap[i] >= heap[2 * i + 1]) and (heap[i] >= heap[2 * i + 2])
#  for all valid indices.
#
#  In this implementation, an empty heap should be full of infinities
#
cdef class MaxHeap(HeapBase):
    cdef int needs_final_sort(self):
        return 1

    cdef DTYPE_t largest(self):
        return self.val[0]

    cdef ITYPE_t idx_largest(self):
        return self.idx[0]

    cdef void insert(self, DTYPE_t val, ITYPE_t i_val):
        cdef ITYPE_t i, ic1, ic2, i_tmp
        cdef DTYPE_t d_tmp

        # check if val should be in heap
        if val > self.val[0]:
            return

        # insert val at position zero
        self.val[0] = val
        self.idx[0] = i_val

        #descend the heap, swapping values until the max heap criterion is met
        i = 0
        while 1:
            ic1 = 2 * i + 1
            ic2 = ic1 + 1

            if ic1 >= self.size:
                break
            elif ic2 >= self.size:
                if self.val[ic1] > val:
                    i_swap = ic1
                else:
                    break
            elif self.val[ic1] >= self.val[ic2]:
                if val < self.val[ic1]:
                    i_swap = ic1
                else:
                    break
            else:
                if val < self.val[ic2]:
                    i_swap = ic2
                else:
                    break

            self.val[i] = self.val[i_swap]
            self.idx[i] = self.idx[i_swap]

            i = i_swap

        self.val[i] = val
        self.idx[i] = i_val


#----------------------------------------------------------------------
# Priority Queue Implementation
#
#  This is used to keep track of the neighbors as they are found.
#  It keeps the list of neighbors sorted, and inserts each new item
#  into the list.  In this fixed-size implementation, empty elements
#  are represented by infinities.
cdef class PriorityQueue(HeapBase):
    cdef int needs_final_sort(self):
        return 0

    cdef DTYPE_t largest(self):
        return self.val[self.size - 1]

    cdef ITYPE_t pqueue_idx_largest(self):
        return self.idx[self.size - 1]

    cdef void insert(self, DTYPE_t val, ITYPE_t i_val):
        cdef ITYPE_t i_lower = 0
        cdef ITYPE_t i_upper = self.size - 1
        cdef ITYPE_t i, i_mid

        if val >= self.val[i_upper]:
            return
        elif val <= self.val[i_lower]:
            i_mid = i_lower
        else:
            while True:
                if (i_upper - i_lower) < 2:
                    i_mid = i_lower + 1
                    break
                else:
                    i_mid = (i_lower + i_upper) / 2

                if i_mid == i_lower:
                    i_mid += 1
                    break

                if val >= self.val[i_mid]:
                    i_lower = i_mid
                else:
                    i_upper = i_mid

        for i from self.size > i > i_mid:
            self.val[i] = self.val[i - 1]
            self.idx[i] = self.idx[i - 1]

        self.val[i_mid] = val
        self.idx[i_mid] = i_val


#----------------------------------------------------------------------
# One item implementation
#
# In the common case of a single neighbor, we can use a simple "heap" of
# one item which is more efficient than either of the above options
cdef class OneItemHeap(HeapBase):
    cdef int needs_final_sort(self):
        return 0

    cdef DTYPE_t largest(self):
        return self.val[0]

    cdef ITYPE_t pqueue_idx_largest(self):
        return self.idx[0]

    cdef void insert(self, DTYPE_t val, ITYPE_t i_val):
        if val < self.val[0]:
            self.val[0] = val
            self.idx[0] = i_val
