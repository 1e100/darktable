#include "sqlite3.h"

#include <stdio.h>

int sqlite3IcuInit(sqlite3 *db);

static int exec_sql(sqlite3 *db, const char *sql)
{
  char *err = NULL;
  const int rc = sqlite3_exec(db, sql, NULL, NULL, &err);
  if(rc != SQLITE_OK)
  {
    fprintf(stderr, "%s: %s\n", sql, err ? err : sqlite3_errmsg(db));
    sqlite3_free(err);
    return 1;
  }
  return 0;
}

int main(void)
{
  sqlite3 *db = NULL;
  int rc = sqlite3_open(":memory:", &db);
  if(rc != SQLITE_OK)
  {
    fprintf(stderr, "sqlite3_open: %s\n", db ? sqlite3_errmsg(db) : "out of memory");
    sqlite3_close(db);
    return 1;
  }

  rc = sqlite3IcuInit(db);
  if(rc != SQLITE_OK)
  {
    fprintf(stderr, "sqlite3IcuInit: %s\n", sqlite3_errstr(rc));
    sqlite3_close(db);
    return 1;
  }

  if(exec_sql(db, "SELECT icu_load_collation('en_US', 'english')") ||
     exec_sql(db, "CREATE TABLE t(value TEXT COLLATE english)") ||
     exec_sql(db, "INSERT INTO t(value) VALUES ('z'), ('a')") ||
     exec_sql(db, "SELECT value FROM t ORDER BY value COLLATE english") ||
     exec_sql(db, "SELECT lower('I', 'tr_TR')"))
  {
    sqlite3_close(db);
    return 1;
  }

  sqlite3_close(db);
  return 0;
}
