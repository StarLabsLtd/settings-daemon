/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <packagekit-glib2/packagekit.h>

static unsigned calls;

unsigned test_offline_calls(void)
{
    return calls;
}

/* Only the stored result is substituted; the provider and GApplication run normally. */
PkResults *pk_offline_get_results(GError **error)
{
    PkResults *results = pk_results_new();

    calls++;
    if (g_strcmp0(g_getenv("TEST_OFFLINE_RESULT"), "failure") == 0) {
        PkError *failure = pk_error_new();

        g_object_set(failure, "code", PK_ERROR_ENUM_FAILED_INITIALIZATION,
                     "details", "fixture offline failure", NULL);
        pk_results_set_exit_code(results, PK_EXIT_ENUM_FAILED);
        pk_results_set_error_code(results, failure);
        g_object_unref(failure);
    } else {
        pk_results_set_exit_code(results, PK_EXIT_ENUM_SUCCESS);
    }
    return results;
}
