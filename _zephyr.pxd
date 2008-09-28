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
    
    struct _ZTimeval:
        unsigned int tv_sec
        unsigned int tv_usec
    
    ctypedef struct ZUnique_Id_t:
        in_addr zuid_addr
        _ZTimeval tv
    
    ctypedef struct ZNotice_t:
        char * z_packet
        char * z_version
        ZNotice_Kind_t z_kind
        ZUnique_Id_t z_uid
        _ZTimeval z_time
        unsigned short z_port
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

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *, Py_ssize_t)

cdef extern from "com_err.h":
    char * error_message(int)

cdef extern from "stdlib.h":
    void * malloc(unsigned int)
    void free(void *)

cdef extern from "string.h":
    void * memset(void *, int, unsigned int)

