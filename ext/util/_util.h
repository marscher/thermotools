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

#ifndef THERMOTOOLS_UTIL
#define THERMOTOOLS_UTIL

/***************************************************************************************************
*   C99 compatibility for macros INFINITY and NAN 
***************************************************************************************************/

#include <math.h>

/* define INFINITY if not available */
#ifndef INFINITY
    #define INFINITY 1.0/0.0
#endif

/* define NAN if not available */
#ifndef NAN
    #define NAN INFINITY-INFINITY
#endif

/***************************************************************************************************
*   sorting
***************************************************************************************************/

extern void _mixed_sort(double *array, int L, int R);

/***************************************************************************************************
*   direct summation schemes
***************************************************************************************************/

extern void _kahan_summation_step(
    double new_value, double *sum, double *err, double *loc, double *tmp);
extern double _kahan_summation(double *array, int size);

/***************************************************************************************************
*   logspace summation schemes
***************************************************************************************************/

extern double _logsumexp(double *array, int size, double array_max);
extern double _logsumexp_kahan_inplace(double *array, int size, double array_max);
extern double _logsumexp_sort_inplace(double *array, int size);
extern double _logsumexp_sort_kahan_inplace(double *array, int size);
extern double _logsumexp_pair(double a, double b);

/***************************************************************************************************
*   counting states and transitions
***************************************************************************************************/

extern int _get_therm_state_break_points(int *T_x, int seq_length, int *break_points);

/***************************************************************************************************
*   transition matrix renormalization
***************************************************************************************************/

extern void _renormalize_transition_matrix(double *p, int n_conf_states, double *scratch_M);

#endif
