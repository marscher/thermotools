/*
* This file is part of thermotools.
*
* Copyright 2015 Computational Molecular Biology Group, Freie Universitaet Berlin (GER)
*
* thermotools is free software: you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "_util.h"

/***************************************************************************************************
*   sorting
***************************************************************************************************/

extern void _mixed_sort(double *array, int L, int R)
/* _mixed_sort() is based on examples from http://www.linux-related.de (2004) */
{
    int l, r;
    double swap;
    if(R - L > 25) /* use quicksort */
    {
        l = L - 1;
        r = R;
        for(;;)
        {
            while(array[++l] < array[R]);
            while((array[--r] > array[R]) && (r > l));
            if(l >= r) break;
            swap = array[l];
            array[l] = array[r];
            array[r] = swap;
        }
        swap = array[l];
        array[l] = array[R];
        array[R] = swap;
        _mixed_sort(array, L, l - 1);
        _mixed_sort(array, l + 1, R);
    }
    else /* use insertion sort */
    {
        for(l=L+1; l<=R; ++l)
        {
            swap = array[l];
            for(r=l-1; (r >= L) && (swap < array[r]); --r)
                array[r + 1] = array[r];
            array[r + 1] = swap;
        }
    }
}

/***************************************************************************************************
*   direct summation schemes
***************************************************************************************************/

extern void _kahan_summation_step(
    double new_value, double *sum, double *err, double *loc, double *tmp)
{
    *loc = new_value - *err;
    *tmp = *sum + *loc;
    *err = (*tmp - *sum) - *loc;
    *sum = *tmp;
}

extern double _kahan_summation(double *array, int size)
{
    int i;
    double sum = 0.0, err = 0.0, loc, tmp;
    for(i=0; i<size; ++i)
    {
        loc = array[i] - err;
        tmp = sum + loc;
        err = (tmp - sum) - loc;
        sum = tmp;
    }
    return sum;
}

/***************************************************************************************************
*   logspace summation schemes
***************************************************************************************************/

extern double _logsumexp(double *array, int size, double array_max)
{
    int i;
    double sum = 0.0;
    if(0 == size) return -INFINITY;
    if(-INFINITY == array_max)
        return -INFINITY;
    for(i=0; i<size; ++i)
        sum += exp(array[i] - array_max);
    return array_max + log(sum);
}

extern double _logsumexp_kahan_inplace(double *array, int size, double array_max)
{
    int i;
    if(0 == size) return -INFINITY;
    if(-INFINITY == array_max)
        return -INFINITY;
    for(i=0; i<size; ++i)
        array[i] = exp(array[i] - array_max);
    return array_max + log(_kahan_summation(array, size));
}

extern double _logsumexp_sort_inplace(double *array, int size)
{
    if(0 == size) return -INFINITY;
    _mixed_sort(array, 0, size - 1);
    return _logsumexp(array, size, array[size - 1]);
}

extern double _logsumexp_sort_kahan_inplace(double *array, int size)
{
    if(0 == size) return -INFINITY;
    _mixed_sort(array, 0, size - 1);
    return _logsumexp_kahan_inplace(array, size, array[size - 1]);
}

extern double _logsumexp_pair(double a, double b)
{
    if((-INFINITY == a) && (-INFINITY == b))
        return -INFINITY;
    if(b > a)
        return b + log(1.0 + exp(a - b));
    return a + log(1.0 + exp(b - a));
}

/***************************************************************************************************
*   counting states and transitions
***************************************************************************************************/

extern int _get_therm_state_break_points(int *T_x, int seq_length, int *break_points)
{
    int i, K, o = 1;
    break_points[0] = 0;
    K = T_x[0];
    for(i=1; i<seq_length; ++i)
    {
        if(T_x[i] != K)
        {
            K = T_x[i];
            break_points[o++] = i;
        }
    }
    return o;
}

/***************************************************************************************************
*   transition matrix renormalization
***************************************************************************************************/

extern void _renormalize_transition_matrix(double *p, int n_conf_states, double *scratch_M)
{
    int i, j;
    double sum, max_sum = 0.0;
    for(i=0; i<n_conf_states; ++i)
    {
        for(j=0; j<n_conf_states; ++j)
            scratch_M[j] = p[i * n_conf_states + j];
        _mixed_sort(scratch_M, 0, n_conf_states - 1);
        sum = _kahan_summation(scratch_M, n_conf_states);
        max_sum = (max_sum > sum) ? max_sum : sum;
    }
    if(0.0 >= max_sum) return;
    for(i=0; i<n_conf_states; ++i)
    {
        for(j=0; j<n_conf_states; ++j)
        {
            p[i * n_conf_states + j] /= max_sum;
            if(i == j) scratch_M[i] = 0.0;
            else scratch_M[i] = p[i * n_conf_states + j];
        }
        _mixed_sort(scratch_M, 0, n_conf_states - 1);
        p[i * n_conf_states + i] = 1.0 - _kahan_summation(scratch_M, n_conf_states);
    }
}
