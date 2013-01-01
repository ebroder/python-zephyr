typedef struct object_pool {
    void **objects;
    size_t count;
    size_t alloc;
} object_pool;

void object_pool_init(struct object_pool *pool);
void object_pool_append(struct object_pool *pool, PyObject *obj);
void object_pool_free(struct object_pool *pool);
