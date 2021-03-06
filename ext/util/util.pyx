# This file is part of thermotools.
#
# Copyright 2015 Computational Molecular Biology Group, Freie Universitaet Berlin (GER)
#
# thermotools is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

r"""
Python interface to utility functions.
"""

import numpy as _np
cimport numpy as _np
from scipy.sparse import csr_matrix as _csr
from msmtools.estimation import count_matrix as _cm

__all__ = [
    'kahan_summation',
    'logsumexp',
    'logsumexp_pair',
    'get_therm_state_break_points',
    'count_matrices',
    'state_counts',
    'restrict_samples_to_cset',
    'renormalize_transition_matrix',
    'renormalize_transition_matrices']

cdef extern from "_util.h":
    # sorting
    void _mixed_sort(double *array, int L, int R)
    # direct summation schemes
    double _kahan_summation(double *array, int size)
    # logspace summation schemes
    double _logsumexp(double *array, int size, double array_max)
    double _logsumexp_kahan_inplace(double *array, int size, double array_max)
    double _logsumexp_sort_inplace(double *array, int size)
    double _logsumexp_sort_kahan_inplace(double *array, int size)
    double _logsumexp_pair(double a, double b)
    # counting states and transitions
    int _get_therm_state_break_points(int *T_x, int seq_length, int *break_points)
    # transition matrix renormalization
    void _renormalize_transition_matrix(double *p, int n_conf_states, double *scratch_M)
    # misc functions
    double _mirrored_sigmoid(double x)

####################################################################################################
#   sorting
####################################################################################################

def mixed_sort(_np.ndarray[double, ndim=1, mode="c"] array not None,
    inplace=True):
    r"""
    Sorts the given array using a quicksort/mergesort hybrid.
        
    Parameters
    ----------
    array : numpy.ndarray(dtype=numpy.float64, ndim=1)
        unsorted values
    inplace : boolean
        should the sorting be performed inplace

    Returns
    -------
    sorted_array : numpy.ndarray(dtype=numpy.float64, ndim=1)
        sorted values

    Notes
    -----
    This python wrapper is only to expose the underlying C function to the nose test suite.
    """
    x = array
    if not inplace:
        x = array.copy()
    _mixed_sort(<double*> _np.PyArray_DATA(x), 0, x.shape[0] - 1)
    return x

####################################################################################################
#   direct summation schemes
####################################################################################################

def kahan_summation(_np.ndarray[double, ndim=1, mode="c"] array not None,
    sort_array=True,
    inplace=True):
    r"""
    Sums the array using Kahan's algorithm.
        
    Parameters
    ----------
    array : numpy.ndarray(dtype=numpy.float64, ndim=1)
        (unsorted) values
    sort_array : boolean
        should the array be sorted before summation
    inplace : boolean
        should the sorting be performed inplace

    Returns
    -------
    sum : float
        sum of the array's values
    """
    x = array
    if sort_array:
        x = mixed_sort(x, inplace=inplace)
    return _kahan_summation(<double*> _np.PyArray_DATA(x), x.shape[0])

####################################################################################################
#   logspace summation schemes
####################################################################################################

def logsumexp(_np.ndarray[double, ndim=1, mode="c"] array not None,
    sort_array=True,
    inplace=True,
    use_kahan=True):
    r"""
    Perform a summation of an array of exponentials via the logsumexp scheme.
        
    Parameters
    ----------
    array : numpy.ndarray(dtype=numpy.float64, ndim=1)
        arguments of the exponentials
    sort_array : boolean
        should the array be sorted before summation
    inplace : boolean
        should the sorting be performed inplace
    use_kahan : boolean
        use Kahan's algorithm for the actual summation

    Returns
    -------
    ln_sum : float
        logarithm of the sum of exponentials

    Notes
    -----
    The logsumexp() function returns

    .. math:
        \ln\left( \sum_{i=0}^{n-1} \exp(a_i) \right)

    where the :math:`a_i` are the :math:`n` values in the supplied array.
    """
    x = array
    if not inplace:
        x = array.copy()
    # from now on, we can always use <inplace=True> safely
    if use_kahan:
        if sort_array:
            return _logsumexp_sort_kahan_inplace(<double*> _np.PyArray_DATA(x), x.shape[0])
        else:
            return _logsumexp_kahan_inplace(<double*> _np.PyArray_DATA(x), x.shape[0], x.max())
    else:
        if sort_array:
            return _logsumexp_sort_inplace(<double*> _np.PyArray_DATA(x), x.shape[0])
        else:
            return _logsumexp(<double*> _np.PyArray_DATA(x), x.shape[0], x.max())

