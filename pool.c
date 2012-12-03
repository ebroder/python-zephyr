#include "Python.h"

#include <stdlib.h>

#include "pool.h"

void object_pool_init(struct object_pool *pool) {
    pool->objects = NULL;
    pool->count = pool->alloc = 0;
}

void object_pool_append(struct object_pool *pool, PyObject *obj) {
    if (pool->count == pool->alloc) {
        size_t new_alloc = pool->alloc ? 2 * pool->alloc : 8;
        pool->objects = realloc(pool->objects, new_alloc * sizeof(*pool->objects));
        pool->alloc = new_alloc;
    }
    pool->objects[pool->count++] = obj;
    Py_INCREF(obj);
}

void object_pool_free(struct object_pool *pool) {
    int i;
    for (i = 0; i < pool->count; i++) {
        Py_DECREF(pool->objects[i]);
    }
    free(pool->objects);
    object_pool_init(pool);
}
