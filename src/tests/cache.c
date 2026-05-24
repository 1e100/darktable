/*
    This file is part of darktable,
    Copyright (C) 2011-2023 darktable developers.

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
*/


#define DT_UNIT_TEST

// unit test for the concurrent hopscotch hashmap and the LRU cache built on top of it.
#include "common/cache.h"
#include "common/darktable.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _OPENMP
#include <omp.h>
#endif

darktable_t darktable;

void *dt_alloc_aligned(const size_t size)
{
  void *buf = NULL;
  if(posix_memalign(&buf, DT_CACHELINE_BYTES, dt_round_size(size, DT_CACHELINE_BYTES))) return NULL;
  return buf;
}

size_t dt_round_size(const size_t size, const size_t alignment)
{
  const size_t remainder = size % alignment;
  return remainder ? size + alignment - remainder : size;
}

void dt_print_ext(const char *msg, ...)
{
  (void)msg;
}

static void alloc_dummy(void *data, dt_cache_entry_t *entry)
{
  (void)data;
  entry->cost = 1; // also the default
  entry->data_size = sizeof(uint32_t);
  entry->data = (void *)(uintptr_t)entry->key;
}

static void cleanup_dummy(void *data, dt_cache_entry_t *entry)
{
  (void)data;
  (void)entry;
}

static int cache_size(const dt_cache_t *cache)
{
  return g_hash_table_size(cache->hashtable);
}

static int lru_check_consistency(const dt_cache_t *cache)
{
  int count = 0;
  for(const GList *l = cache->lru; l; l = g_list_next(l))
  {
    const dt_cache_entry_t *entry = (const dt_cache_entry_t *)l->data;
    assert(entry->link == l);
    count++;
  }
  return count;
}

static int lru_check_consistency_reverse(const dt_cache_t *cache)
{
  int count = 0;
  for(const GList *l = g_list_last(cache->lru); l; l = g_list_previous(l))
  {
    const dt_cache_entry_t *entry = (const dt_cache_entry_t *)l->data;
    assert(entry->link == l);
    count++;
  }
  return count;
}

int main(int argc, char *arg[])
{
  dt_cache_t cache;
  // really hammer it, make quota insanely low:
  dt_cache_init(&cache, sizeof(uint32_t), 100);
  dt_cache_set_allocate_callback(&cache, alloc_dummy, NULL);
  dt_cache_set_cleanup_callback(&cache, cleanup_dummy, NULL);

#ifdef _OPENMP
#pragma omp parallel for default(none) schedule(guided) shared(cache, stderr) num_threads(16)
#endif
  for(int k = 0; k < 100000; k++)
  {
    const int con1 = dt_cache_contains(&cache, k);
    dt_cache_entry_t *entry = dt_cache_get(&cache, k, 'r');
    const int val1 = (int)(uintptr_t)entry->data;
    dt_cache_release(&cache, entry);
    entry = dt_cache_get(&cache, k, 'r');
    const int val2 = (int)(uintptr_t)entry->data;
    // fprintf(stderr, "\rinserted number %d, size %d, value %d - %d, contains %d - %d", k, size, val1, val2,
    // con1, con2);
    const int con2 = dt_cache_contains(&cache, k);
    assert(con1 == 0);
    assert(con2 == 1);
    assert(val1 == k);
    assert(val2 == k);
    dt_cache_release(&cache, entry);
  }
  // fprintf(stderr, "\n");
  fprintf(stderr, "[passed] inserting 100000 entries concurrently\n");

  const int size = cache_size(&cache);
  const int lru_cnt = lru_check_consistency(&cache);
  const int lru_cnt_r = lru_check_consistency_reverse(&cache);
  // fprintf(stderr, "lru list contains %d|%d/%d entries\n", lru_cnt, lru_cnt_r, size);
  assert(size == lru_cnt);
  assert(lru_cnt_r == lru_cnt);
  fprintf(stderr, "[passed] cache lru consistency after removals, have %d entries left.\n", size);

  dt_cache_cleanup(&cache);



  {
    // now a harder case: a cache with only one entry and a lot of threads fighting over it:
    dt_cache_t cache2;
    // really hammer it, make quota insanely low:
    // capacity 1 num threads 1 cache line size 64 ignored, quota 2 (80% => 1)
    dt_cache_init(&cache2, sizeof(uint32_t), 2);
    dt_cache_set_allocate_callback(&cache2, alloc_dummy, NULL);
    dt_cache_set_cleanup_callback(&cache2, cleanup_dummy, NULL);

#ifdef _OPENMP
#pragma omp parallel for default(none) schedule(guided) shared(cache2, stderr) num_threads(16)
#endif
    for(int k = 0; k < 100000; k++)
    {
      const int con1 = dt_cache_contains(&cache2, k);
      dt_cache_entry_t *entry = dt_cache_get(&cache2, k, 'r');
      const int val1 = (int)(uintptr_t)entry->data;
      dt_cache_release(&cache2, entry);
      entry = dt_cache_get(&cache2, k, 'r');
      const int val2 = (int)(uintptr_t)entry->data;
      // fprintf(stderr, "\rinserted number %d, size %d, value %d - %d, contains %d - %d", k, size, val1,
      // val2, con1, con2);
      const int con2 = dt_cache_contains(&cache2, k);
      assert(con1 == 0);
      assert(con2 == 1);
      assert(val1 == k);
      assert(val2 == k);
      dt_cache_release(&cache2, entry);
    }
    // fprintf(stderr, "\n");
    fprintf(stderr, "[passed] inserting 100000 entries concurrently\n");

    const int size = cache_size(&cache2);
    const int lru_cnt = lru_check_consistency(&cache2);
    const int lru_cnt_r = lru_check_consistency_reverse(&cache2);
    // fprintf(stderr, "lru list contains %d|%d/%d entries\n", lru_cnt, lru_cnt_r, size);
    assert(size == lru_cnt);
    assert(lru_cnt_r == lru_cnt);
    fprintf(stderr, "[passed] cache lru consistency after removals, have %d entries left.\n", size);
    dt_cache_cleanup(&cache2);
  }

  exit(0);
}
// clang-format off
// modelines: These editor modelines have been set for all relevant files by tools/update_modelines.py
// vim: shiftwidth=2 expandtab tabstop=2 cindent
// kate: tab-indents: off; indent-width 2; replace-tabs on; indent-mode cstyle; remove-trailing-spaces modified;
// clang-format on