def logsumexp_pair(a, b):
    r"""
    Perform a summation of two exponentials via the logsumexp scheme.
        
    Parameters
    ----------
    a : float
        argument of the first exponential
    b : float
        argument of the second exponential

    Returns
    -------
    ln_sum : float
        logarithm of the sum of exponentials

    Notes
    -----
    The logsumexp_pair() function returns

    .. math:
        \ln\left( \exp(a) + \exp(b) \right)

    where the :math:`a` and :math:`b` are the supplied values.
    """
    return _logsumexp_pair(a, b)

####################################################################################################
#   counting states and transitions
####################################################################################################

def get_therm_state_break_points(
    _np.ndarray[int, ndim=1, mode="c"] T_x not None):
    r"""
    Find thermodynamic state changes within a trajectory.

    Parameters
    ----------
    T_x : numpy.ndarray(shape=(X), dtype=numpy.intc)
        Thermodynamic state sequence of a trajectory of length X

    Returns
    -------
    T_B : numpy.ndarray(shape=(B), dtype=numpy.intc)
        Sequence of first subsequence starting frames
    """
    T_B = _np.zeros(shape=(T_x.shape[0],), dtype=_np.intc)
    nb = _get_therm_state_break_points(
        <int*> _np.PyArray_DATA(T_x),
        T_x.shape[0],
        <int*> _np.PyArray_DATA(T_B))
    return _np.ascontiguousarray(T_B[:nb])

def count_matrices(dtraj, lag, sliding=True, sparse_return=True, nthermo=None, nstates=None):
    r"""
    Count transitions at given lagtime.

    Parameters
    ----------
    dtraj : [numpy.ndarray(shape=(X, 2), dtype=numpy.intc)]
        list of discretized trajectories
    lag : int
        lagtime in trajectory steps
    sliding : bool, optional
        if true the sliding window approach is used for transition counting
    sparse_return : bool (optional)
        whether to return a 3D dense matrix or a list 2D sparse matrices
    nthermo : int, optional
        enforce nthermo count-matrices with shape=(nstates, nstates)
    nstates : int, optional
        enforce count-matrices with shape=(nstates, nstates) for all thermodynamic states

    Returns
    -------
    C_K : [scipy.sparse.coo_matrix] or numpy.ndarray(shape=(T, M, M), dtype=numpy.intc)
        count matrices at given lagtime
    """
    kmax = _np.max([d[:, 0].max() for d in dtraj])
    nmax = _np.max([d[:, 1].max() for d in dtraj])
    if nthermo is None:
        nthermo = kmax + 1
    elif nthermo < kmax + 1:
        raise ValueError("nthermo is smaller than the number of observed thermodynamic states")
    if nstates is None:
        nstates = nmax + 1
    elif nstates < nmax + 1:
        raise ValueError("nstates is smaller than the number of observed microstates")
    C_K = [_csr((nstates, nstates), dtype=_np.intc)] * nthermo
    for d in dtraj:
        bp = get_therm_state_break_points(_np.ascontiguousarray(d[:, 0]))
        for b in range(1, bp.shape[0]):
            C_K[d[bp[b - 1], 0]] = C_K[d[bp[b - 1], 0]] + _cm(
                _np.ascontiguousarray(d[bp[b - 1]:bp[b], 1]), lag,
                sliding=sliding, sparse_return=True, nstates=nstates)
        C_K[d[bp[-1], 0]] = C_K[d[bp[-1], 0]] + _cm(
            _np.ascontiguousarray(d[bp[-1]:, 1]), lag,
            sliding=sliding, sparse_return=True, nstates=nstates)
    if sparse_return:
        return C_K
    return _np.array([C.toarray() for C in C_K], dtype=_np.intc)

