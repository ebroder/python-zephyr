# cython: c_string_type=unicode, c_string_encoding=ascii

cdef extern from "netinet/in.h":
    struct in_addr:
        int s_addr
    struct sockaddr_in:
        short sin_family
        unsigned short sin_port
        in_addr sin_addr
        char sin_zero[8]

cdef extern from "arpa/inet.h":
    char * inet_ntoa(in_addr)
    int inet_aton(char *, in_addr *)

cdef extern from "sys/time.h":
     struct timeval:
         unsigned int tv_sec
         unsigned int tv_usec

cdef extern from "zephyr/zephyr.h":
    ctypedef enum ZNotice_Kind_t:
        UNSAFE,
        UNACKED,
        ACKED,
        HMACK,
        HMCTL,
        SERVACK,
        SERVNAK,
        CLIENTACK,
        STAT

    enum _ZAuth_Levels:
        ZAUTH_FAILED,
        ZAUTH_YES,
        ZAUTH_NO

    enum _ZCharsets:
        ZCHARSET_UNKNOWN,
        ZCHARSET_ISO_8859_1,
        ZCHARSET_UTF_8

    ctypedef struct ZUnique_Id_t:
        in_addr zuid_addr
        timeval tv

    ctypedef struct ZNotice_t:
        char * z_packet
        char * z_version
        ZNotice_Kind_t z_kind
        ZUnique_Id_t z_uid
        timeval z_time
        unsigned short z_port
        unsigned short z_charset
        int z_auth
        int z_checked_auth
        int z_authent_len
        char * z_ascii_authent
        char * z_class
        char * z_class_inst
        char * z_opcode
        char * z_sender
        char * z_recipient
        char * z_default_format
        char * z_multinotice
        ZUnique_Id_t z_multiuid
        unsigned int z_checksum
        int z_num_other_fields
        char * z_other_fields[10]
        char * z_message
        int z_message_len

    ctypedef struct ZSubscription_t:
        char * zsub_recipient
        char * zsub_class
        char * zsub_classinst

    int (*ZAUTH)()
    int (*ZNOAUTH)()

    int ZInitialize()
    int ZOpenPort(unsigned short * port)
    int ZGetFD()
    int ZSetFD(int)
    int ZSendNotice(ZNotice_t * notice, int (*cert_routine)())
    int ZReceiveNotice(ZNotice_t *, sockaddr_in *)
    int ZPending()
    int ZCheckAuthentication(ZNotice_t *, sockaddr_in *)
    void ZFreeNotice(ZNotice_t * notice)
    int ZSubscribeTo(ZSubscription_t subslist[], int nitems, unsigned short port)
    int ZUnsubscribeTo(ZSubscription_t subslist[], int nitems, unsigned short port)
    int ZCancelSubscriptions(unsigned short port)
    char * ZGetSender()
    char * ZGetRealm()
    int ZRetrieveSubscriptions(unsigned short port, int* nitems)
    int ZGetSubscriptions(ZSubscription_t subslist[], int* nitems)
    int ZFlushSubscriptions()

    # XXX: This should really be const char * (or const_char *) -- see
    # <http://docs.cython.org/src/tutorial/strings.html#dealing-with-const>
    # In Cython 0.12, Cython doesn't seem to support const_char at all, and
    # in Cython 0.15, it doesn't seem to be able to handle converting a
    # const_char * to a Python string. Once we're dealing with newer Cythons,
    # this should probably change, though.
    char *ZCharsetToString(unsigned short charset)

cdef extern from "com_err.h":
    char * error_message(int)

cdef extern from "stdlib.h":
    void * malloc(unsigned int)
    void * calloc(unsigned int, unsigned int)
    void free(void *)

cdef extern from "string.h":
    void * memset(void *, int, unsigned int)

cdef extern from "pool.h":
    ctypedef struct object_pool:
        void **objects
        size_t alloc
        size_t count

    void object_pool_init(object_pool *pool)
    void object_pool_append(object_pool *pool, object obj)
    void object_pool_free(object_pool *pool)
