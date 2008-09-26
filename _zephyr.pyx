import os
import pwd
import time

cdef extern from "netinet/in.h":
    struct in_addr:
        int s_addr

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
    
    struct _ZTimeval:
        int tv_sec
        int tv_usec
    
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
    
    int (*ZAUTH)()
    int (*ZNOAUTH)()
    
    int ZInitialize()
    int ZOpenPort(unsigned short * port)
    int ZSendNotice(ZNotice_t * notice, int (*cert_routine)())

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *, Py_ssize_t)

cdef extern from "com_err.h":
    char * error_message(int)

cdef extern from "stdlib.h":
    void * malloc(unsigned int)

cdef extern from "string.h":
    void * memset(void *, int, unsigned int)

### BEGIN autoinitialization

cdef unsigned short __port
__port = 0

cdef class __Manager:
    def __init__(self):
        __initialize()
        __openPort(&__port)

cdef object __cm
__cm = __Manager()

def __error(errno):
    if errno != 0:
        raise IOError(errno, error_message(errno))

cdef __initialize():
    errno = ZInitialize()
    __error(errno)

cdef __openPort(unsigned short * port):
    errno = ZOpenPort(port)
    __error(errno)

### END autoinitialization

cdef object _string_c2p(char * string):
    if string is NULL:
        return None
    else:
        return str(string)

cdef char * _string_p2c(object string):
    if string is None:
        return NULL
    else:
        return string

# Timevals can just be floats; they're not intereting enough to have
# their own class

cdef object _ZTimeval_c2p(_ZTimeval * timeval):
    return timeval.tv_sec + (timeval.tv_usec / 100000.0)

cdef void _ZTimeval_p2c(float timeval, _ZTimeval * c_timeval) except *:
    c_timeval.tv_sec = int(timeval)
    c_timeval.tv_usec = int((timeval - c_timeval.tv_sec) * 100000)

class ZUid():
    """
    A per-transaction unique ID for zephyrs
    """
    __slots__ = ('address', 'time')
    
    def __init__(self):
        self.address = ''
        self.time = 0

cdef void _ZUid_c2p(ZUnique_Id_t * uid, object p_uid):
    p_uid.address = inet_ntoa(uid.zuid_addr)
    p_uid.time = _ZTimeval_c2p(&uid.tv)

cdef void _ZUid_p2c(object uid, ZUnique_Id_t * c_uid) except *:
    inet_aton(uid.address, &c_uid.zuid_addr)
    _ZTimeval_p2c(uid.time, &c_uid.tv)

class ZNotice():
    """
    A zephyr message
    """
    __slots__ = ('kind', 'uid', 'time', 'port', 'auth',
                 'cls', 'instance', 'recipient',
                 'sender', 'opcode', 'format',
                 'fields',
                 'message')
    
    def __init__(self, **options):
        self.kind = ACKED
        self.cls = 'message'
        self.instance = 'personal'
        
        self.uid = ZUid()
        self.time = 0
        self.port = 0
        self.auth = True
        self.recipient = None
        self.sender = None
        self.opcode = None
        self.format = "Class $class, Instance $instance:\nTo: @bold($recipient) at $time $date\nFrom: @bold{$1 <$sender>}\n\n$2"
        self.fields = []
        self.message = None
        
        for k, v in options.iteritems():
            setattr(self, k, v)
    
    def send(self):
        cdef ZNotice_t notice
        _ZNotice_p2c(self, &notice)
        
        if self.auth:
            errno = ZSendNotice(&notice, ZAUTH)
        else:
            errno = ZSendNotice(&notice, ZNOAUTH)
        __error(errno)
        
        _ZNotice_c2p(&notice, self)

cdef void _ZNotice_c2p(ZNotice_t * notice, object p_notice):
    p_notice.kind = notice.z_kind
    _ZUid_c2p(&notice.z_uid, p_notice.uid)
    p_notice.time = _ZTimeval_c2p(&notice.z_time)
    p_notice.port = int(notice.z_port)
    p_notice.auth = bool(notice.z_auth)
    
    p_notice.cls = _string_c2p(notice.z_class)
    p_notice.instance = _string_c2p(notice.z_class_inst)
    p_notice.recipient = _string_c2p(notice.z_recipient)
    p_notice.sender = _string_c2p(notice.z_sender)
    p_notice.opcode = _string_c2p(notice.z_opcode)
    p_notice.format = _string_c2p(notice.z_default_format)
    p_notice.fields = list()
    for i in range(notice.z_num_other_fields):
        p_notice.fields.append(notice.z_other_fields[i])
    
    if notice.z_message is NULL:
        p_notice.message = None
    else:
        p_notice.message = PyString_FromStringAndSize(notice.z_message, notice.z_message_len).decode('utf-8')

cdef void _ZNotice_p2c(object notice, ZNotice_t * c_notice) except *:
    memset(c_notice, 0, sizeof(ZNotice_t))
    
    c_notice.z_kind = notice.kind
    _ZUid_p2c(notice.uid, &c_notice.z_uid)
    if notice.time != 0:
        _ZTimeval_p2c(notice.time, &c_notice.z_time)
    if notice.port != 0:
        c_notice.z_port = notice.port
    c_notice.z_auth = int(notice.auth)
    
    c_notice.z_class = _string_p2c(notice.cls)
    c_notice.z_class_inst = _string_p2c(notice.instance)
    c_notice.z_recipient = _string_p2c(notice.recipient)
    c_notice.z_sender = _string_p2c(notice.sender)
    c_notice.z_opcode = _string_p2c(notice.opcode)
    c_notice.z_default_format = _string_p2c(notice.format)
    c_notice.z_num_other_fields = len(notice.fields)
    for i in range(c_notice.z_num_other_fields):
        c_notice.z_other_fields[i] = _string_p2c(notice.fields[i])
    
    encoded_message = notice.message.encode('utf-8')
    
    c_notice.z_message = _string_p2c(encoded_message)
    c_notice.z_message_len = len(encoded_message)