def state_counts(dtraj, nstates=None, nthermo=None):
    r"""
    Count discrete states visits in all thermodynamic states.

    Parameters
    ----------
    dtraj : [numpy.ndarray(shape=(X, 2), dtype=numpy.intc)]
        list of discretized trajectories
    nstates : int, optional
        enforce state count matrix with shape=(nthermo, nstates)
    nthermo : int, optional
        enforce state count matrix with shape=(nthermo, nstates)

    Returns
    -------
    N : numpy.ndarray(shape=(T, M), dtype=numpy.intc)
        state counts
    """
    kmax = int(_np.max([d[:, 0].max() for d in dtraj]))
    nmax = int(_np.max([d[:, 1].max() for d in dtraj]))
    if nthermo is None:
        nthermo = kmax + 1
    elif nthermo < kmax + 1:
        raise ValueError("nthermo is smaller than the number of observed thermodynamic states")
    if nstates is None:
        nstates = nmax + 1
    elif nstates < nmax + 1:
        raise ValueError("nstates is smaller than the number of observed microstates")
    N = _np.zeros(shape=(nthermo, nstates), dtype=_np.intc)
    for d in dtraj:
        for K in range(nthermo):
            for i in range(nstates):
                N[K, i] += ((d[:, 0] == K) * (d[:, 1] == i)).sum()
    return N

def restrict_samples_to_cset(state_sequence, bias_energy_sequence, cset):
    r"""
    Restrict full list of samples to a subset and relabel configurational state indices.

    Parameters
    ----------
    state_sequence : numpy.ndarray(shape=(X, 2), dtype=numpy.intc)
        sequence of the thermodynamic and configurational state indices of the X samples
    bias_energy_sequence : numpy.ndarray(shape=(T, X), dtype=numpy.float64)
        sequence of the reduced bias energies for all X samples in all T thermodynamic states
    cset : list
        list of configurational states within the desired set

    Returns
    -------
    new_state_sequence : numpy.ndarray(shape=(Y, 2), dtype=numpy.intc)
        restricted and relabeled sequence of the thermodynamic and configurational state
        indices of the Y valid samples
    new_bias_energy_sequence : numpy.ndarray(shape=(T, Y), dtype=numpy.float64)
        restricted sequence of the reduced bias energies for all Y valid samples in
        all T thermodynamic states
    """
    nmax = int(_np.max([_np.max(state_sequence), _np.max(cset)]))
    mapping = []
    o = 0
    for i in range(nmax + 1):
        if i in cset:
            mapping.append(o)
            o += 1
        else:
            mapping.append(-1)
    mapping = _np.array(mapping, dtype=_np.intc)
    conf_state_sequence = mapping[state_sequence[:, 1]]
    valid_samples = (conf_state_sequence != -1)
    new_state_sequence = _np.ascontiguousarray(state_sequence[valid_samples, :])
    new_state_sequence[:, 1] = conf_state_sequence[valid_samples]
    new_bias_energy_sequence = _np.ascontiguousarray(bias_energy_sequence[:, valid_samples])
    return new_state_sequence, new_bias_energy_sequence

####################################################################################################
#   transition matrix renormalization
####################################################################################################

def renormalize_transition_matrix(
    _np.ndarray[double, ndim=2, mode="c"] P not None,
    _np.ndarray[double, ndim=1, mode="c"] scratch_M not None):
    _renormalize_transition_matrix(
        <double*> _np.PyArray_DATA(P),
        P.shape[0],
        <double*> _np.PyArray_DATA(scratch_M))

def renormalize_transition_matrices(
    _np.ndarray[double, ndim=3, mode="c"] PK not None,
    _np.ndarray[double, ndim=1, mode="c"] scratch_M not None):
    for K in range(PK.shape[0]):
        P = _np.ascontiguousarray(PK[K, :, :])
        _renormalize_transition_matrix(
            <double*> _np.PyArray_DATA(P),
            P.shape[0],
            <double*> _np.PyArray_DATA(scratch_M))
        PK[K, :, :] = P[:, :]
